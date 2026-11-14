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
	"fmt"
	"os"
	"path/filepath"
	"testing"

	"github.com/version-fox/vfox-python/tests/e2e/common"
)

// TestNativeE2E runs the Linux scenarios on the GitHub runner itself:
// CPython source builds, the python.org mirror, uv-build, GraalPy,
// `vfox link --detect` and `.python-version`.
//
// The source-build and mirror subtests need the Linux build packages listed in
// docs/platforms.md. The uv-build and GraalPy subtests do not; TestContainerE2E
// proves that in a bare Ubuntu container.
func TestNativeE2E(t *testing.T) {
	repoRoot := common.RepoRoot(t)
	home := t.TempDir()
	bin := common.InstallVfox(t, home)
	plugin := common.BuildPluginZip(t, repoRoot)
	env := common.HomeEnv(home, bin)

	output := common.RunShellOK(t, repoRoot, env, "vfox add --source "+common.BashQuote(plugin))
	common.RequireContains(t, output, "successfully", "vfox add")

	run := func(t *testing.T, extra map[string]string, script string) string {
		t.Helper()
		merged := common.HomeEnv(home, bin)
		for key, value := range extra {
			merged[key] = value
		}
		return common.RunShellOK(t, repoRoot, merged, script)
	}

	// uvVersion is the CPython that the uv-build subtest installs. The
	// .python-version subtest asks for it, so it runs after uv-build.
	var uvVersion string

	// The default is uv-build for CPython, so the source-build subtests opt out.
	t.Run("source build", func(t *testing.T) {
		output := run(t, map[string]string{"VFOX_PYTHON_USE_UV_BUILD": "0"}, `
set -euo pipefail
eval "$(vfox activate bash)"
vfox install python@3.12.2
vfox use -g python@3.12.2
eval "$(vfox env -s bash)"
python -V
`)
		common.RequireContains(t, output, "3.12.2", "source build Python")
	})

	t.Run("mirror", func(t *testing.T) {
		output := run(t, map[string]string{
			"VFOX_PYTHON_MIRROR":       "https://mirrors.huaweicloud.com/python/",
			"VFOX_PYTHON_USE_UV_BUILD": "0",
		}, `
set -euo pipefail
eval "$(vfox activate bash)"
vfox install python@3.12.1
vfox use -g python@3.12.1
eval "$(vfox env -s bash)"
python -V
`)
		common.RequireContains(t, output, "3.12.1", "mirror Python")
	})

	t.Run("uv-build", func(t *testing.T) {
		uvVersion = common.NewestUvBuildVersion(t)
		// The request is the minor version: install and use both resolve it to
		// the newest release of that minor, which python -V then prints in full.
		minor := common.MinorVersion(uvVersion)
		output := run(t, map[string]string{"VFOX_PYTHON_USE_UV_BUILD": "1"}, fmt.Sprintf(`
set -euo pipefail
eval "$(vfox activate bash)"
vfox install python@%s
vfox use -g python@%s
eval "$(vfox env -s bash)"
python -V
python -m pip --version
pip --version
`, minor, minor))
		common.RequireContains(t, output, "Python "+uvVersion, "uv-build Python")
		common.RequireContains(t, output, "pip", "uv-build pip")
	})

	t.Run("graalpy", func(t *testing.T) {
		output := run(t, nil, `
set -euo pipefail
eval "$(vfox activate bash)"
vfox install python@graalpy-24.2.0
vfox use -g python@graalpy-24.2.0
eval "$(vfox env -s bash)"
python -V
python -c 'import sys; assert sys.implementation.name == "graalpy", sys.implementation.name'
python -m pip --version
pip --version
`)
		common.RequireContains(t, output, "GraalPy", "GraalPy interpreter")
	})

	t.Run("link", func(t *testing.T) {
		output := run(t, nil, "vfox link --detect python -y")
		common.RequireContains(t, output, "-system", "vfox link --detect")
		list := run(t, nil, "vfox list python")
		common.RequireContains(t, list, "(linked", "vfox list linked version")
	})

	t.Run("python-version", func(t *testing.T) {
		if uvVersion == "" {
			t.Fatal("python-version needs the uv-build subtest to run first")
		}
		project := filepath.Join(home, "python-version-project")
		if err := os.MkdirAll(project, 0o755); err != nil {
			t.Fatalf("create project: %v", err)
		}
		if err := os.WriteFile(filepath.Join(project, ".python-version"), []byte(uvVersion+"\n"), 0o644); err != nil {
			t.Fatalf("write .python-version: %v", err)
		}
		// The global version is GraalPy at this point, so a CPython line can
		// only come from the project's .python-version.
		output := run(t, nil, fmt.Sprintf(`
set -euo pipefail
cd %s
eval "$(vfox env -s bash)"
python -c 'import sys; print(sys.implementation.name, sys.version.split()[0])'
`, common.BashQuote(project)))
		common.RequireContains(t, output, "cpython "+uvVersion, ".python-version selects the installed CPython")
	})
}
