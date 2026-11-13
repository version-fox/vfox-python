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

//go:build windows

package windows

import (
	"context"
	"io"
	"os"
	"testing"

	"github.com/containerd/platforms"
	specs "github.com/opencontainers/image-spec/specs-go/v1"
	tc "github.com/testcontainers/testcontainers-go"
	tcexec "github.com/testcontainers/testcontainers-go/exec"

	client "github.com/moby/moby/client"

	"github.com/version-fox/vfox-python/tests/e2e/common"
)

const windowsBaseImage = "mcr.microsoft.com/windows/servercore:ltsc2025-KB5122871-amd64"

// TestContainerE2E builds tests/e2e/windows/Dockerfile once, starts a
// long-lived Server Core container and drives GraalPy through pwsh exec
// calls. The assertions stay in Go.
func TestContainerE2E(t *testing.T) {
	if testing.Short() {
		t.Skip("skip container E2E in short mode")
	}
	if os.Getenv("VFOX_SKIP_CONTAINER_E2E") != "" {
		t.Skip("container E2E disabled by VFOX_SKIP_CONTAINER_E2E")
	}
	// Ryuk has no Windows image; every container is terminated explicitly.
	t.Setenv("TESTCONTAINERS_RYUK_DISABLED", "true")

	ctx := context.Background()
	repoRoot := common.RepoRoot(t)
	image := buildImage(t, ctx, repoRoot)
	plugin, err := os.ReadFile(common.BuildPluginZip(t, repoRoot))
	if err != nil {
		t.Fatalf("read plugin zip: %v", err)
	}

	ctr, err := tc.GenericContainer(ctx, tc.GenericContainerRequest{
		ContainerRequest: tc.ContainerRequest{
			Image:         image,
			ImagePlatform: "windows/amd64",
		},
		Started: true,
	})
	if err != nil {
		t.Fatalf("start container: %v", err)
	}
	t.Cleanup(func() {
		_ = ctr.Terminate(context.Background())
	})

	if err := ctr.CopyToContainer(ctx, plugin, `C:/python-plugin.zip`, 0o644); err != nil {
		t.Fatalf("copy plugin zip: %v", err)
	}
	execOK(t, ctx, ctr, `vfox add --source C:/python-plugin.zip`)

	env := []string{"GRAALPY_VERSION=graalpy3.13-community-25.5.5"}
	if token := os.Getenv("GITHUB_TOKEN"); token != "" {
		env = append(env, "GITHUB_TOKEN="+token)
	}
	output := execOK(t, ctx, ctr, `
Invoke-Expression "$(vfox activate pwsh)"
vfox install "python@$env:GRAALPY_VERSION"
vfox use -g "python@$env:GRAALPY_VERSION"
Invoke-Expression "$(vfox env -s pwsh)"
python -V
python -c "import sys; assert sys.implementation.name == 'graalpy'; print(sys.implementation.name)"
python -m pip --version
pip --version

$project = 'C:\python-version-project'
Remove-Item -Recurse -Force -LiteralPath $project -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Path $project | Out-Null
Set-Content -LiteralPath "$project\.python-version" -Value $env:GRAALPY_VERSION
Set-Location $project
Invoke-Expression "$(vfox env -s pwsh)"
python -V
`, env...)

	common.RequireContains(t, output, "GraalPy", "GraalPy container interpreter")
	common.RequireContains(t, output, "graalpy", "GraalPy container implementation")
	common.RequireContains(t, output, "pip", "GraalPy container pip")
}

func buildImage(t testing.TB, ctx context.Context, repoRoot string) string {
	t.Helper()
	provider, err := tc.NewDockerProvider()
	if err != nil {
		t.Fatalf("new Docker provider: %v", err)
	}
	t.Cleanup(func() { _ = provider.Close() })

	pf, err := platforms.Parse("windows/amd64")
	if err != nil {
		t.Fatalf("parse platform: %v", err)
	}

	image := "vfox-python-e2e:windows"
	baseImage := windowsBaseImage
	tag, err := provider.BuildImage(ctx, &tc.ContainerRequest{
		FromDockerfile: tc.FromDockerfile{
			Context:        repoRoot,
			Dockerfile:     "tests/e2e/windows/Dockerfile",
			Repo:           "vfox-python-e2e",
			Tag:            "windows",
			BuildArgs:      map[string]*string{"BASE_IMAGE": &baseImage},
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
	code, reader, err := ctr.Exec(ctx, []string{"pwsh", "-NoProfile", "-Command", pwshPrelude + " " + script}, opts...)
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
