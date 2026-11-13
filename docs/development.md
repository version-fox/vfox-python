# Development

[中文](zh-CN/development.md) | [English](development.md)

## Layout

```
metadata.lua                    plugin name, version, notes and .python-version
hooks/available.lua             vfox search
hooks/pre_install.lua           vfox install: choose the release and name it
hooks/post_install.lua          vfox install: build, run the installer or unpack uv-build
hooks/pre_uninstall.lua         vfox uninstall: remove the PEP 514 registration
hooks/env_keys.lua              PATH for the selected Python
hooks/pre_use.lua               vfox use: repair shebangs, skip linked installs
hooks/parse_legacy_file.lua     .python-version
hooks/detect.lua                vfox link --detect: find Pythons on the machine
lib/util.lua                    versions, downloads, Windows install, uv-build, shebangs
lib/windows_command.lua         base64 PowerShell commands and the MSI junction
lib/pep514.lua                  Windows Python launcher registration
lib/python_version.lua          version parsing and installed-name matching
lib/detect_python.lua           the Detect hook's sources and filtering
tests/*_test.lua                offline hook tests, run by vfox plugin test
tests/windows_install_layouts.lua  the Windows command paths, with stubbed processes
tests/e2e/                      Go end-to-end suites for Linux and Windows; see e2e.md
tests/fixtures/                 .python-version files used by the legacy-file test
bin/WiX/                        the WiX tools used to extract Windows EXE installers
.github/workflows/              test, lint, license, e2e and publish
docs/, docs/zh-CN/              documentation in English and Chinese
Injection.lua                   type hints for what vfox injects, never loaded
stylua.toml, .luarc.json        Lua formatter and language-server settings
.licenserc.yaml, .license.tpl   the Apache header check
opencode.jsonc                  allows OpenCode agent sessions in this repository
                                to run git push, gh pr create and gh pr comment
```

vfox loads `metadata.lua`, calls a hook when a command needs it, and puts
`PLUGIN`, `RUNTIME` (`osType`, `archType`, `version`, `pluginDirPath`) and
`OS_TYPE`/`ARCH_TYPE` in scope. `lib/util.lua` is a script that defines globals
for the older hooks; the newer modules (`python_version`, `detect_python`,
`windows_command`, `pep514`) return tables.

## What runs for a command

| You run | Hooks |
| --- | --- |
| `vfox search python` | `Available` |
| `vfox install python@3.12.2` | `PreInstall` returns the URL and name. vfox downloads and unpacks, then calls `PostInstall` |
| `vfox use python@3.12.2` | `PreUse` returns the installed name to select. `EnvKeys` provides `PATH` |
| `cd` into a directory with `.python-version` | `ParseLegacyFile` |
| `vfox link --detect python` | `Detect` returns the Pythons already on the machine |
| `vfox uninstall python@3.12.2` | `PreUninstall` removes the PEP 514 registration; vfox removes the version directory |

## Contracts that cost time

### PreInstall

It returns `version`, `url`, `headers`, `sha256` and `note`; vfox downloads the
URL, verifies `sha256` when present, unpacks the archive and names the install
after `version`. A partial version such as `3.12` is resolved first, to the newest
stable release that `Available({})` names for this mode; an exact version is not
looked up.

- `version = "latest"` is resolved to `Available({})[1].version`. The list is
  newest CPython first, so this can be a pre-release; GraalPy is selected by
  its full name.
- On Windows, `Available` lists only the exact installer names on the download
  page. PreInstall still sends a HEAD request for the EXE and then for the MSI,
  and stops before any download when neither answers 200, with `Python <version>
  has no Windows installer on python.org`.
- A GraalPy version is resolved against Oracle's release assets for the running
  platform. The hook returns the official archive URL and its SHA-256; Linux and
  macOS use `linux-*`/`macos-*` tarballs, Windows uses `windows-amd64.zip`.
  If the GitHub API is rate-limited, the hook constructs the asset URL from the
  version and verifies its `.sha256` before using it.
- uv-build mode returns the archive URL and checksum from the index. The
  archive must be HTTPS; an unusable checksum fails the install instead of
  skipping verification. A GraalPy version is rejected because the index
  contains CPython only.
- `note = "uv-build"`, `"GraalPy"` or `"GraalPy Community"` is shown by vfox.

### PostInstall

`ctx.rootPath` is the vfox home, and `ctx.sdkInfo["python"]` has the version
directory (`path`) and name (`version`).

- On Linux and macOS, pyenv is cloned into `ctx.rootPath .. "/pyenv"` and
  `python-build <version> <path>` runs. The clone is removed afterwards.
