# Changes

[中文](zh-CN/changes.md) | [English](changes.md)

## Unreleased

- A partial version such as `python@3.12` now selects a linked install named
  with `-opt`, such as `3.12.8-opt`, and `python@3.13t` selects a linked
  free-threaded install, such as `3.13.1t-uv`. The source suffix is no longer
  read as part of the release.
- A `.python-version` file that names a partial version such as `3.13` follows
  the rule `vfox use` follows: it no longer selects a free-threaded (`t`) or
  pre-release install. `3.13t` still selects a free-threaded install; a
  pre-release needs its full name, such as `3.14.0a4`.
- When two installs share a version, such as `3.12.8-local` and
  `3.12.8-system`, `.python-version`, the `latest_installed` fallback and
  `system` pick the bare name first, then the name that sorts first. Before,
  the choice depended on the order in which the names were listed.
- `system` and the `latest_installed` fallback now choose a regular CPython
  install. Before, they compared release numbers across every installed name,
  so `system` picked `graalpy-24.2.0-system` over `3.12.3-system`, and a
  free-threaded or pre-release install could win on its number alone. Both
  still fall back to any installed name when no CPython install exists. Name a
  free-threaded, pre-release or GraalPy install in full to select it.

## 0.6.3

- When a source build fails, the error names the usual cause, a missing build
  dependency such as `zlib1g-dev`, and links to the platform notes. Without the zlib
  headers, `make install` fails in ensurepip.
- On Windows, `vfox install` stops before the download when python.org publishes no
  installer for the version, such as 3.12.12, instead of failing after the download.
- `vfox use` stops with a reinstall hint when a Python version has no `bin` directory,
  instead of reporting "Now using" for a broken installation.
- When a Windows EXE install fails to extract, the error names a missing WiX
  `dark.exe`, which antivirus software can quarantine, and reports the exit code of
  `dark.exe`.
- Partial versions such as `python@3.12` resolve in `vfox install` and `vfox use` for every
  mode. Install picks the newest stable release that the mode lists (pyenv, python.org or the
  uv-build index); use picks the newest installed match. uv-build installs are recorded under
  their full version, and Windows MSI installs create the same `python3` aliases as EXE installs.
- GraalPy is supported: Oracle GraalVM and Community distributions install from
  Oracle's official archives on Linux, macOS and Windows amd64. The Linux and
  macOS version list still comes from pyenv. Version notes mark the
  distribution. Windows arm64 and 386, and uv-build, remain CPython-only.
- `vfox link --detect python` adopts GraalPy installations and names them
  `graalpy[-community][<python>]-<release>-<source>`.
- Windows GraalPy installs can be registered with `py.exe` through PEP 514;
  `SysVersion` is the Python language version and `WindowedExecutablePath` is
  omitted.
- E2E now includes Linux and Windows container images in `tests/e2e/` that
  install GraalPy from Oracle's archives and check `python`, `pip` and
  `.python-version`, alongside the existing runner matrix.
- `vfox link --detect python` adopts system, uv, pyenv, asdf, mise, Conda,
  Homebrew, Nix, Snap, python.org, Store and py-launcher Pythons (vfox 1.1.0
  or later). Linked versions are named `<version>-<source>`.
- `.python-version` is read through `ParseLegacyFile`, so pyenv and uv projects
  select their Python when vfox enters the directory.
- `PreUse` leaves a linked installation alone instead of checking its packaging
  tools and rewriting its shebangs.
- English and Chinese documentation: versions, uv, linking, platforms, mirrors,
  development and changes.
- CI: checksum-pinned vfox 1.1.0 on Linux and Windows for the offline tests,
  GopherLua layout tests, StyLua, LuaLS, actionlint, Apache license headers,
  and E2E installs on Linux and Windows.
- Apache headers, `.gitattributes` (LF), StyLua, LuaLS and license
  configuration, and new offline tests for Detect, `.python-version`, uv-build,
  the mirror and linked versions.
- E2E coverage for `vfox link --detect python` on Linux and for a project
  `.python-version` on Linux and Windows.
- `VFOX_PYTHON_MIRROR` accepts a URL without a trailing slash and ignores an
  empty value, which is what CI passes for an unset matrix entry.
- Windows installs are registered with `py.exe` through PEP 514 under vfox's
  own `VersionFox` company key by default; set
  `VFOX_PYTHON_REGISTER_PY_LAUNCHER=0` to turn this off. The plugin never writes
  `PythonCore`; `py -3.x` remains PythonCore-only, and vfox versions are selected
  with `py -V:VersionFox/<version>`. `PreUninstall` removes the entry when it
  still points at the version.
- Windows MSI installs of old CPython releases, such as 3.4.4, need the Visual C++
  runtime that the release was built with. When `ensurepip` exits with
  `-1073741515`, the install fails and its output names the missing runtime. The
  x64 redistributable for 3.4 and the install steps are in
  [platforms.md](platforms.md#windows).

## 0.6.2

- Windows installer paths with spaces, percent signs, `!` and single quotes are
  passed through base64 PowerShell commands; targets containing `%` use a
  temporary junction during MSI installation.
- The Windows installer checks exit codes and cleans up temporary files and
  junctions.

## 0.6.1

- Authenticate installer requests and select an available uv-build release for
  the installation smoke test.
- Filter Windows Python versions by the installers python.org actually
  publishes for the architecture.

## 0.6.0

- Add the optional uv-build prebuilt archives with libc detection and SHA-256
  verification.
- Add shebang repair for source and uv-build installs.
