# vfox-python

[中文](README_CN.md) | [English](README.md)

Python plugin for [vfox](https://vfox.dev/).

It installs CPython from python.org, compiles it from source on Linux and macOS,
or downloads a prebuilt uv-build archive. It also adopts the Pythons already on
the machine — system packages, uv, pyenv, Conda and others — and reads a
project's `.python-version`, so pyenv and uv projects open on the version they
name.

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

A version is the CPython release, such as `3.12.2`, `3.13.1` or `3.14.0a4`. A
free-threaded build ends in `t`, such as `3.14.0a4t`. A bare major version
selects the newest installed release of that line:

```bash
vfox install python@3.12       # newest 3.12.x
vfox install python@3.12.2     # exactly 3.12.2
vfox install python@3.14.0a4t  # free-threaded 3.14.0a4
```

The available versions depend on the platform:

| Platform | Default source | Versions |
| --- | --- | --- |
| Linux | source build with pyenv | every release pyenv knows |
| macOS | source build with pyenv | every release pyenv knows |
| Windows | python.org installer | stable releases with an EXE or MSI for the architecture |

On Windows, source-only security releases and pre-release or free-threaded
builds are left out because python.org's stable installer names do not cover
them. `VFOX_PYTHON_USE_UV_BUILD=1` switches to prebuilt uv-build archives on
Linux, macOS and Windows; see [docs/uv.md](docs/uv.md).

## Already installed Python

If a Python is already on the machine — from the system package manager, uv,
pyenv, asdf, mise, Conda, Homebrew or the python.org installer —
`vfox link --detect python` adopts it instead of downloading another copy
(needs vfox 1.1.0 or later):

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
```

## uv

uv-build is the optional prebuilt source:

```bash
export VFOX_PYTHON_USE_UV_BUILD=1
vfox install python@3.12.2
```

On Linux the libc is detected automatically; set `VFOX_PYTHON_UV_LIBC=gnu` or
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
- [uv and uv-build](docs/uv.md): prebuilt archives, uv-managed Pythons, and
  using uv with the interpreter vfox selected
- [Already installed Python](docs/link.md): `vfox link --detect python`, the
  system and uv installations it adopts, and how to use them safely
- [Platforms](docs/platforms.md): what is built from source, what is downloaded,
  and the build dependencies Linux needs
- [Mirror](docs/mirror.md): python.org and uv-build mirrors
- [Changes](docs/changes.md): what each release changed

**Working on the plugin**

- [Install from source](docs/install-from-source.md): trying `main` before the
  next release
- [Development](docs/development.md): layout, hooks, tests, checks and release

## Thanks

- [pyenv](https://github.com/pyenv/pyenv), whose version list and `python-build`
  the default Linux and macOS installs use
- [uv](https://github.com/astral-sh/uv), for the prebuilt Python archives and
  the `.python-version` convention
- [python.org](https://www.python.org/), for the releases and Windows installers