- On Windows, a CPython EXE is extracted with `bin/WiX/dark.exe`, its MSIs are
  installed into `path`, and `ensurepip` bootstraps pip. An MSI is installed
  directly. Alias executables are copied next to `python.exe`.
- A GraalPy archive is already unpacked by vfox. The hook finds the payload
  under its `graalpy*-<platform>` directory and runs the bundled `ensurepip`.
  On Unix it repairs shebangs; on Windows it runs `bin/python.exe` and creates
  pip shims if the launchers are missing.
- In uv-build mode, the archive has already been unpacked by vfox; the hook
  finds the payload under `path/python-<version>`, repairs shebangs on Unix and
  ensures pip on Windows. `resolvePythonInstallPath` handles the MSI, uv-build
  and GraalPy layouts.
- Paths outside `ctx.rootPath` are rejected for uv-build, so a malformed index
  cannot make the hook write elsewhere.
- Unless `VFOX_PYTHON_REGISTER_PY_LAUNCHER` is `0`, `false`, `no` or `off`, the
  hook registers the version under `HKCU\Software\Python\VersionFox\<tag>`
  following PEP 514. The tag is
  the full version, with `-32`/`-arm64` for non-default architectures; several
  patch releases can coexist. It never writes `PythonCore`. For GraalPy,
  `SysVersion` is the Python language version and the optional
  `WindowedExecutablePath` is omitted.

### PreUninstall

`ctx.main` has the version directory (`path`) and name (`version`). On Windows,
the hook removes `HKCU\Software\Python\VersionFox\<tag>` only when
`VfoxManaged` is `1` and the registered `InstallPath` still matches the version
directory. It also removes the empty `VersionFox` company key. The hook runs
even when `VFOX_PYTHON_REGISTER_PY_LAUNCHER=0` has turned registration off, so
disabling registration does not leave old entries behind on uninstall.

`lib/pep514.lua` resolves the MSI layout (`path/python.exe`), the uv-build
layout (`path/python-<version>/python.exe`) and the GraalPy layout
(`path/graalpy*-windows-amd64/bin/python.exe`) before reading or writing the
registration.

### PreUse

A partial version such as `3.12` is resolved first, to the newest installed
name that matches (`find_release` in `lib/python_version.lua`); vfox passes the
request through unchanged. Then, before switching to a version, the hook checks
`bin/pip`, `bin/pip3` and `bin/easy_install`, and repairs shebangs that still point at
`.version-fox/temp/...`. A linked version (`vfox link`) is skipped: its
installation belongs to its owner, and missing packaging tools are normal for a
system Python. `isLinkedPythonInstall` tests the `python-<version>` link in the
version directory with `test -L`.

On Windows the hook returns at once, so none of the checks above run there. On
Unix, an installation with no `bin` directory stops `vfox use` with an error
that names the problem and the `vfox uninstall` and `vfox install` commands to
run again, instead of printing "Now using" for a broken install.

### EnvKeys

- Unix: `PATH = ctx.path .. "/bin"`; for GraalPy, `<prefix>/bin` with the
  prefix resolved from the extracted archive.
- Windows CPython: `PATH = ctx.path` and `PATH = ctx.path .. "\\Scripts"`.
- Windows GraalPy: `PATH = <prefix>\\bin` and `PATH = <prefix>\\Scripts`, where
  `<prefix>` is resolved from the extracted archive.

A linked system Python at `/usr` therefore puts `/usr/bin` on `PATH`, where the
command is `python3`, not `python`. The plugin does not create aliases in a
linked installation.

### Detect

`Detect` returns a list of `{ version, path, note }`. `path` is the Python
prefix (the directory with `bin` or `python.exe`), not a virtual environment.
vfox validates each name with its version-name rules, ignores unusable entries,
drops duplicates and skips a name that is already installed or a target that is
already linked.

`lib/detect_python.lua`:

- collects candidate executables from `PATH` and known directories (uv, pyenv,
  asdf, mise, Conda, Homebrew, `/usr`, `/usr/local`, `/opt`, `~/graalpy*`,
  Windows `Programs\Python`, `C:\Python*`, `C:\graalpy*`, the py launcher and
  the Store),
- queries each interpreter once with `-E -s -c` and a one-line program,
- asks for the Python version and implementation (`platform`), `sys.prefix`,
  `sys.base_prefix`, the real executable and `sys.abiflags`, plus
  `__graalpython__.get_graalvm_version()` and the Oracle/Community edition for
  GraalPy,
- skips PyPy and other implementations, virtual environments, vfox's own
  directory and root prefixes,
- names the result `<version>[-t]-<source>` for CPython and
  `graalpy[-community][<python>]-<release>-<source>` for GraalPy.

