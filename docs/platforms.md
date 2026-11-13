# Platforms

[中文](zh-CN/platforms.md) | [English](platforms.md)

## What is installed

| Platform | Default | `VFOX_PYTHON_USE_UV_BUILD=1` |
| --- | --- | --- |
| Linux x86_64 | source build with pyenv | prebuilt uv-build archive |
| Linux arm64 | source build with pyenv | prebuilt uv-build archive |
| Linux armv7 | source build with pyenv | prebuilt uv-build archive when available |
| Linux musl / Alpine | source build with pyenv | prebuilt musl archive |
| macOS Intel and Apple silicon | source build with pyenv | prebuilt uv-build archive |
| Windows x86_64, arm64, 386 | python.org EXE or MSI | prebuilt uv-build archive |

The source build takes the pyenv tag and version list, clones pyenv at that tag,
and runs its `python-build`. It needs a C toolchain and the headers Python
links against. The Windows path downloads the official installer, extracts the
MSIs with the bundled WiX tools and runs `ensurepip`; it needs no compiler.

## Version coverage

- **Source builds:** every CPython release in the pyenv list, including 2.x,
  pre-releases and free-threaded versions whose name ends in `t`.
- **Windows installers:** stable releases with an EXE or MSI for the
  architecture. Source-only security releases are omitted, releases before 2.5
  are not listed, and pre-release installer names do not match the exact stable
  filename; use uv-build for a pre-release on Windows.
- **uv-build:** CPython archives that the index has for the platform,
  architecture and libc, including `freethreaded` builds.

A free-threaded release is selected with the same `t` suffix on every source:

```bash
vfox install python@3.13.1t
VFOX_PYTHON_USE_UV_BUILD=1 vfox install python@3.13.1t
```

Windows free-threaded releases come through uv-build; the stable installer list
does not include the `t` builds.

## Linux build dependencies

Debian and Ubuntu:

```bash
sudo apt update
sudo apt install --assume-yes make build-essential libssl-dev zlib1g-dev \
  libbz2-dev libreadline-dev libsqlite3-dev wget curl llvm \
  libncursesw5-dev xz-utils tk-dev libxml2-dev libxmlsec1-dev \
  libffi-dev liblzma-dev
```

Fedora and RHEL:

```bash
sudo dnf install --assumeyes make gcc zlib-devel bzip2 bzip2-devel \
  readline-devel sqlite sqlite-devel openssl-devel tk-devel \
  libffi-devel xz-devel
```

Alpine:

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

- `python-<version>-amd64.exe` / `-arm64.exe` / `python-<version>.exe` (386)
  are extracted with `bin/WiX/dark.exe`. The embedded MSIs are installed into
  the version directory, then pip is bootstrapped with `ensurepip`.
- Older releases ship an MSI; it is installed with `msiexec /a` and pip is
  bootstrapped the same way.
- The installer normally creates `python3.exe`, `python3.12.exe` and their
  `pythonw` counterparts in a shared directory. The plugin creates them next to
  `python.exe` so the selected version has them.
- Paths with spaces, `%`, `!` and single quotes are supported. They are passed
  through base64-encoded PowerShell arguments; `%` also makes the MSI path use
  a temporary junction, because Windows Installer expands `%` during file copy.
  See [development.md](development.md) and the Windows CI job.
- Set `VFOX_PYTHON_REGISTER_PY_LAUNCHER=1` to register the installation under
  `HKCU\Software\Python\VersionFox` for `py.exe`. The plugin does not write
  `PythonCore`; see [windows-launcher.md](windows-launcher.md).

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
The CI E2E job installs a source build on Linux and an installer and uv-build on
Windows to keep both paths working.

## Python 2

Old 2.x releases appear where the source list or the Windows page has them.
They are unmaintained and many dependencies no longer build on current systems;
use them only for a legacy project that cannot move.
