# 版本

[中文](versions.md) | [English](../versions.md)

## 写法

版本就是 CPython 的版本号，比如 `3.12.2`、`3.13.1` 或 `3.14.0a4`，或者
GraalPy 的版本名，比如 `graalpy-24.2.0`、`graalpy-community-24.2.0` 或
`graalpy3.13-25.5.5`。自由线程（free-threaded）的 CPython 构建在最后加 `t`：

```bash
vfox install python@3.13.1t
vfox install python@3.14.0a4t
vfox install python@graalpy-24.2.0
```

GraalPy 的命名规则见 [GraalPy](graalpy.md)。版本名里的 release 是
GraalPy/GraalVM 的版本，和 Python 语言版本是两回事。

`vfox install` 只写大版本号时，装这个系列里最新的版本；`vfox use` 只写大版本
号时，选这个系列里已安装的最新版本，和 vfox 对其他 SDK 的做法一样：

```bash
vfox install python@3.12       # 可用的 3.12.x 里最新的
vfox install python@3.12.2     # 正好这个版本
vfox use python@3.12           # 已安装的 3.12.x 里最新的
```

部分版本号两边都会解析。`PreInstall` 选出版本列表里最新的稳定版；在 Linux 和 macOS 的默认模式下，它先选出 uv-build 索引里最新的匹配版本，索引里没有时才用版本列表；`PreUse` 选出已安装里
最新的匹配项，同一版本时裸名字优先于带 `-system` 等来源后缀的名字。普通请求从不选自由线程
（`t`）或预发布版，所以 `python@3.13` 不会选到 `python@3.13t`。

`latest` 由 `PreInstall` 解析成 `Available` 返回的、第一个不是自由线程版的版本。列表按从新到旧
排列，所以它是这个平台列出的最新常规 CPython 版本；有预发布版时，也可能是一个
预发布版。自由线程版（如 `3.13.18t`）只有写出名字时才会安装。GraalPy 需要写出完整版本名。在 Linux 和 macOS 的默认模式下，`latest` 不在 uv-build 索引里解析，
它仍是列表里最新的版本：索引列出该版本时安装它的预编译包；pyenv 列出的版本比索引新时，则从源码编译，
并打印一行说明。

## 版本列表从哪里来

| 平台 | 来源 | 列出什么 |
| --- | --- | --- |
| Linux、macOS | 插件里的 pyenv 索引；默认模式下还包括 uv-build 索引 | pyenv 收录的全部版本，包括 CPython、GraalPy、PyPy 和 Conda；默认模式下还包括只有 uv-build 列出的 CPython 版本 |
| Windows | python.org 下载页和 Oracle 的 GraalPy 发布 | 当前架构的稳定 CPython 安装包，以及 GraalPy 的 Windows amd64 版本 |
| 任意平台，`VFOX_PYTHON_USE_UV_BUILD=1` | uv-build 索引 | 当前平台、架构和 libc 的 CPython 包 |

在 Linux 和 macOS 的默认模式下，两个列表都列出的 CPython 版本只列一次。最新的版本排在最前面，
正式版排在它的预发布版和自由线程构建之前。每个安装用哪种来源，由 PreInstall 决定，而不是由列表决定：见 [uv.md](uv.md)。

Windows 上，插件只读一次下载页，然后按当前架构只留下安装包名完全匹配的条目：
`python-<版本>-amd64.exe`，386 上是 `python-<版本>.exe`，arm64 上是
`python-<版本>-arm64.exe`，以及对应的 MSI 名。只有源码的安全版本、嵌入式 zip、
Python Manager 和重复的架构条目都不会留下。2.5 以前的版本不列出。预发布安装包的
文件名带后缀（比如 `python-3.13.0a1-amd64.exe`），匹配不上稳定的精确文件名，
所以不列出；Windows 上需要预发布版时请用 uv-build。

Linux 和 macOS 不从 python.org 取版本列表。插件向
`https://vault.vfox.dev/python/pyenv` 询问 pyenv 的 tag 和版本列表。CPython
用这个 tag 里的 `python-build` 构建；GraalPy 从 Oracle 的发布压缩包下载并解压。
这个列表和 `pyenv install --list` 显示的一样，所以也包含 GraalPy、PyPy、Conda
等非 CPython 发行版。插件只文档化和测试 CPython 与 GraalPy；其他条目取决于
pyenv 自己的定义。在较新的发行版上安装很老的 CPython 版本时，源码可能已经编译
不过；编译输出会指出缺少的头文件或编译器。

`Available` 的结果默认由 vfox 缓存 12 小时；要提前刷新，见 vfox 的缓存设置。

## 安装后的名字

用这个插件安装的版本保留裸版本号：`3.12.2`、`3.14.0a4t` 或
`graalpy-24.2.0`。`vfox list python`、`vfox use` 和 `vfox uninstall` 显示、
接收的都是这个名字。

用 `vfox link --detect python` 纳入的版本会带上来源，免得和 vfox 安装的同版本
重名：