The interpreter prints UTF-8 paths as hex (`PREFIX_HEX=...`) so a non-ASCII
user name survives the Windows console and pipe encodings. The Python program
itself is one line with escaped newlines because `windows_command` rejects
control characters in arguments.

### ParseLegacyFile

`metadata.lua` declares `.python-version`. The hook reads the first non-empty,
non-comment line, maps `cpython-<version>` and the uv `+freethreaded` form, and
matches it against `ctx.getInstalledVersions()`.

Call `ctx.getInstalledVersions()` with no argument. vfox binds it as a Go
`func() []string`; `ctx:getInstalledVersions()` passes an extra argument and
fails silently.

The hook returns `{ version = name }` or `{}`. A version that is not installed
selects nothing. With `strategy = "latest_installed"`, an unreadable or missing
entry falls back to the newest regular CPython install, or else to the newest
installed name.

A partial version such as `3.13` in a `.python-version` file is resolved with
`find_release`, the function PreUse uses, so it never selects a free-threaded
or pre-release name. Other requests, such as `3.12.8`, are matched as a prefix,
so a linked `3.12.8-system` still counts. When several names share a version,
the bare name wins, then the name that sorts first, so the result does not
depend on the order the names are listed.

### windows_command

`lib/windows_command.lua` builds `powershell -NoProfile -NonInteractive
-EncodedCommand <base64 UTF-16LE>`, with every program and argument encoded
separately as UTF-8 base64. Nothing is interpolated into a cmd or PowerShell
parser, so spaces, `%`, `!`, `&` and single quotes are data. `command.msi`
escapes a trailing backslash in the quoted target and uses a temporary
directory junction when the target contains `%`, because Windows Installer
expands `%` while copying files. The junction is removed in a `finally` block
and the MSI exit code is preserved.

## Tests

`vfox plugin test .` (vfox 1.0.13 or later; `Detect` needs 1.1.0) discovers
`tests/**/*_test.lua`. Each file gets a fresh VM and a typed plugin object:

```lua
local test = require("vfox.test")
local plugin = test.load({ os = "linux", arch = "amd64", env = { HOME = "/home/test" } })
local versions = plugin:Available({})
```

- `env` values are strings, or `false` for absent.
- `http` is a function receiving `{ method, url, headers }`; return a response
  table or `nil, err`. Without it, requests are rejected unless `--online` is
  given.
- `os.execute` and `io.popen` are disabled until a test replaces them. The
  Detect tests stub `io.open` and `io.popen` to model files and commands; the
  PreUse test stubs `io.popen`.
- The PEP 514 test stubs `os.execute` and `io.open`, so it checks registration
  and cleanup command generation on Linux and Windows without writing the
  registry.
- A file that does not call `test.load()` fails; a run that finds no test file
  fails.

`tests/windows_install_layouts.lua` is run by GopherLua instead, because it
executes the real shell scripts in `PostInstall` against stubbed process calls.
It checks native argument encoding, MSI target quoting, the `%` junction,
exit-code propagation and every failure path.

The E2E suite lives in `tests/e2e` and is written in Go. The Linux package
installs CPython from source, through the mirror, through uv-build and GraalPy,
and also runs `vfox link --detect` and a project `.python-version` on the
runner. The Windows package installs CPython and uv-build, installs GraalPy
with PEP 514 registration, and checks `.python-version`. Both packages also
run GraalPy checks in Docker containers: the Linux package through
testcontainers-go, the Windows package through the `docker` CLI, because
testcontainers-go creates a bridge network for every container and a Windows
engine has no bridge driver.
See [E2E](e2e.md) for the layout and the local commands.

Local commands:

```bash
vfox plugin test .
go run github.com/yuin/gopher-lua/cmd/glua@v1.1.1 tests/windows_install_layouts.lua
stylua --check .
lua-language-server --check . --checklevel=Warning
cd tests/e2e && go test -v ./linux
cd tests/e2e && go test -v ./windows
VFOX_SKIP_CONTAINER_E2E=1 go test -v ./linux
```

## Checks

| Check | Tool | Workflow |
| --- | --- | --- |
| Lua formatting | StyLua 2.6.0, `--check .` | `lint.yml` |
| Lua diagnostics | LuaLS 3.19.1, warnings | `lint.yml` |
| Workflow syntax | actionlint 1.7.7 | `lint.yml` |
| Apache headers | Apache SkyWalking Eyes | `license.yml` |
| Hook tests | `vfox plugin test .` on Linux and Windows | `test.yml` |
| Windows command paths | GopherLua | `test.yml` |
| Native and container E2E | Go tests on Linux and Windows | `e2e.yml` |

`stylua.toml` uses four spaces, a 120-column limit and Unix line endings;
`.gitattributes` keeps checkouts LF so the check agrees with Windows. LuaLS
reads `.luarc.json`, which declares the vfox globals and disables only
`duplicate-set-field` (tests intentionally replace `io.popen` and friends).

