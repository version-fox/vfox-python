# Use a Python that is already installed

[中文](zh-CN/link.md) | [English](link.md)

If a Python is already on the machine, `vfox link --detect python` adopts it
instead of downloading another copy. It needs vfox 1.1.0 or later
(`vfox --version`). The plugin looks for CPython and GraalPy, asks each
interpreter for its version and prefix, and reports the installations it can
link:

```bash
vfox link --detect python
```

vfox lists what it found; pick the ones to link, or use `-y` to link everything
without asking:

```bash
vfox link --detect python -y
```

A linked version is a symlink to the installation. Nothing is copied, the
installation stays where it is and stays its owner's, and `vfox uninstall`
removes only the link. `vfox list python` marks linked versions, and
`vfox info --json python@<version>` shows `origin: linked` and the `target`.

## Where it looks

| Source | Where the plugin looks | Name suffix |
| --- | --- | --- |
| `PATH` | `python3` and `python`, or `python.exe` and `python3.exe` | by location |
| Oracle GraalPy | `~/graalpy*`, `/opt/graalpy*`, `C:\graalpy*`, or `PATH` | `-system` or `-opt` |
| uv | `UV_PYTHON_INSTALL_DIR`, `uv python dir`, or the uv default directory | `-uv` |
| pyenv | `$PYENV_ROOT/versions`, default `~/.pyenv/versions` | `-pyenv` |
| asdf | `$ASDF_DATA_DIR/installs/python`, default `~/.asdf/installs/python` | `-asdf` |
| mise | `$MISE_DATA_DIR/installs/python`, default `~/.local/share/mise/installs/python` | `-mise` |
| Conda | `CONDA_PREFIX`, `~/miniconda3`, `~/anaconda3`, `~/miniforge3`, `~/mambaforge`, `/opt/conda`, `/opt/miniconda3`, `/opt/miniforge3` | `-conda` |
| Linux system | `/usr`, `/usr/local`, `/opt/python` | `-system`, `-local`, `-opt` |
| Homebrew | `/opt/homebrew`, `/home/linuxbrew/.linuxbrew` | `-brew` |
| Nix and Snap | interpreters on `PATH` under `/nix/store` or `/snap` | `-nix`, `-snap` |
| macOS python.org | `/Library/Frameworks/Python.framework/Versions/*` | `-pythonorg` |
| Windows python.org | `%LOCALAPPDATA%\Programs\Python\Python*`, `%ProgramFiles%\Python*`, `%ProgramFiles(x86)%\Python*`, `C:\Python*` | `-pythonorg` |
| Windows py launcher | every path `py -0p` reports | by location |
| Microsoft Store | `%LOCALAPPDATA%\Microsoft\WindowsApps\PythonSoftwareFoundation.Python.*` | `-store` |
| Scoop | `~/scoop/apps/python/current` | `-scoop` |

The uv directory is `%APPDATA%\uv\python` on Windows and
`$XDG_DATA_HOME/uv/python` or `~/.local/share/uv/python` elsewhere.

CPython and GraalPy are reported. PyPy, Jython and other implementations are
left out. GraalPy keeps its own name, so a GraalPy 24.2.0 installation becomes
`graalpy-24.2.0-<source>`, and a Community build becomes
`graalpy-community-24.2.0-<source>`; from GraalPy 25.1 the name includes the
Python language version, as in `graalpy3.13-25.5.5-<source>`. Naming a
non-CPython implementation after a CPython version would be misleading.

## Names

The name is `<version>-<source>`, such as `3.12.8-system`, `3.13.1-uv`,
`3.12.10-pythonorg` or `graalpy-24.2.0-pyenv`. A free-threaded CPython build
keeps its `t`: `3.14.0a4t-uv`. A GraalPy name also records the Community
edition: `graalpy-community-24.2.0-system`, and from GraalPy 25.1 it includes
the Python language version: `graalpy3.13-25.5.5-uv`. The version comes from
the interpreter itself, not from the directory name, so a renamed uv directory
still reports the right version.

`vfox link` refuses a name that is already taken, and a directory that some
version already links to. The plugin also skips:

- a virtual environment (`sys.prefix` differs from `sys.base_prefix`); its base
  Python is found separately,
- a Python under the vfox home, which is already a vfox version,
- a broken Windows Store alias that exists but cannot run,
- a second installation that would get the same name.

Use `vfox use python@3.12.8-system` for the linked version. `vfox use
python@3.12` matches installed versions by prefix, so it can also select the
linked one.

## Manual linking

When `--detect` does not find an installation, link it by hand. The path is the
Python prefix: the directory that contains `bin` on Unix, or `python.exe` on
Windows, not `bin` itself.

```bash
vfox link python@3.12.8-system /usr
vfox link python@3.13.1-uv /home/me/.local/share/uv/python/cpython-3.13.1-linux-x86_64-gnu
vfox use python@3.12.8-system
```

A name that is already linked can be pointed somewhere else with `--force`:

```bash
vfox link --force python@3.12.8-system /usr/local
```

`--force` never replaces a version vfox installed; uninstall that version first.

## System Python

A linked system Python is the distribution's Python. That has consequences:

- Debian and Ubuntu often have `python3` but no `python`. Selecting
  `python@3.12.3-system` puts `/usr/bin` on `PATH`; run `python3`, not `python`.
- The distribution may not ship pip. `python3 -m pip` then says
  `No module named pip`; install `python3-pip`, or use a virtual environment.
- PEP 668 marks the system environment as externally managed, so pip refuses to
  install into it. Create a virtual environment instead:

  ```bash
  python3 -m venv .venv
  . .venv/bin/activate
  ```

  Debian and Ubuntu need `sudo apt install python3-venv`; building packages with
  a C extension also needs `python3-dev`.
- A distribution upgrade can move `/usr/bin/python3` to a new version. The
  linked version follows the symlink, so its reported version can change;
  re-run `vfox link --detect python` if you want a new name.
- Do not `pip install` into a linked Python, and do not use
  `uv pip install --system` against it. Both write into the distribution's
  environment. Use a venv, or install a Python owned by vfox or uv.

The same rule applies to a uv-managed base interpreter and a Conda base
environment: link it to make tools find it, but keep project packages in a
virtual environment.

## Best practices

- Pick one owner for each interpreter. Either vfox installs it, or it stays a
  system/uv/pyenv installation and vfox links it; do not keep two copies of the
  same release for the same job.
- Use the system Python for tools that expect the distribution's interpreter.
  Use a vfox, uv or pyenv Python for project work, where you can create
  environments without touching the system.
- Commit `.python-version` (or `.tool-versions`) so the selected version is
  reproducible. The plugin reads both conventions.
- Keep global selections for tools that need a Python everywhere; select
  project versions in the project directory.
- After a system upgrade, run `vfox link --detect python` again. Installations
  that disappeared are reported as missing versions.