| 来源 | 名字示例 |
| --- | --- |
| 系统包管理器 | `3.12.3-system` |
| `/usr/local` | `3.12.3-local` |
| uv | `3.13.1-uv` |
| pyenv | `3.11.9-pyenv` |
| asdf | `3.12.8-asdf` |
| mise | `3.13.1-mise` |
| Conda | `3.10.14-conda` |
| python.org 安装包 | `3.12.10-pythonorg` |
| Microsoft Store | `3.13.1-store` |
| Homebrew | `3.12.8-brew` |
| Nix | `3.12.8-nix` |
| `/opt` | `3.12.8-opt` |
| Snap | `3.12.8-snap` |
| Scoop | `3.12.8-scoop` |

来源后缀见 [link.md](link.md)。`vfox use python@3.12` 仍会按版本前缀匹配
`3.12.3-system`；如果裸版本和链接版本都装了同一个 3.12，要指定其中一个时就写
后缀。

## `.python-version`

`metadata.lua` 把 `.python-version` 注册为兼容版本文件。vfox 切换进含有这个
文件的目录时，钩子会选一个已安装的版本：

```text
3.12.8
3.12
cpython-3.12.8
cpython-3.12.8+freethreaded-linux-x86_64-gnu
graalpy-24.2.0
graalpy3.13-community-25.5.5
system
```

- `3.12` 选已安装的 3.12.x 里最新的，和 `vfox use` 一样不会选中自由线程（`t`）或预发布版。
  `3.13t` 选中自由线程版本；预发布版要写完整名字，如 `3.14.0a4`。
- `cpython-3.12.8` 选 `3.12.8`；只装了链接版本时，选 `3.12.8-system`。几个安装的版本号相同时，先选裸版本，其余按名字排序取第一个，所以 `3.12.8-local` 排在 `3.12.8-system` 前面；要选哪一个，就写完整名字。
- `+freethreaded` 形式选带 `t` 的版本。
- `system` 选最新的 `-system` 链接版本，但只限常规的 CPython 版本。自由线程和预发布版要写完整名字，
  如 `3.13.1t-system`；GraalPy 也要写完整名字。
- `graalpy-24.2.0`、`graalpy3.13-community-25.5.5` 这样的 GraalPy 版本名会选中
  对应的已安装 GraalPy。
- 不处理 PyPy 等其他实现，也不处理路径或 `3.12.3/envs/...` 这样的条目。
- 文件里的版本没安装时不选任何版本，vfox 保持当前版本，不会在背后替你安装。

文件按 `specified` 策略读取。如果 vfox 配置里的
`legacyVersionFile.strategy` 是 `latest_installed`，条目缺失或读不懂时就退回到
最新的常规 CPython；没有 CPython 时，退回到已安装的最新名字。

## Windows 安装包

Windows 上不编译，直接用 python.org 的安装包。该版本发布了
`python-<版本>-amd64.exe`（ARM64 为 `-arm64.exe`，386 为 `python-<版本>.exe`）时使用
EXE；没有 EXE 时才用 MSI（`python-<版本>.amd64.msi`、`.arm64.msi`，386 为
`python-<版本>.msi`）。例如 3.12.10 在 python.org 上只有 EXE，2.7.18 只有 MSI。
检查顺序见 [平台](platforms.md#windows)。

- `.exe` 安装包用 Windows 自带的 `expand.exe` 解出里面的 MSI。这些 MSI 用
  `msiexec /quiet /a` 安装进 `python-<版本>` 目录；启动器、PATH 和 pip 的 MSI 会被跳过，pip
  用 `ensurepip` 装好。
- 老版本的 `.msi` 安装包用 `msiexec /quiet /a` 安装进 `python-<版本>` 目录，pip 用
  `ensurepip` 装好。
- python.org 安装包通常把 `python3.exe`、`python3.12.exe` 之类的别名放在目标
  目录外面，插件会在 `python.exe` 旁边补上这些别名。
- 带空格、百分号、`!` 和引号的路径通过 base64 参数的 PowerShell 命令处理，
  见 [development.md](development.md)。

GraalPy 走另一条路径：插件从 Oracle 的 GitHub 发布下载官方压缩包，校验
SHA-256 后解压。Linux 和 macOS 上是 `.tar.gz`，Windows 上是
`graalpy*-windows-amd64.zip`。`python.exe` 留在 `bin` 下，pip 由包里自带的
`ensurepip` 安装。Windows 只有 amd64。见 [GraalPy](graalpy.md)。

## uv-build 的名字

uv-build 模式下，索引提供 `display_version` 时用它；否则 `freethreaded`
构建会加 `t`，也就是 `3.13.1` 配 `variant = "freethreaded"` 时叫 `3.13.1t`。
列表里只保留有 HTTPS 包地址的 CPython 构建。设置 `VFOX_PYTHON_USE_UV_BUILD=1` 时，
GraalPy 版本会被拒绝，并提示取消 `VFOX_PYTHON_USE_UV_BUILD` 或把它设为 `0`。详见 [uv.md](uv.md)。

部分版本号（如 `3.12`、`3.13t`）会解析为索引里最新的匹配版本，安装记录的是完整版本名（如 `3.12.16`）。