The license check reads `.licenserc.yaml`; `.license.tpl` is the plain-text
copy. Markdown, JSON, `LICENSE`, `.tool-versions`, `tests/fixtures/**` and the
third-party WiX files under `bin/` are ignored. New Lua, YAML, TOML, Python
and ignore files need the header; `license-eye` prints the fix command when one
is missing.

## CI

- `test.yml` runs the offline tests on `ubuntu-latest` and `windows-latest` with
  vfox 1.1.0 (checksum-pinned), the GopherLua layouts on Linux, and a real
  install of CPython 3.14.5 through the EXE installer on Windows, with paths full
  of spaces and shell characters, driven by the released vfox 1.0.12.
- `lint.yml` runs StyLua, LuaLS and actionlint.
- `license.yml` runs the header check.
- `e2e.yml` builds and installs real Pythons on Linux and Windows, including a
  mirror, uv-build and GraalPy, plus the Windows PEP 514 check.
- `publish.yaml` calls the shared plugin-manifest workflow.

## Release

Maintainers publish from **Actions → Plugin → Run workflow** on the default
branch. Enter a stable plugin version without the `v` prefix; the shared
workflow updates `metadata.lua`, creates the version commit and tag, and
publishes the ZIP and manifest in this repository. Pull requests only run the
checks. Re-run the original failed job to resume a failed publication. No local
tag or release token is needed. Pushing a `v*` tag also runs the release job; it
is supported when `PLUGIN.version` in `metadata.lua` already matches the tag. The
workflows call the shared `version-fox/plugin-manifest-action` at `@v1`, and
updating that tool does not release this plugin.

## Adding a detection source

1. Add a root to `known_roots()` in `lib/detect_python.lua`, with its source
   suffix and, for a directory of installations, a child-name pattern.
2. Add the suffix to `notes` and to the tables in `docs/link.md`,
   `docs/zh-CN/link.md`, `docs/versions.md` and `docs/zh-CN/versions.md`.
3. If the source has a configuration variable, add it to the environment
   tables in this document and in `docs/link.md`.
4. Add a case to `tests/detect_test.lua` or
   `tests/detect_windows_test.lua`, including a path that must be skipped.
5. Run `vfox plugin test .` and `stylua --check .`.

## Environment variables

| Variable | Used by | Meaning |
| --- | --- | --- |
| `VFOX_PYTHON_MIRROR` | PreInstall, PostInstall | python.org mirror; a trailing `/` is added |
| `VFOX_PYTHON_USE_UV_BUILD` | Available, PreInstall, PostInstall | use uv-build archives |
| `VFOX_PYTHON_UV_LIBC` | Available, PreInstall | `gnu` or `musl` override |
| `VFOX_PYTHON_UV_BUILD_MIRROR` | PreInstall | HTTPS mirror for uv-build archives |
| `VFOX_PYTHON_REGISTER_PY_LAUNCHER` | PostInstall, PreUninstall | register Windows installs under `HKCU\Software\Python\VersionFox`; on by default, `0`, `false`, `no` or `off` disables |
| `GITHUB_TOKEN`, `GH_TOKEN` | Available | raise the GitHub API limit for the Windows GraalPy release list |
| `UV_PYTHON_INSTALL_DIR` | Detect | uv's Python directory |
| `PYENV_ROOT` | Detect | pyenv root |
| `ASDF_DATA_DIR` | Detect | asdf data directory |
| `MISE_DATA_DIR` | Detect | mise data directory |
| `CONDA_PREFIX` | Detect | current Conda installation |
| `XDG_DATA_HOME` | Detect | uv default on Unix |
| `VFOX_HOME` | Detect | skip vfox's own installations when the plugin path does not reveal it |
| `PATH` | Detect | interpreter candidates |
| `HOME`, `USERPROFILE` | Detect | default installation roots |
| `LOCALAPPDATA`, `APPDATA`, `ProgramFiles`, `ProgramFiles(x86)` | Detect | Windows installation roots |
| `HTTPS_PROXY`, `HTTP_PROXY` | vfox, python-build | proxy for downloads |

## Known limits

- Detect runs local interpreters; it is not a sandbox. Venvs are skipped, but a
  Python with a slow sitecustomize delays detection because there is no
  per-command timeout.
- Only CPython and GraalPy are detected. PyPy, Jython and other
  implementations are out of scope.
- A linked version follows its target; if the distribution moves it, the
  version name and the interpreter can disagree until Detect is run again.
- The plugin does not manage virtual environments. Use `venv`, `uv venv` or
  Conda and select the base interpreter with vfox.
