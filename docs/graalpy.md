# GraalPy

[中文](zh-CN/graalpy.md) | [English](graalpy.md)

[GraalPy](https://www.graalvm.org/python/) is Oracle's Python implementation. It
is a Python 3 runtime with its own JVM and native-image builds. The plugin
installs both distributions that Oracle publishes:

| Name | Distribution | License |
| --- | --- | --- |
| `graalpy-<release>` | GraalPy built on Oracle GraalVM | GFTC |
| `graalpy-community-<release>` | GraalPy Community, built on GraalVM CE | GraalVM Community |

From GraalPy 25.1 the name also carries the Python language version:

| Name | Python | Distribution |
| --- | --- | --- |
| `graalpy-24.2.0` | 3.11 | Oracle GraalVM |
| `graalpy-community-24.2.0` | 3.11 | Community |
| `graalpy3.13-25.5.5` | 3.13 | Oracle GraalVM |
| `graalpy3.13-community-25.5.5` | 3.13 | Community |

The release number is the GraalPy/GraalVM release, not the Python language
version. `graalpy-24.2.0` runs Python 3.11.7; `graalpy3.13-25.5.5` runs Python
3.13.

## Install

```bash
vfox install python@graalpy-24.2.0
vfox install python@graalpy-community-24.2.0
vfox install python@graalpy3.13-25.5.5
vfox use --global python@graalpy-24.2.0
python -V
```

`vfox search python` marks the GraalPy entries in its notes:

```text
 - graalpy-24.2.0 (GraalPy)
 - graalpy-community-24.2.0 (GraalPy Community)
```

`latest` is resolved to the newest CPython release, not to GraalPy. Name a
GraalPy version explicitly when that is what the project needs.

## Platform support

| Platform | Source | Versions |
| --- | --- | --- |
| Linux x86_64 / arm64 | Oracle's release archive | every GraalPy release with a `linux-amd64` or `linux-aarch64` asset |
| macOS Intel / Apple silicon | Oracle's release archive | every GraalPy release with a `macos-amd64` or `macos-aarch64` asset |
| Windows amd64 | Oracle's release zip | every release with a `windows-amd64` asset |
| Windows arm64 / 386 | not supported | Oracle publishes no build |
| any, `VFOX_PYTHON_USE_UV_BUILD=1` | not supported | uv-build contains CPython only |

The plugin downloads the archive from
[oracle/graalpython](https://github.com/oracle/graalpython/releases), verifies
its SHA-256 checksum and unpacks it into the version directory. On Linux and
macOS the archive is a `.tar.gz`; the plugin runs its bundled `ensurepip`, so pip
does not need a network download. On Windows the archive is a `.zip`;
`python.exe` stays under `bin`, and the plugin adds both `bin` and `Scripts` to
`PATH`.

The Linux and macOS *version list* still comes from pyenv, but the GraalPy
download and installation are direct. No C toolchain is needed.

Oracle describes Windows support as experimental. Some packages with native
extensions may not have a GraalPy build.

On Windows, `vfox search python` reads the GraalPy release list from the GitHub
API. Set `GITHUB_TOKEN` or `GH_TOKEN` to raise GitHub's anonymous rate limit.
Installing a named version does not depend on that list: the plugin constructs
the official asset URL and verifies its `.sha256` file.

`VFOX_PYTHON_MIRROR` and `VFOX_PYTHON_UV_BUILD_MIRROR` do not apply to GraalPy
downloads.

## PEP 514 and `py.exe`

Like CPython, a Windows GraalPy install is registered under
`HKCU\Software\Python\VersionFox` by default; `VFOX_PYTHON_REGISTER_PY_LAUNCHER=0`
turns that off. The PEP 514 `SysVersion` is the Python language version (`3.11`
or `3.13`), not the GraalPy release, so `py -V:VersionFox/graalpy3.13-25.5.5` can
select it. GraalPy has no `pythonw.exe`, so the optional
`WindowedExecutablePath` value is omitted. See
[Windows Python launcher](windows-launcher.md).

## Existing GraalPy installations

`vfox link --detect python` adopts GraalPy as well as CPython. The name follows
the install naming and adds the source:

```bash
vfox link --detect python
vfox use --global python@graalpy-24.2.0-pyenv
vfox use --global python@graalpy-community-24.2.0-system
```

For a manual link, the path is the GraalPy prefix, the directory that contains
`bin` (on Windows, the directory that contains `bin\python.exe`):

```bash
vfox link python@graalpy-24.2.0-system /opt/graalpy-24.2.0
```

`vfox link` only adopts CPython and GraalPy. PyPy, Jython and other
implementations are still left out. See [Already installed
Python](link.md).

## `.python-version`

A project can select an installed GraalPy by name:

```text
graalpy-24.2.0
graalpy3.13-community-25.5.5
```

A bare `3.13` still means CPython, not the GraalPy build that runs Python 3.13.
See [Versions](versions.md#python-version) for the other forms the file accepts.
