# Windows Python 启动器

[中文](windows-launcher.md) | [English](../windows-launcher.md)

`py.exe` 不扫描 `PATH`，而是通过 `HKCU\Software\Python` 下的 PEP 514 注册项找到
Python。所以 vfox 安装的 Python 如果没有注册项，`py -V:VersionFox/3.12.10` 就找不到它，
即使 `PATH` 上的 `python` 能用。

vfox 默认会为每个 Windows 安装写入注册项。想让之后的安装不注册，安装前设置
`VFOX_PYTHON_REGISTER_PY_LAUNCHER=0`（或 `false`、`no`、`off`）。

vfox 不安装启动器。请使用 python.org 安装包带的 `py.exe`，或者 Python install manager
提供的 `py`。Python 3.14 起 `py.exe` 启动器已被 install manager 取代，两者都使用 PEP 514
注册项。`py -0p` 会列出启动器能启动的所有 Python 及其路径。

## `py` 会选哪个 Python

短形式只选 python.org（PythonCore）的版本。公司形式只从你指定的公司里选：

| 命令 | 选中 |
| --- | --- |
| `py`、`py -3`、`py -3.12` | 只选 python.org（PythonCore）版本 |
| `py -V:VersionFox/3.12` | vfox 的 3.12 项，即已安装的最新 3.12.x |
| `py -V:VersionFox/3.12.9` | vfox 的 3.12.9 项 |
| `py -V:VersionFox/graalpy3.13` | vfox 的 GraalPy 3.13 项 |

`-V:` 需要 Python 3.11 或更新版本自带的启动器，或者 Python install manager。tag 可以
缩写成在 `.` 或 `-` 之前结束的前缀：`3.1` 匹配 `3.1-32`，但不匹配 `3.10`。

只写 tag、不写公司（比如 `py -V:3.12`）时，启动器会搜索所有公司。文档没有说明两个公司
提供相同 tag 时哪个优先，所以选 vfox 的版本请使用公司形式。

安装两个补丁版本并列出来：

```powershell
vfox install python@3.12.9
vfox install python@3.12.10

py --list
py -0p
```

`py --list` 列出 tag，`py -0p` 列出同样的运行时及其可执行文件路径。输出是缩略的，`*`
标记裸 `py` 会运行的默认版本：

```text
 -V:3.13 *        C:\Users\you\AppData\Local\Programs\Python\Python313\python.exe
 -V:VersionFox/3.12.10 C:\Users\you\.vfox\cache\python\v-3.12.10\python-3.12.10\python.exe
 -V:VersionFox/3.12.9 C:\Users\you\.vfox\cache\python\v-3.12.9\python-3.12.9\python.exe
```

两个补丁版本可以并存，因为每个版本都有自己的 tag。PythonCore 每个 minor 版本只有一个
位置，所以 python.org 的安装没法同时注册 3.12.9 和 3.12.10。

## `py.exe` 的实际用途

下面的例子假设已经安装了上面的 vfox 版本。

### 用指定的 vfox 版本运行项目

```powershell
cd C:\src\billing
py -V:VersionFox/3.12.10 -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install -r requirements.txt
```

虚拟环境会记住创建它时用的解释器。之后如果卸载 `3.12.10`，这个虚拟环境就不能用了，
需要用其他版本重新创建。

### python.org 的 Python 仍然是默认

官方安装仍然是默认。`py script.py`、`py -3` 和 `py -3.12` 仍然只选 python.org 的版本，
调用裸启动器的脚本和工具行为不变。只有显式指定时才会用到 vfox 的版本。

### 对比 GraalPy 和 CPython

```powershell
py -V:VersionFox/graalpy3.13 -c "import sys; print(sys.implementation.name, sys.version.split()[0])"
py -V:VersionFox/3.13 -c "import sys; print(sys.implementation.name, sys.version.split()[0])"
```

