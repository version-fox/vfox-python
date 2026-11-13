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
	"encoding/base64"
	"errors"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"testing"
	"time"
	"unicode/utf16"

	"github.com/version-fox/vfox-python/tests/e2e/common"
)

const windowsBaseImage = "mcr.microsoft.com/windows/servercore:ltsc2025-KB5122871-amd64"

// pwshPath is PowerShell 7 in the image. The exec process is started from the
// command line Docker is given, so the full path avoids a PATH lookup, as the
// image's CMD does.
const pwshPath = "C:/Program Files/PowerShell/7/pwsh.exe"

// TestContainerE2E builds tests/e2e/windows/Dockerfile once, starts a
// long-lived Server Core container and drives GraalPy through pwsh exec calls.
// The assertions stay in Go.
//
// The suite talks to the docker CLI rather than to testcontainers-go:
// testcontainers creates a bridge network for every container, and a Windows
// engine has no bridge driver, so it cannot start a Windows container.
func TestContainerE2E(t *testing.T) {
	if testing.Short() {
		t.Skip("skip container E2E in short mode")
	}
	if os.Getenv("VFOX_SKIP_CONTAINER_E2E") != "" {
		t.Skip("container E2E disabled by VFOX_SKIP_CONTAINER_E2E")
	}

	repoRoot := common.RepoRoot(t)
	image := buildImage(t, repoRoot)
	plugin := common.BuildPluginZip(t, repoRoot)

	name := fmt.Sprintf("vfox-python-e2e-%d", time.Now().UnixNano())
	docker(t, "run", "--detach", "--name", name, image)
	t.Cleanup(func() {
		_, _ = exec.Command("docker", "rm", "--force", name).CombinedOutput()
	})
	docker(t, "cp", plugin, name+":C:/python-plugin.zip")
	execOK(t, name, `vfox add --source C:/python-plugin.zip`)

	env := []string{"GRAALPY_VERSION=graalpy3.13-community-25.5.5"}
	if token := os.Getenv("GITHUB_TOKEN"); token != "" {
		env = append(env, "GITHUB_TOKEN="+token)
	}
	output := execOK(t, name, `
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

// buildImage builds the image with the same docker CLI command the workflow
// used before the suite moved into Go.
func buildImage(t testing.TB, repoRoot string) string {
	t.Helper()
	const image = "vfox-python-e2e:windows"
	cmd := exec.Command("docker", "build",
		"--file", filepath.Join("tests", "e2e", "windows", "Dockerfile"),
		"--build-arg", "BASE_IMAGE="+windowsBaseImage,
		"--tag", image,
		".")
	cmd.Dir = repoRoot
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	if err := cmd.Run(); err != nil {
		t.Fatalf("docker build: %v", err)
	}
	return image
}

// docker runs a docker CLI command and fails the test if it does not succeed.
func docker(t testing.TB, args ...string) string {
	t.Helper()
	output, err := exec.Command("docker", args...).CombinedOutput()
	if err != nil {
		t.Fatalf("docker %v: %v\n%s", args, err, output)
	}
	return string(output)
}

// execRun runs a PowerShell script in the container and returns its exit code
// and combined output. The script travels as base64 over UTF-16LE, so no
// quoting reaches the docker CLI or a shell.
func execRun(t testing.TB, container, script string, env ...string) (int, string) {
	t.Helper()
	args := []string{"exec"}
	for _, item := range env {
		args = append(args, "--env", item)
	}
	args = append(args, container, pwshPath, "-NoProfile", "-EncodedCommand", encodePowerShell(pwshPrelude+" "+script))
	output, err := exec.Command("docker", args...).CombinedOutput()
	if err == nil {
		return 0, string(output)
	}
	var exitErr *exec.ExitError
	if errors.As(err, &exitErr) {
		return exitErr.ExitCode(), string(output)
	}
	t.Fatalf("docker exec: %v", err)
	return -1, ""
}

func execOK(t testing.TB, container, script string, env ...string) string {
	t.Helper()
	code, output := execRun(t, container, script, env...)
	if code != 0 {
		t.Fatalf("exec exited with code %d\n--- script ---\n%s\n--- output ---\n%s", code, script, output)
	}
	return output
}

// encodePowerShell returns the script in the form that pwsh -EncodedCommand
// reads: UTF-16LE, then base64.
func encodePowerShell(script string) string {
	units := utf16.Encode([]rune(script))
	raw := make([]byte, 0, 2*len(units))
	for _, unit := range units {
		raw = append(raw, byte(unit), byte(unit>>8))
	}
	return base64.StdEncoding.EncodeToString(raw)
}
