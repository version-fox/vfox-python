# Platforms

[中文](zh-CN/platforms.md) | [English](platforms.md)

## What is installed

| Platform | Default | `VFOX_PYTHON_USE_UV_BUILD=0` | `VFOX_PYTHON_USE_UV_BUILD=1` |
| --- | --- | --- | --- |
| Linux x86_64 | prebuilt uv-build archive for CPython when the index lists the version, otherwise a source build with pyenv; Oracle archive for GraalPy | source build with pyenv for CPython; Oracle archive for GraalPy | prebuilt uv-build archive |
| Linux arm64 | same as Linux x86_64 | same as Linux x86_64 | prebuilt uv-build archive |
| Linux armv7 | same as Linux x86_64, with no GraalPy build | source build with pyenv; no GraalPy build | prebuilt uv-build archive when available |
| Linux musl / Alpine | prebuilt musl archive when the index lists the version, otherwise a source build with pyenv | source build with pyenv | prebuilt musl archive |
| macOS Intel and Apple silicon | same as Linux x86_64 | source build with pyenv for CPython; Oracle archive for GraalPy | prebuilt uv-build archive |
| Windows x86_64, arm64, 386 | python.org EXE or MSI for CPython; GraalPy amd64 zip | python.org EXE or MSI for CPython; GraalPy amd64 zip | prebuilt uv-build archive |

In the default mode, a `VFOX_PYTHON_MIRROR` setting keeps CPython on the source
path, unless `VFOX_PYTHON_UV_BUILD_MIRROR` is also set.

The CPython source build takes the pyenv tag and version list, clones pyenv at
that tag, and runs its `python-build`. It needs a C toolchain and the headers
Python links against. The Windows path downloads the python.org installer,
installs its MSIs into the `python-<version>` directory and runs `ensurepip`; for an EXE,
the bundled WiX tools extract the MSIs first. It needs no compiler. GraalPy is
downloaded from Oracle's releases on every supported platform and unpacked; it
needs no compiler. Linux and macOS have amd64 and arm64 assets; Windows only
amd64.

## Version coverage

- **CPython source builds:** every CPython release in the pyenv list, including
  2.x, pre-releases and free-threaded versions whose name ends in `t`.
- **GraalPy:** releases with an asset for the platform and architecture, from
  GraalPy 22.3 onward. Linux and macOS use the version list pyenv provides;
  Windows lists the releases that have a `windows-amd64` asset. Windows arm64
  and 386 are not supported.
- **Windows CPython installers:** stable releases with an EXE or MSI for the
  architecture. Source-only security releases are omitted, releases before 2.5
  are not listed, and pre-release installer names do not match the exact stable
  filename; use uv-build for a pre-release on Windows.
- **uv-build:** CPython archives that the index has for the platform,
  architecture and libc, including `freethreaded` builds. GraalPy is not
  available in this mode. In the default mode on Linux and macOS, `vfox search
  python` lists the pyenv names together with these CPython releases; a version
  the index lacks is built from source.

A free-threaded release is selected with the same `t` suffix on every source:

```bash
vfox install python@3.13.1t
VFOX_PYTHON_USE_UV_BUILD=1 vfox install python@3.13t
```

A partial name resolves in each mode: `python@3.13t` is the newest free-threaded
3.13 release that the mode lists, and a plain `python@3.13` never picks a
free-threaded build. In the default mode on Linux and macOS, the uv-build index is
searched first; see [uv.md](uv.md).

Windows free-threaded releases come through uv-build; the stable installer list
does not include the `t` builds.

## Linux build dependencies

Only a **source build** needs the packages in this section. A CPython install
from uv-build needs none of them, and uv-build is the default for a version the
index lists:

| What you install | Needs these packages? |
| --- | --- |
| CPython, source build (a version the index lacks, or `VFOX_PYTHON_USE_UV_BUILD=0`) | yes |
| CPython, uv-build (the default for a listed version, or `VFOX_PYTHON_USE_UV_BUILD=1`) | no |
| GraalPy | no |

