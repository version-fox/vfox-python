# Windows Python launcher

[中文](zh-CN/windows-launcher.md) | [English](windows-launcher.md)

`py.exe` does not search `PATH`; it discovers Python installations through
PEP 514 registry entries. A Python installed by vfox is therefore invisible to
`py`, to `.py` file associations, and to tools that run `py -3.x`.

The plugin can register its Windows installations with the launcher. This is
opt-in: without `VFOX_PYTHON_REGISTER_PY_LAUNCHER=1`, vfox does not write to the
registry.

```powershell
$env:VFOX_PYTHON_REGISTER_PY_LAUNCHER = "1"
vfox install python@3.12.10
py --list
py -V:VersionFox/3.12 -c "import sys; print(sys.version)"
```

## What is registered

Each installed version is written under vfox's own company key:

```text
HKCU\Software\Python\VersionFox\3.12.10
    DisplayName = "Python 3.12.10 (vfox)"
    SysVersion = "3.12"
    SysArchitecture = "64bit"
    InstallPath
        (Default) = "C:\Users\...\python-3.12.10"
        ExecutablePath = "C:\Users\...\python-3.12.10\python.exe"
        WindowedExecutablePath = "C:\Users\...\python-3.12.10\pythonw.exe"
    VfoxManaged = "1"
```

The values follow PEP 514. `VfoxManaged` is private to the plugin and lets
`vfox uninstall` remove only entries it created.

Tags use the full version, so several patch releases can coexist:

| Build | Tag |
| --- | --- |
| x86_64 | `3.12.10` |
| 32-bit | `3.12.10-32` |
| ARM64 | `3.12.10-arm64` |
| free-threaded | `3.14.0a4t` |

`py -V:VersionFox/3.12` selects the newest vfox-installed 3.12, or use the exact
tag from `py --list`.

GraalPy is registered the same way. Its tag is the version name, and
`SysVersion` is the Python language version:

```text
HKCU\Software\Python\VersionFox\graalpy-community-24.2.0
    DisplayName = "GraalPy Community 24.2.0 (vfox)"
    SysVersion = "3.11"
    ExecutablePath = "...\graalpy-community-24.2.0-windows-amd64\bin\python.exe"
```

GraalPy has no `pythonw.exe`, so `WindowedExecutablePath` is omitted. From
GraalPy 25.1 the tag includes the Python language version, such as
`graalpy3.13-25.5.5`. See [GraalPy](graalpy.md).

## Why not `PythonCore`

`PythonCore` is python.org's identity. A per-user `PythonCore\3.12` entry would
take precedence over a machine-wide official 3.12 and hide it from `py`; it also
has only one slot per minor version, while vfox can install several patch
releases side by side. The plugin never writes there.

As a result, `py -3.12` continues to select `PythonCore` only, by design. Use
`py -V:VersionFox/3.12` or the exact tag. The `-V:` option requires the launcher
from Python 3.11 or newer, or the Python install manager.

## Removing and disabling

`vfox uninstall python@3.12.10` removes the entry when it still points at that
version. The variable only affects new installs; uninstall and reinstall an
existing version to register it. Unset the variable to stop registering future
installs. Existing entries can also be deleted under
`HKCU\Software\Python\VersionFox`.

The reverse direction is covered by `vfox link --detect python`, which adopts
Pythons that `py` reports. See [link.md](link.md).
