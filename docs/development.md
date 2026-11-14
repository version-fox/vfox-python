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
lib/bundle.lua                  reads the attached cabinets and the manifest of a python.org EXE
lib/pep514.lua                  Windows Python launcher registration
lib/python_version.lua          version parsing and installed-name matching
lib/detect_python.lua           the Detect hook's sources and filtering
tests/*_test.lua                offline hook tests, run by vfox plugin test
tests/windows_install_layouts.lua  the Windows command paths, with stubbed processes
tests/e2e/                      Go end-to-end suites for Linux and Windows; see e2e.md
tests/fixtures/                 .python-version files used by the legacy-file test
.github/workflows/              test, lint, license, e2e and publish
.github/scripts/                the docs parity check
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
after `version`. A partial version such as `3.12` is resolved first. In the default
mode on Linux and macOS it resolves to the newest match in the uv-build index when
the index has one; otherwise, and in every other mode, it resolves to the newest
stable release that `Available({})` names for this mode. An exact version is not
looked up.

- `version = "latest"` is resolved to the first entry of `Available({})` that is
  not a free-threaded build. The list is newest CPython first, so this can be a
  pre-release; a free-threaded build is installed only when its name asks for it,
  and GraalPy is selected by its full name.
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
- The default mode (no `VFOX_PYTHON_USE_UV_BUILD`, Linux and macOS, and no
  `VFOX_PYTHON_MIRROR` unless `VFOX_PYTHON_UV_BUILD_MIRROR` is set) checks the
  index for a CPython version only; a non-CPython name is never looked up there.
  When the index lists the version, the result is the same as uv-build mode. When
  it does not, PreInstall prints a line and returns no archive, so vfox runs the
  pyenv source build. A failed index request is retried (see below); an index that
  still fails is an error that names `VFOX_PYTHON_USE_UV_BUILD=0`. When no libc can be
  detected, the source build is used.
- Index requests go through `readIndex` in `lib/util.lua`. A request is sent again on
  a transport error, HTTP 429, a 5xx, or a 200 whose body is not JSON with the list the
  caller reads, since a proxy or a captive portal can answer that way. There are three
  attempts in all. Before a retry the plugin waits for the `Retry-After` seconds when
  the header is present and at most ten; otherwise for one second, then two. A longer
  `Retry-After` fails at once, and the error names the wait. An HTTP-date `Retry-After`
  is not read. Other statuses are returned to the caller as they are. The uv-build
  index and the pyenv index both use it. `pauseBeforeIndexRetry` runs `sleep`, or
  PowerShell on Windows, through `os.execute`, which plugin tests disable. The tests
  that make an index fail replace it, and `tests/index_retry_test.lua` checks both
  commands.
- `note = "uv-build"`, `"GraalPy"` or `"GraalPy Community"` is shown by vfox.

### PostInstall

`ctx.rootPath` is the vfox home, and `ctx.sdkInfo["python"]` has the version
directory (`path`) and name (`version`).

- On Linux and macOS, pyenv is cloned into `ctx.rootPath .. "/pyenv"` and
  `python-build <version> <path>` runs. The clone is removed afterwards.
- On Windows, a CPython EXE's MSIs are unpacked from the cabinet inside the
  installer with `expand.exe`. The MSIs are installed into `path`, the scratch
  folder is removed, and `ensurepip` bootstraps pip. An MSI is installed directly. Alias executables
  are copied next to `python.exe`.
- A GraalPy archive is already unpacked by vfox. The hook finds the payload
  under its `graalpy*-<platform>` directory and runs the bundled `ensurepip`.
  On Unix it repairs shebangs; on Windows it runs `bin/python.exe` and creates
  pip shims if the launchers are missing.
- In uv-build mode, and in the default mode when PreInstall returned an archive,
  vfox has already unpacked the archive. PostInstall takes the archive path when
  the note that PreInstall set is `uv-build`; vfox passes the note on in `sdkInfo`,
  so PostInstall does not ask the index again. A source build stops if a Python
  already sits in the install path: vfox clears the directory of a failed or
  interrupted install, so that Python came from an archive, and building over it
  would replace it silently. The hook repairs shebangs on Unix and ensures pip on
  Windows. `resolvePythonInstallPath` handles the MSI, uv-build and GraalPy layouts.
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
installs CPython from source (`VFOX_PYTHON_USE_UV_BUILD=0`), through the mirror, through uv-build and GraalPy,
and also runs `vfox link --detect` and a project `.python-version` on the
runner. The Windows package installs CPython and uv-build, installs GraalPy
with PEP 514 registration, and checks `.python-version`. Both packages also
run container checks. The Linux package starts a bare Ubuntu 24.04 container,
installs CPython from uv-build with the default settings and checks GraalPy there, through
testcontainers-go. The Windows package checks GraalPy in a Server Core container through the
`docker` CLI, because testcontainers-go creates a bridge network for every container and a
Windows engine has no bridge driver.
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
| Index retry waits | `vfox search` through a closed proxy, on Windows | `test.yml` |
| Docs in English and Chinese | `.github/scripts/check_docs_parity.py` | `lint.yml` |

`stylua.toml` uses four spaces, a 120-column limit and Unix line endings;
`.gitattributes` keeps checkouts LF so the check agrees with Windows. LuaLS
reads `.luarc.json`, which declares the vfox globals and disables only
`duplicate-set-field` (tests intentionally replace `io.popen` and friends).

The license check reads `.licenserc.yaml`; `.license.tpl` is the plain-text
copy. Markdown, JSON, `LICENSE`, `.tool-versions` and `tests/fixtures/**` are ignored. New Lua, YAML, TOML, Python
and ignore files need the header; `license-eye` prints the fix command when one
is missing.

## CI

- `test.yml` runs the offline tests on `ubuntu-latest` and `windows-latest` with
  vfox 1.1.0 (checksum-pinned), the GopherLua layouts on Linux, and a real
  install of CPython 3.14.5 through the EXE installer on Windows, with paths full
  of spaces and shell characters, driven by the released vfox 1.0.12. On Windows it
  also searches through a closed proxy with `VFOX_PYTHON_USE_UV_BUILD=1`, and checks
  that the index retries wait and then fail after three attempts.
- `lint.yml` runs StyLua, LuaLS and actionlint. Its `docs` job runs
  `.github/scripts/check_docs_parity.py`. That check compares the structure of the
  Chinese pages with the English ones, not their sentences: page pairs, `VFOX_*`
  names, code block counts and relative links. Translation quality still needs a
  reader.
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
| `VFOX_PYTHON_USE_UV_BUILD` | Available, PreInstall, PostInstall | unset: uv-build for a CPython version the index lists, on Linux and macOS; `0`, `false`, `no` or `off`: source build; `1`, `true`, `yes` or `on`: uv-build only |
| `VFOX_PYTHON_UV_LIBC` | Available, PreInstall | `gnu` or `musl` override |
| `VFOX_PYTHON_UV_BUILD_MIRROR` | PreInstall | HTTPS mirror for uv-build archives |
| `VFOX_PYTHON_REGISTER_PY_LAUNCHER` | PostInstall, PreUninstall | register Windows installs under `HKCU\Software\Python\VersionFox`; on by default, `0`, `false`, `no` or `off` disables |
| `GITHUB_TOKEN`, `GH_TOKEN` | Available, PreInstall | authenticate the GitHub API requests for GraalPy release lookups, which raises the rate limit |
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