uv-build downloads a prebuilt CPython archive and GraalPy is an Oracle archive,
so neither runs a compiler. The Linux container suite checks the default case:
it starts an Ubuntu 24.04 image with no compiler and no `-dev` packages,
installs a CPython from the uv-build index, and imports `ssl`, `sqlite3`, `bz2`, `lzma`,
`ctypes`, `readline`, `curses`, `zlib` and `hashlib`.

On Ubuntu, the source build needs these packages:

```bash
sudo apt update
sudo apt install --assume-yes make build-essential libssl-dev zlib1g-dev \
  libbz2-dev libreadline-dev libsqlite3-dev wget curl llvm \
  libncursesw5-dev xz-utils tk-dev libxml2-dev libxmlsec1-dev \
  libffi-dev liblzma-dev
```

`zlib1g-dev` is the package most often missing. Without the zlib headers CPython
builds no `zlib` module, and `make install` then fails in ensurepip: pip is
installed from a wheel, which is a zip archive and needs zlib to be read
(`No module named 'zlib'`).

To avoid that step on Ubuntu, install a version the uv-build index lists. It
needs no `sudo` and no `apt`, and it is the default on Linux:

```bash
vfox install python@3.12.16
vfox use -g python@3.12.16
```

A partial name such as `python@3.12` picks the newest 3.12 that the uv-build index
lists, and installs its archive. A newer pyenv patch that the index does not list is
built from source, and only its exact name selects it.

Fedora and RHEL, for a source build:

```bash
sudo dnf install --assumeyes make gcc zlib-devel bzip2 bzip2-devel \
  readline-devel sqlite sqlite-devel openssl-devel tk-devel \
  libffi-devel xz-devel
```

Alpine, for a source build:

```bash
sudo apk add build-base zlib-dev bzip2-dev readline-dev sqlite-dev \
  openssl-dev tk-dev libffi-dev xz-dev
```

An old release can need an older OpenSSL or fail on a newer compiler. The
python-build output names the missing header; install that package, or use
uv-build when a prebuilt archive exists.

## macOS

Install the Command Line Tools once:

```bash
xcode-select --install
```

Homebrew's `openssl`, `readline`, `sqlite` and `xz` help older releases find
their headers and libraries. python-build sets the usual `CPPFLAGS` and
`LDFLAGS` for the Homebrew prefixes. If a build cannot find OpenSSL, set them
yourself:

```bash
export CPPFLAGS="$(brew --prefix openssl@3)/include"
export LDFLAGS="$(brew --prefix openssl@3)/lib"
export PKG_CONFIG_PATH="$(brew --prefix openssl@3)/lib/pkgconfig"
```

On Apple silicon, CPython 3.8.7 stops in `configure` with `Unexpected output of
'arch' on OSX`: that release's configure script accepts only `i386` and `ppc` from
`arch`. CPython 3.8.20 adds `arm64` to that check, so use 3.8.20 or a later 3.8
patch release. CPython 3.9.0's configure has the same check without `arm64`; later
3.9 patch releases were not checked.

Apple silicon builds are native arm64; an x86_64 shell under Rosetta builds an
x86_64 Python and installs it under the same vfox home.

## Windows

CPython comes from python.org. The plugin uses the **EXE** installer when
python.org publishes one for the architecture, and the **MSI** only when it does
not. It checks in this order:

1. `python-<version>-amd64.exe`, `python-<version>-arm64.exe`, or, for 32-bit,
   `python-<version>.exe`. The plugin sends a HEAD request for that file, and a
   200 response selects the EXE.
2. `python-<version>.amd64.msi`, `python-<version>.arm64.msi`, or, for 32-bit,
   `python-<version>.msi`, when step 1 finds nothing.

If neither exists, `vfox install` stops before it downloads anything, with
`Python <version> has no Windows installer on python.org`. Two examples from
python.org:

| Version | Published on python.org | Installer used |
| --- | --- | --- |
| 3.12.10 | `python-3.12.10-amd64.exe`, no MSI | EXE |
| 2.7.18 | `python-2.7.18.amd64.msi`, no EXE | MSI |

