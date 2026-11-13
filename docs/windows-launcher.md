# Windows Python launcher

[中文](zh-CN/windows-launcher.md) | [English](windows-launcher.md)

`py.exe` does not search `PATH`. It finds Python through PEP 514 registry
entries under `HKCU\Software\Python`. A vfox install therefore has no entry
unless vfox writes one, and `py -V:VersionFox/3.12.10` cannot find it even
though `python` on `PATH` works.

vfox writes an entry for every Windows install by default. To skip registration
for installs made afterwards, set `VFOX_PYTHON_REGISTER_PY_LAUNCHER=0` (or
`false`, `no`, `off`) before installing.

vfox does not install a launcher. Use the `py.exe` from your python.org
installation, or the `py` from the Python install manager. Python 3.14 deprecated
the `py.exe` launcher in favour of that install manager; both use PEP 514
registry entries. `py -0p` lists what the launcher can start, with paths.

## Which Python `py` selects

The short forms select python.org releases only. The company form selects from
the company you name:

| Command | Selects |
| --- | --- |
| `py`, `py -3`, `py -3.12` | python.org (PythonCore) releases only |
| `py -V:VersionFox/3.12` | vfox's 3.12 entries, the newest installed 3.12.x |
| `py -V:VersionFox/3.12.9` | vfox's 3.12.9 entry |
| `py -V:VersionFox/graalpy3.13` | vfox's GraalPy 3.13 entry |

`-V:` needs the launcher from Python 3.11 or later, or the Python install
manager. A tag may be shortened to a prefix that ends before a `.` or `-`: `3.1`
matches `3.1-32` but not `3.10`.

With a tag and no company, such as `py -V:3.12`, the launcher searches every
company. The documentation does not say which entry wins when two companies
share a tag, so use the company form for vfox installs.

Install two patch releases and list them:

```powershell
vfox install python@3.12.9
vfox install python@3.12.10

py --list
py -0p
```

`py --list` prints the tags, and `py -0p` prints the same runtimes with their
executable paths. The output is abbreviated, and `*` marks the default that a
bare `py` runs:

```text
 -V:3.13 *        C:\Users\you\AppData\Local\Programs\Python\Python313\python.exe
 -V:VersionFox/3.12.10 C:\Users\you\.vfox\cache\python\v-3.12.10\python.exe
 -V:VersionFox/3.12.9 C:\Users\you\.vfox\cache\python\v-3.12.9\python.exe
```

Two patch releases can coexist because each has its own tag. PythonCore has one
slot per minor version, so python.org cannot register 3.12.9 and 3.12.10 side by
side.

## What `py.exe` is useful for

These examples assume the vfox installs named above.

### Run a project on a chosen vfox install

```powershell
cd C:\src\billing
py -V:VersionFox/3.12.10 -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install -r requirements.txt
```

The venv records the interpreter it was made from. If you later uninstall
`3.12.10`, that venv stops working, so recreate it with another version.

### Keep the python.org Python as the default

The official install stays the default. `py script.py`, `py -3` and `py -3.12`
still select python.org releases only, so scripts and tools that call the bare
launcher behave as before. A vfox install is used only when you name it.

### Compare GraalPy with CPython

```powershell
py -V:VersionFox/graalpy3.13 -c "import sys; print(sys.implementation.name, sys.version.split()[0])"
py -V:VersionFox/3.13 -c "import sys; print(sys.implementation.name, sys.version.split()[0])"
```

The first line prints `graalpy`, and the second prints `cpython`. This assumes
both runtimes are installed.

### Run a windowed script

```powershell
pyw -V:VersionFox/3.12.10 app.pyw
```

`pyw` runs the `WindowedExecutablePath`, which is `pythonw.exe`, so no console
window opens. GraalPy has no `pythonw.exe` and no windowed path is written, so
`pyw` runs its `python.exe` and a console window stays open.

### Check which interpreter ran

```powershell
py -V:VersionFox/3.12 -c "import sys; print(sys.executable)"
```

This prints the path of the interpreter that actually ran, which is useful when
several installs share a version.

### Editors and other tools

PEP 514 is the format the PEP names for editors that list interpreters, such as
PyCharm and Visual Studio. vfox writes the same format, so tools that read PEP
514 can find vfox installs.

## What is registered

Each installed version gets a key under vfox's own company name, `VersionFox`:

```text
HKCU\Software\Python\VersionFox\3.12.10
    DisplayName = "Python 3.12.10 (vfox)"
    SysVersion = "3.12"
    SysArchitecture = "64bit"
    VfoxManaged = "1"
    InstallPath
        (Default) = "C:\Users\you\.vfox\cache\python\v-3.12.10"
        ExecutablePath = "C:\Users\you\.vfox\cache\python\v-3.12.10\python.exe"
        WindowedExecutablePath = "C:\Users\you\.vfox\cache\python\v-3.12.10\pythonw.exe"
```

The values follow PEP 514. `InstallPath` is the install directory, and
`ExecutablePath` points at its `python.exe`, which is under `bin\` for GraalPy.
For the python.org EXE and MSI installers the install directory is the version
directory itself. uv-build keeps the interpreter one level down, in
`python-3.12.10\`, and the entries point there.
`VfoxManaged = "1"` marks entries vfox wrote, and `vfox uninstall` removes only
those.

The tag is the full version, with `-32` or `-arm64` for other architectures, so
several patch releases can coexist:

| Build | Tag |
| --- | --- |
| x86_64 | `3.12.10` |
| 32-bit | `3.12.10-32` |
| ARM64 | `3.12.10-arm64` |
| free-threaded | `3.13.1t` |

GraalPy is registered the same way. Its tag is the version name, such as
`graalpy3.13-community-25.5.5`. Its `SysVersion` is the Python language version
(`3.13`), not the GraalPy release, and no `WindowedExecutablePath` is written
because GraalPy has no `pythonw.exe`. See [GraalPy](graalpy.md).

## Why not `PythonCore`

`PythonCore` is python.org's company name. A per-user `PythonCore\3.12` entry
would take precedence over the official 3.12 installed for all users, because
PEP 514 makes per-user entries win, and it would hide that install from `py`.
PythonCore also has one slot per minor version. vfox therefore writes its own
company key and never touches `PythonCore`.

## Removing and disabling

`vfox uninstall python@3.12.10` removes that version's entry, but only when the
entry carries `VfoxManaged = "1"` and still points at that version's directory.

`VFOX_PYTHON_REGISTER_PY_LAUNCHER=0` stops registration for installs made
afterwards. Entries that already exist stay until their version is uninstalled.
To remove them all, delete `HKCU\Software\Python\VersionFox`.

The reverse direction is `vfox link --detect python`. It links the Pythons that
`py -0p` reports, but it skips vfox's own installs. See [link.md](link.md).
