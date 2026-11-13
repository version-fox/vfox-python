# vfox-python

[中文](README_CN.md) | [English](README.md)

Python plugin for [vfox](https://vfox.dev/).

It installs CPython from python.org, compiles CPython from source on Linux and
macOS, or downloads a prebuilt uv-build archive. GraalPy comes from Oracle's
release archives on every supported platform. It also adopts the Pythons
already on the machine — system packages, uv, pyenv, Conda and others — and
reads a project's `.python-version`, so pyenv and uv projects open on the
version they name.

## Install

After installing [vfox](https://github.com/version-fox/vfox), install the plugin
and a Python, and select it:

```bash
vfox add python
vfox install python@3.12.2
vfox use --global python@3.12.2
python -V
```

`vfox search python` lists the available versions. For the newest one use
`latest`:

```bash
vfox install python@latest
```

`python -V` shows the selected interpreter. For `python` to be on the `PATH`,
vfox has to be hooked into your shell; see its
[quick start](https://vfox.dev/guides/quick-start.html).

## Versions

A version is the CPython release, such as `3.12.2`, `3.13.1` or `3.14.0a4`, or
a GraalPy release, such as `graalpy-24.2.0` or `graalpy3.13-community-25.5.5`.
A free-threaded CPython build ends in `t`, such as `3.14.0a4t`. A bare major
version selects the newest installed release of that line:

```bash
vfox install python@3.12       # newest 3.12.x
vfox install python@3.12.2     # exactly 3.12.2
vfox install python@3.14.0a4t  # free-threaded 3.14.0a4
vfox install python@graalpy-24.2.0
```

The available versions depend on the platform:

| Platform | Default source | Versions |
| --- | --- | --- |
| Linux | pyenv source build for CPython; Oracle archive for GraalPy | every release pyenv knows, including GraalPy, PyPy and Conda |
| macOS | pyenv source build for CPython; Oracle archive for GraalPy | every release pyenv knows, including GraalPy, PyPy and Conda |
| Windows | python.org installer for CPython; Oracle zip for GraalPy | stable CPython installers for the architecture, plus GraalPy amd64 releases |

On Windows, source-only security releases and pre-release or free-threaded
CPython builds are left out because python.org's stable installer names do not
cover them. `VFOX_PYTHON_USE_UV_BUILD=1` switches to prebuilt uv-build archives
on Linux, macOS and Windows; uv-build contains CPython only. See
[docs/uv.md](docs/uv.md).

`py.exe` does not read `PATH`. Windows installs are registered automatically
under vfox's own PEP 514 key, so `py -V:VersionFox/<version>` can select them.
Set `VFOX_PYTHON_REGISTER_PY_LAUNCHER=0` to opt out; see [Windows Python
launcher](docs/windows-launcher.md).

## GraalPy

[GraalPy](https://www.graalvm.org/python/) is Oracle's Python implementation.
The plugin installs both distributions:

| Version name | Distribution | License |
| --- | --- | --- |
| `graalpy-24.2.0`, `graalpy3.13-25.5.5` | GraalPy built on Oracle GraalVM | GFTC |
| `graalpy-community-24.2.0`, `graalpy3.13-community-25.5.5` | GraalPy Community (GraalVM CE) | Community |

```bash
vfox install python@graalpy-24.2.0
vfox install python@graalpy-community-24.2.0
vfox use --global python@graalpy-24.2.0
```

On Linux and macOS the plugin downloads Oracle's official tar.gz and runs the
bundled `ensurepip`; the version list still comes from pyenv. On Windows it
downloads the official amd64 zip. Windows arm64 and 386 are not supported
because Oracle does not publish those builds. `VFOX_PYTHON_MIRROR` does not
apply to GraalPy downloads. GraalPy is not part of uv-build, so
`VFOX_PYTHON_USE_UV_BUILD=1` lists CPython only. `vfox link --detect python`
adopts existing GraalPy installations. See [GraalPy](docs/graalpy.md) for the
version-name rules, platform limits and PEP 514 registration.

## Already installed Python

If a Python or GraalPy is already on the machine — from the system package
manager, uv, pyenv, asdf, mise, Conda, Homebrew, the python.org installer or
Oracle's GraalPy archive — `vfox link --detect python` adopts it instead of
downloading another copy (needs vfox 1.1.0 or later):

```bash
vfox link --detect python
vfox use --global python@3.12.8-system
```

The plugin lists what it found and links what you pick; `-y` links everything
without asking. A linked version is a symlink: the installation stays where it
is, and `vfox uninstall` removes only the link. See
[docs/link.md](docs/link.md) for the directories it scans, the names it gives
them, and what it skips.

A `.python-version` file selects an installed version when vfox changes into a
project, so projects written for pyenv or uv work unchanged:

```bash
echo 3.12 > .python-version
echo graalpy-24.2.0 > .python-version
```

## uv

uv-build is the optional prebuilt source. Its index lists exact versions, so
install a name that `vfox search python` shows while the variable is set; a
partial name such as `python@3.12` does not resolve in this mode:

```bash
export VFOX_PYTHON_USE_UV_BUILD=1
vfox install python@3.12.16
```

uv-build needs no compiler or build dependencies. On Linux the libc is
detected automatically; set `VFOX_PYTHON_UV_LIBC=gnu` or
`VFOX_PYTHON_UV_LIBC=musl` to override it. uv-managed Pythons from
`uv python install` are picked up by `vfox link --detect python` like any other
installation. See [docs/uv.md](docs/uv.md) for the archive and for how to make
uv use the interpreter vfox selected, instead of downloading one of its own.

## Mirror

Set `VFOX_PYTHON_MIRROR` to download from a mirror with the same layout as
`https://www.python.org/ftp/python/`:

```bash
export VFOX_PYTHON_MIRROR=https://mirrors.huaweicloud.com/python/
```

uv-build downloads can go through `VFOX_PYTHON_UV_BUILD_MIRROR`. See
[docs/mirror.md](docs/mirror.md) for both and for what a mirror must contain.

## Documentation

**Using the plugin**

- [Versions](docs/versions.md): version names, free-threaded builds, `latest`,
  and which versions each platform has
- [GraalPy](docs/graalpy.md): Oracle and Community distributions, platform
  support, `vfox link` and PEP 514
- [uv and uv-build](docs/uv.md): prebuilt archives, uv-managed Pythons, and
  using uv with the interpreter vfox selected
- [Already installed Python](docs/link.md): `vfox link --detect python`, the
  system and uv installations it adopts, and how to use them safely
- [Platforms](docs/platforms.md): what is built from source, what is downloaded,
  and the build dependencies Linux needs
- [Windows Python launcher](docs/windows-launcher.md): PEP 514 registration
  for `py.exe`, on by default, with examples of selecting vfox installs
- [Mirror](docs/mirror.md): python.org and uv-build mirrors
- [Changes](docs/changes.md): what each release changed

**Working on the plugin**

- [Install from source](docs/install-from-source.md): trying `main` before the
  next release
- [End-to-end tests](docs/e2e.md): the Linux and Windows container suites and
  the runner matrix
- [Development](docs/development.md): layout, hooks, tests, checks and release

## Thanks

- [pyenv](https://github.com/pyenv/pyenv), whose version list and `python-build`
  the default Linux and macOS installs use
- [uv](https://github.com/astral-sh/uv), for the prebuilt Python archives and
  the `.python-version` convention
- [python.org](https://www.python.org/), for the releases and Windows installers
- [Oracle GraalPy](https://github.com/oracle/graalpython), for the GraalPy
  releases
