# Windows Python 启动器

[中文](windows-launcher.md) | [English](../windows-launcher.md)

`py.exe` 不扫描 `PATH`，而是通过 PEP 514 注册表发现 Python。因此 vfox 安装的
Python 对 `py`、`.py` 文件关联以及运行 `py -3.x` 的工具都不可见。

插件可以把 Windows 上安装的版本注册到启动器。这个功能默认关闭：不设置
`VFOX_PYTHON_REGISTER_PY_LAUNCHER=1` 时，vfox 不会写注册表。

```powershell
$env:VFOX_PYTHON_REGISTER_PY_LAUNCHER = "1"
vfox install python@3.12.10
py --list
py -V:VersionFox/3.12 -c "import sys; print(sys.version)"
```

## 注册了什么

每个已安装版本写在 vfox 自己的 company key 下：

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

这些值遵循 PEP 514。`VfoxManaged` 是插件私有的标记，`vfox uninstall` 只删除
自己创建的项。

tag 使用完整版本号，所以多个补丁版本可以并存：

| 构建 | tag |
| --- | --- |
| x86_64 | `3.12.10` |
| 32 位 | `3.12.10-32` |
| ARM64 | `3.12.10-arm64` |
| 自由线程 | `3.14.0a4t` |

`py -V:VersionFox/3.12` 会选 vfox 安装的最新 3.12，也可以直接用 `py --list` 里
的完整 tag。

GraalPy 也按同样方式注册。tag 是版本名，`SysVersion` 是 Python 语言版本：

```text
HKCU\Software\Python\VersionFox\graalpy-community-24.2.0
    DisplayName = "GraalPy Community 24.2.0 (vfox)"
    SysVersion = "3.11"
    ExecutablePath = "...\graalpy-community-24.2.0-windows-amd64\bin\python.exe"
```

GraalPy 没有 `pythonw.exe`，所以不写 `WindowedExecutablePath`。从 GraalPy
25.1 开始，tag 里会带上 Python 语言版本，比如 `graalpy3.13-25.5.5`。见
[GraalPy](graalpy.md)。

## 为什么不写 `PythonCore`

`PythonCore` 是 python.org 的身份。用户级的 `PythonCore\3.12` 会优先于机器上
官方安装的 3.12，让它在 `py` 里消失；而且每个 minor 版本只有一个位置，vfox 却
可以同时装多个补丁版本。插件不会写这个位置。

因此 `py -3.12` 仍然只选 `PythonCore`，这是启动器的设计。用
`py -V:VersionFox/3.12` 或完整 tag 来选 vfox 的 Python。`-V:` 需要 Python 3.11
或更新版本自带的启动器，或者新的 Python install manager。

## 删除与关闭

`vfox uninstall python@3.12.10` 在注册项仍指向该版本时删除它。这个变量只影响
新安装；要让已安装的版本也注册，先卸载再重新安装。取消变量后，后续安装不再
注册。已有的项也可以直接在 `HKCU\Software\Python\VersionFox` 下删除。

反过来，`vfox link --detect python` 会纳入 `py` 报告的 Python。见
[link.md](link.md)。
