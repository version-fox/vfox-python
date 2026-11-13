// Copyright 2026 Han Li and contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//   http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

//go:build linux

package linux

import (
	"context"
	"io"
	"os"
	"testing"

	"github.com/containerd/platforms"
	client "github.com/moby/moby/client"
	specs "github.com/opencontainers/image-spec/specs-go/v1"
	tc "github.com/testcontainers/testcontainers-go"
	tcexec "github.com/testcontainers/testcontainers-go/exec"

	"github.com/version-fox/vfox-python/tests/e2e/common"
)

// TestContainerE2E builds tests/e2e/linux/Dockerfile once and runs each
// scenario in its own Ubuntu container. The image holds only the tools the
// Dockerfile installs and no build packages, so the uv-build subtest proves
// that uv-build needs no apt install. The assertions stay in Go.
func TestContainerE2E(t *testing.T) {
	if testing.Short() {
		t.Skip("skip container E2E in short mode")
	}
	if os.Getenv("VFOX_SKIP_CONTAINER_E2E") != "" {
		t.Skip("container E2E disabled by VFOX_SKIP_CONTAINER_E2E")
	}

	ctx := context.Background()
	repoRoot := common.RepoRoot(t)
	image := buildImage(t, ctx, repoRoot)
	plugin, err := os.ReadFile(common.BuildPluginZip(t, repoRoot))
	if err != nil {
		t.Fatalf("read plugin zip: %v", err)
	}
	uvVersion := common.NewestUvBuildVersion(t)

	t.Run("uv-build without build packages", func(t *testing.T) {
		ctr := startContainer(t, ctx, image, plugin)
		output := execOK(t, ctx, ctr, `
set -euo pipefail
eval "$(vfox activate bash)"
VFOX_PYTHON_USE_UV_BUILD=1 vfox install "python@$UV_VERSION"
vfox use -g "python@$UV_VERSION"
eval "$(vfox env -s bash)"
python -c 'import ssl, sqlite3, bz2, lzma, ctypes, readline, curses, zlib, hashlib; print("stdlib ok")'
python -m pip --version
`, "UV_VERSION="+uvVersion)
		common.RequireContains(t, output, "stdlib ok", "uv-build stdlib without build packages")
		common.RequireContains(t, output, "pip", "uv-build pip")
	})

	for _, version := range []string{"graalpy-24.2.0", "graalpy-community-24.2.0"} {
		version := version
		t.Run(version, func(t *testing.T) {
			ctr := startContainer(t, ctx, image, plugin)
			env := []string{"GRAALPY_VERSION=" + version, "UV_VERSION=" + uvVersion}
			if token := os.Getenv("GITHUB_TOKEN"); token != "" {
				env = append(env, "GITHUB_TOKEN="+token)
			}
			output := execOK(t, ctx, ctr, `
set -euo pipefail
eval "$(vfox activate bash)"
vfox install "python@$GRAALPY_VERSION"
vfox use -g "python@$GRAALPY_VERSION"
VFOX_PYTHON_USE_UV_BUILD=1 vfox install "python@$UV_VERSION"
eval "$(vfox env -s bash)"
python -V
python -c 'import sys; assert sys.implementation.name == "graalpy", sys.implementation.name; print(sys.implementation.name)'
python -m pip --version
pip --version

project=/tmp/python-version-project
rm -rf "$project"
mkdir -p "$project"
printf '%s\n' "$UV_VERSION" > "$project/.python-version"
cd "$project"
eval "$(vfox env -s bash)"
python -c 'import sys; print(sys.implementation.name, sys.version.split()[0])'
`, env...)
			common.RequireContains(t, output, "graalpy", "GraalPy container interpreter")
			common.RequireContains(t, output, "pip", "GraalPy container pip")
			common.RequireContains(t, output, "cpython "+uvVersion, ".python-version selects the installed CPython")
		})
	}
}

// startContainer starts a container from image and installs the plugin into
// it with `vfox add --source`.
func startContainer(t testing.TB, ctx context.Context, image string, plugin []byte) tc.Container {
	t.Helper()
	ctr, err := tc.GenericContainer(ctx, tc.GenericContainerRequest{
		ContainerRequest: tc.ContainerRequest{
			Image:         image,
			ImagePlatform: "linux/amd64",
		},
		Started: true,
	})
	if err != nil {
		t.Fatalf("start container: %v", err)
	}
	t.Cleanup(func() {
		_ = ctr.Terminate(context.Background())
	})
	if err := ctr.CopyToContainer(ctx, plugin, "/tmp/python-plugin.zip", 0o644); err != nil {
		t.Fatalf("copy plugin zip: %v", err)
	}
	execOK(t, ctx, ctr, "set -euo pipefail\nvfox add --source /tmp/python-plugin.zip\n")
	return ctr
}

func buildImage(t testing.TB, ctx context.Context, repoRoot string) string {
	t.Helper()
	provider, err := tc.NewDockerProvider()
	if err != nil {
		t.Fatalf("new Docker provider: %v", err)
	}
	t.Cleanup(func() { _ = provider.Close() })

	pf, err := platforms.Parse("linux/amd64")
	if err != nil {
		t.Fatalf("parse platform: %v", err)
	}

	image := "vfox-python-e2e:linux"
	tag, err := provider.BuildImage(ctx, &tc.ContainerRequest{
		FromDockerfile: tc.FromDockerfile{
			Context:        repoRoot,
			Dockerfile:     "tests/e2e/linux/Dockerfile",
			Repo:           "vfox-python-e2e",
			Tag:            "linux",
			KeepImage:      true,
			BuildLogWriter: os.Stdout,
			BuildOptionsModifier: func(opts *client.ImageBuildOptions) {
				opts.Platforms = []specs.Platform{pf}
				opts.PullParent = true
			},
		},
	})
	if err != nil {
		t.Fatalf("build image: %v", err)
	}
	if tag != image {
		t.Fatalf("built image %s, want %s", tag, image)
	}
	return tag
}

func execRun(t testing.TB, ctx context.Context, ctr tc.Container, script string, env ...string) (int, string) {
	t.Helper()
	opts := []tcexec.ProcessOption{tcexec.Multiplexed()}
	if len(env) > 0 {
		opts = append(opts, tcexec.WithEnv(env))
	}
	code, reader, err := ctr.Exec(ctx, []string{"bash", "-c", script}, opts...)
	if err != nil {
		t.Fatalf("exec: %v\n--- script ---\n%s", err, script)
	}
	output, err := io.ReadAll(reader)
	if err != nil {
		t.Fatalf("read exec output: %v\n--- script ---\n%s", err, script)
	}
	return code, string(output)
}

func execOK(t testing.TB, ctx context.Context, ctr tc.Container, script string, env ...string) string {
	t.Helper()
	code, output := execRun(t, ctx, ctr, script, env...)
	if code != 0 {
		t.Fatalf("exec exited with code %d\n--- script ---\n%s\n--- output ---\n%s", code, script, output)
	}
	return output
}
