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
	"fmt"
	"os"
	"path/filepath"
	"testing"

	"github.com/version-fox/vfox-python/tests/e2e/common"
)

const pwshPrelude = "$ErrorActionPreference = 'Stop'; $PSNativeCommandUseErrorActionPreference = $true;"

// TestNativeE2E runs the Windows scenarios on the GitHub runner itself: the
// python.org EXE installer, the mirror, uv-build, GraalPy registered with the
// Python launcher by default, and `.python-version`.
func TestNativeE2E(t *testing.T) {
	repoRoot := common.RepoRoot(t)
	home := t.TempDir()
	bin := common.InstallVfox(t, home)
	plugin := common.BuildPluginZip(t, repoRoot)
	env := common.HomeEnv(home, bin)

	output := common.RunShellOK(t, repoRoot, env, pwshPrelude+" vfox add --source "+common.PowerShellQuote(plugin))
	common.RequireContains(t, output, "successfully", "vfox add")

	run := func(t *testing.T, extra map[string]string, script string) string {
		t.Helper()
		merged := common.HomeEnv(home, bin)
		for key, value := range extra {
			merged[key] = value
		}
		return common.RunShellOK(t, repoRoot, merged, pwshPrelude+" "+script)
	}

	// uvVersion is the CPython that the uv-build subtest installs. The
	// .python-version subtest asks for it, so it runs after uv-build.
	var uvVersion string

	t.Run("installer", func(t *testing.T) {
		output := run(t, nil, `
Invoke-Expression "$(vfox activate pwsh)"
vfox install python@3.12.2
vfox use -g python@3.12.2
Invoke-Expression "$(vfox env -s pwsh)"
python -V
`)
		common.RequireContains(t, output, "3.12.2", "installer Python")
		// python.org publishes 3.12.2 as an EXE, and the plugin uses the EXE
		// whenever it exists, so the MSI fallback must not run here.
		common.RequireContains(t, output, "python-3.12.2-amd64.exe", "installer EXE download")
	})

	t.Run("mirror", func(t *testing.T) {
		output := run(t, map[string]string{
			"VFOX_PYTHON_MIRROR": "https://mirrors.huaweicloud.com/python/",
		}, `
Invoke-Expression "$(vfox activate pwsh)"
vfox install python@3.12.1
vfox use -g python@3.12.1
Invoke-Expression "$(vfox env -s pwsh)"
python -V
`)
		common.RequireContains(t, output, "3.12.1", "mirror Python")
	})

	t.Run("uv-build", func(t *testing.T) {
		uvVersion = common.NewestUvBuildVersion(t)
		output := run(t, map[string]string{"VFOX_PYTHON_USE_UV_BUILD": "1"}, fmt.Sprintf(`
Invoke-Expression "$(vfox activate pwsh)"
vfox install python@%s
vfox use -g python@%s
Invoke-Expression "$(vfox env -s pwsh)"
python -V
python -m pip --version
pip --version
`, uvVersion, uvVersion))
		common.RequireContains(t, output, uvVersion, "uv-build Python")
		common.RequireContains(t, output, "pip", "uv-build pip")
	})

	t.Run("graalpy", func(t *testing.T) {
		// Registration with the Python launcher is on by default, so this
		// subtest does not set VFOX_PYTHON_REGISTER_PY_LAUNCHER.
		output := run(t, nil, `
Invoke-Expression "$(vfox activate pwsh)"
vfox install python@graalpy3.13-community-25.5.5
vfox use -g python@graalpy3.13-community-25.5.5
Invoke-Expression "$(vfox env -s pwsh)"
python -V
python -c "import sys; print(sys.implementation.name)"
python -m pip --version
pip --version
$registered = (py -0p) -join [Environment]::NewLine
if ($registered -notmatch 'graalpy3\.13-community-25\.5\.5') {
    throw 'GraalPy was not registered with the Python launcher'
}
`)
		common.RequireContains(t, output, "graalpy", "GraalPy implementation")
		common.RequireContains(t, output, "GraalPy", "GraalPy interpreter")
	})

	t.Run("python-version", func(t *testing.T) {
		if uvVersion == "" {
			t.Fatal("python-version needs the uv-build subtest to run first")
		}
		project := filepath.Join(home, "python-version-project")
		if err := os.MkdirAll(project, 0o755); err != nil {
			t.Fatalf("create project: %v", err)
		}
		if err := os.WriteFile(filepath.Join(project, ".python-version"), []byte(uvVersion+"\r\n"), 0o644); err != nil {
			t.Fatalf("write .python-version: %v", err)
		}
		// The global version is GraalPy at this point, so a CPython line can
		// only come from the project's .python-version.
		output := run(t, nil, fmt.Sprintf(`
Set-Location %s
Invoke-Expression "$(vfox env -s pwsh)"
python -c "import sys; print(sys.implementation.name, sys.version.split()[0])"
`, common.PowerShellQuote(project)))
		common.RequireContains(t, output, "cpython "+uvVersion, ".python-version selects the installed CPython")
	})
}