- **EXE:** the file is a bundle. The plugin extracts its MSIs with the bundled
  WiX `dark.exe`, deletes `launcher.msi`, `path.msi`, `appendpath.msi` and
  `pip.msi`, and installs the remaining MSIs into the `python-<version>` directory with
  `msiexec /quiet /a <msi> TargetDir=<dir>`. It then runs `ensurepip`. Because
  the launcher, PATH and pip MSIs are skipped, a vfox install adds no `py.exe`,
  does not change `PATH`, and gets pip from `ensurepip`.
- **MSI:** the plugin installs the MSI the same way, with
  `msiexec /quiet /a <msi> TargetDir=<dir>`, then runs `ensurepip` and creates
  the same `python3` aliases as the EXE route. python.org publishes 3.4.4 only as
  an MSI, and the Windows E2E suite installs that release this way.
- **Old MSI releases need their C runtime:** the `msiexec /a` install does not
  copy the Visual C++ runtime that the MSI's merge module would put in
  `System32`. CPython 3.4 links against `msvcr100.dll` from Visual C++ 2010. On a
  machine without that DLL, `python.exe` cannot start: the `ensurepip` step exits
  with `-1073741515` (0xC0000135, a DLL could not be found), and the install fails.
  Other old releases need the runtime of their own Visual Studio version. Install
  the runtime from an elevated PowerShell before you install the version:

  ```powershell
  Invoke-WebRequest -Uri https://download.microsoft.com/download/1/6/5/165255E7-1014-4D0A-B094-B6A430A6BFFC/vcredist_x64.exe -OutFile vcredist_x64.exe
  .\vcredist_x64.exe /quiet /norestart
  ```

Every route leaves `python.exe` in the `python-<version>` directory under the
version directory, for example
`%USERPROFILE%\.vfox\cache\python\v-3.12.10\python-3.12.10\python.exe`.

- The installer normally creates `python3.exe`, `python3.12.exe` and their
  `pythonw` counterparts in a shared directory. The plugin creates them next to
  `python.exe` so the selected version has them.
- Paths with spaces, `%`, `!` and single quotes are supported. They are passed
  through base64-encoded PowerShell arguments; `%` also makes the MSI path use
  a temporary junction, because Windows Installer expands `%` during file copy.
  See [development.md](development.md) and the Windows CI job.
- Installs are registered with the Python launcher by default, under
  `HKCU\Software\Python\VersionFox`, so `py -V:VersionFox/<version>` selects
  them. Set `VFOX_PYTHON_REGISTER_PY_LAUNCHER=0` to skip registration for new
  installs. The plugin does not write `PythonCore`; see
  [windows-launcher.md](windows-launcher.md) for the examples.
- GraalPy downloads `graalpy*-windows-amd64.zip` from Oracle's releases, checks
  its SHA-256 and unpacks it. `python.exe` is under `bin`; pip is bootstrapped
  with `ensurepip`. The PEP 514 `SysVersion` is the Python language version.
  See [graalpy.md](graalpy.md).

## uv-build

The endpoint is:

```text
https://vault.vfox.dev/python/uv-build?os=<linux|windows|darwin>&arch=<x86_64|aarch64|...>&libc=<gnu|musl>
```

On Linux, libc is detected unless `VFOX_PYTHON_UV_LIBC` is set. Windows and
macOS do not send `libc`. A platform without an archive fails before vfox
downloads anything with `VFOX_PYTHON_USE_UV_BUILD=1`; in the default mode, the
install builds from source instead. See [uv.md](uv.md) for archive selection and
checksums.

## Time and disk

A source build typically takes 5 to 15 minutes and a few hundred MB of
temporary space. The Windows installer and uv-build take seconds to a minute.
A GraalPy install is a download and unpack: about 150 MB on Linux and 600 MB on
Windows.

The E2E suites in `tests/e2e` cover these paths. On Linux the runner installs a
source build (`VFOX_PYTHON_USE_UV_BUILD=0`), a mirror build, uv-build (by its
minor version), GraalPy and `vfox link`, and a bare Ubuntu container installs a
CPython with the default settings, and GraalPy. On Windows
the runner installs the EXE installer, the MSI-only 3.4.4, a mirror build, uv-build
and GraalPy, and a Server Core container installs GraalPy.

## Python 2

Old 2.x releases appear where the source list or the Windows page has them.
They are unmaintained and many dependencies no longer build on current systems;
use them only for a legacy project that cannot move.
