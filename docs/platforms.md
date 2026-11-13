# Platforms

[中文](zh-CN/platforms.md) | [English](platforms.md)

## What is installed

| Platform | Default | `VFOX_PYTHON_USE_UV_BUILD=1` |
| --- | --- | --- |
| Linux x86_64 | source build with pyenv for CPython; Oracle archive for GraalPy | prebuilt uv-build archive |
| Linux arm64 | source build with pyenv for CPython; Oracle archive for GraalPy | prebuilt uv-build archive |
| Linux armv7 | source build with pyenv for CPython; no GraalPy build | prebuilt uv-build archive when available |
| Linux musl / Alpine | source build with pyenv | prebuilt musl archive |
| macOS Intel and Apple silicon | source build with pyenv for CPython; Oracle archive for GraalPy | prebuilt uv-build archive |
| Windows x86_64, arm64, 386 | python.org EXE or MSI for CPython; GraalPy amd64 zip | prebuilt uv-build archive |

The CPython source build takes the pyenv tag and version list, clones pyenv at
that tag, and runs its `python-build`. It needs a C toolchain and the headers
Python links against. The Windows path downloads the python.org installer,
extracts its MSIs with the bundled WiX tools and runs `ensurepip`; it needs no
compiler. GraalPy is downloaded from Oracle's releases on every supported
platform and unpacked; it needs no compiler. Linux and macOS have amd64 and
arm64 assets; Windows only amd64.

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
  available in this mode.

A free-threaded release is selected with the same `t` suffix on every source:

```bash
vfox install python@3.13.1t
VFOX_PYTHON_USE_UV_BUILD=1 vfox install python@3.13.18t
```

The uv-build name is the one `vfox search python` shows while the variable is
set; its free-threaded names end in `t`, such as `3.13.18t`.

Windows free-threaded releases come through uv-build; the stable installer list
does not include the `t` builds.

## Linux build dependencies

Only a **source build** needs the packages in this section, and a source build
is the default for CPython on Linux. Two other paths need none of them:

| What you install | Needs these packages? |
| --- | --- |
| CPython, source build (default) | yes |
| CPython, with `VFOX_PYTHON_USE_UV_BUILD=1` | no |
| GraalPy | no |

uv-build downloads a prebuilt CPython archive and GraalPy is an Oracle archive,
so neither runs a compiler. The Linux container suite checks the uv-build case:
it starts an Ubuntu 24.04 image with no compiler and no `-dev` packages,
installs a uv-build CPython, and imports `ssl`, `sqlite3`, `bz2`, `lzma`,
`ctypes`, `readline`, `curses`, `zlib` and `hashlib`.

On Ubuntu, the source build needs these packages:

```bash
sudo apt update
sudo apt install --assume-yes make build-essential libssl-dev zlib1g-dev \
  libbz2-dev libreadline-dev libsqlite3-dev wget curl llvm \
  libncursesw5-dev xz-utils tk-dev libxml2-dev libxmlsec1-dev \
  libffi-dev liblzma-dev
```

To avoid that step on Ubuntu, use uv-build. It needs no `sudo` and no `apt`.
Install a name that `vfox search python` shows while the variable is set:

```bash
export VFOX_PYTHON_USE_UV_BUILD=1
vfox install python@3.12.16
```

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

If neither exists, the install fails with `No available installer found for
current version`. Two examples from python.org:

| Version | Published on python.org | Installer used |
| --- | --- | --- |
| 3.12.10 | `python-3.12.10-amd64.exe`, no MSI | EXE |
| 2.7.18 | `python-2.7.18.amd64.msi`, no EXE | MSI |

- **EXE:** the file is a bundle. The plugin extracts its MSIs with the bundled
  WiX `dark.exe`, deletes `launcher.msi`, `path.msi`, `appendpath.msi` and
  `pip.msi`, and installs the remaining MSIs into the version directory with
  `msiexec /quiet /a <msi> TargetDir=<dir>`. It then runs `ensurepip`. Because
  the launcher, PATH and pip MSIs are skipped, a vfox install adds no `py.exe`,
  does not change `PATH`, and gets pip from `ensurepip`.
- **MSI:** the plugin installs the MSI the same way, with
  `msiexec /quiet /a <msi> TargetDir=<dir>`, and then runs `ensurepip`.

Both routes leave `python.exe` directly in the version directory, for example
`%USERPROFILE%\.vfox\cache\python\v-3.12.10\python.exe`.

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
downloads anything. See [uv.md](uv.md) for archive selection and checksums.

## Time and disk

A source build typically takes 5 to 15 minutes and a few hundred MB of
temporary space. The Windows installer and uv-build take seconds to a minute.
A GraalPy install is a download and unpack: about 150 MB on Linux and 600 MB on
Windows.

The E2E suites in `tests/e2e` cover these paths. On Linux the runner installs a
source build, a mirror build, uv-build, GraalPy and `vfox link`, and a bare
Ubuntu container installs uv-build and GraalPy. On Windows the runner installs
the EXE installer, a mirror build, uv-build and GraalPy, and a Server Core
container installs GraalPy.

## Python 2

Old 2.x releases appear where the source list or the Windows page has them.
They are unmaintained and many dependencies no longer build on current systems;
use them only for a legacy project that cannot move.