第一行输出 `graalpy`，第二行输出 `cpython`。这里假设两个运行时都已安装。

### 运行窗口程序

```powershell
pyw -V:VersionFox/3.12.10 app.pyw
```

`pyw` 运行 `WindowedExecutablePath`，也就是 `pythonw.exe`，不会弹出控制台窗口。GraalPy
没有 `pythonw.exe`，也不写 `WindowedExecutablePath`，所以 `pyw` 会运行它的 `python.exe`，
控制台窗口会保留。

### 确认实际运行的解释器

```powershell
py -V:VersionFox/3.12 -c "import sys; print(sys.executable)"
```

这会打印实际运行的解释器路径。同一版本有多个安装时，这个命令很有用。

### 编辑器和其他工具

PEP 514 是 PEP 里点名的格式，PyCharm 和 Visual Studio 等编辑器用它列出解释器。vfox
写入的是同一种格式，所以读取 PEP 514 的工具能找到 vfox 安装的版本。

## 注册了什么

每个已安装版本在 vfox 自己的 `VersionFox` company key 下有一个键：

```text
HKCU\Software\Python\VersionFox\3.12.10
    DisplayName = "Python 3.12.10 (vfox)"
    SysVersion = "3.12"
    SysArchitecture = "64bit"
    VfoxManaged = "1"
    InstallPath
        (Default) = "C:\Users\you\.vfox\cache\python\v-3.12.10\python-3.12.10"
        ExecutablePath = "C:\Users\you\.vfox\cache\python\v-3.12.10\python-3.12.10\python.exe"
        WindowedExecutablePath = "C:\Users\you\.vfox\cache\python\v-3.12.10\python-3.12.10\pythonw.exe"
```

这些值遵循 PEP 514。`InstallPath` 是安装目录，`ExecutablePath` 指向其中的 `python.exe`。
对于 CPython，vfox 的每条安装路径（EXE、MSI 和 uv-build）都把 `python.exe` 放在版本目录下的
`python-<版本>` 目录里，如示例所示。GraalPy 的 `python.exe` 在 `bin\` 下。`VfoxManaged = "1"`
标记 vfox 写入的项，`vfox uninstall` 只删除这些项。

tag 使用完整版本号，非默认架构加 `-32` 或 `-arm64`，所以多个补丁版本可以并存：

| 构建 | tag |
| --- | --- |
| x86_64 | `3.12.10` |
| 32 位 | `3.12.10-32` |
| ARM64 | `3.12.10-arm64` |
| 自由线程 | `3.13.1t` |

GraalPy 也按同样方式注册。tag 是版本名，比如 `graalpy3.13-community-25.5.5`。它的
`SysVersion` 是 Python 语言版本（`3.13`），不是 GraalPy 的 release。GraalPy 没有
`pythonw.exe`，所以不写 `WindowedExecutablePath`。见 [GraalPy](graalpy.md)。

## 为什么不写 `PythonCore`

`PythonCore` 是 python.org 的 company 名。用户级的 `PythonCore\3.12` 项会优先于机器上
为所有用户安装的官方 3.12（PEP 514 规定用户级项优先），并让它在 `py` 里消失。而且
PythonCore 每个 minor 版本只有一个位置。所以 vfox 写自己的 company key，从不改动
`PythonCore`。

## 删除与关闭

`vfox uninstall python@3.12.10` 只在注册项带有 `VfoxManaged = "1"` 并且仍指向该版本目录时，
才删除这个版本的注册项。

`VFOX_PYTHON_REGISTER_PY_LAUNCHER=0` 会让之后的安装不再注册。已经存在的注册项会保留，
直到它对应的版本被卸载。要全部删除，可以删掉 `HKCU\Software\Python\VersionFox`。

反过来，`vfox link --detect python` 会纳入 `py -0p` 报告的 Python，但会跳过 vfox 自己的
安装。见 [link.md](link.md)。
