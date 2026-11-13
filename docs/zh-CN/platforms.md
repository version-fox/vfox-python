# 平台

[中文](platforms.md) | [English](../platforms.md)

## 安装的是什么

| 平台 | 默认 | `VFOX_PYTHON_USE_UV_BUILD=1` |
| --- | --- | --- |
| Linux x86_64 | CPython 用 pyenv 从源码编译；GraalPy 用 Oracle 压缩包 | uv-build 预编译包 |
| Linux arm64 | CPython 用 pyenv 从源码编译；GraalPy 用 Oracle 压缩包 | uv-build 预编译包 |
| Linux armv7 | CPython 用 pyenv 从源码编译；没有 GraalPy 构建 | 有包时用 uv-build 预编译包 |
| Linux musl / Alpine | 用 pyenv 从源码编译 | uv-build 的 musl 预编译包 |
| macOS Intel 和 Apple silicon | CPython 用 pyenv 从源码编译；GraalPy 用 Oracle 压缩包 | uv-build 预编译包 |
| Windows x86_64、arm64、386 | CPython 用 python.org 的 EXE 或 MSI；GraalPy 用 amd64 压缩包 | uv-build 预编译包 |

CPython 的源码构建取 pyenv 的 tag 和版本列表，把 pyenv 克隆到那个 tag，再运行
它的 `python-build`。它需要 C 工具链和 Python 链接的头文件。Windows 则下载 python.org
的安装包，用自带的 WiX 工具解开 MSI，再运行 `ensurepip`，不需要编译器。GraalPy
在所有支持的平台上都从 Oracle 的发布页下载并解压，不需要编译器；Linux 和
macOS 有 amd64 和 arm64 资源，Windows 只有 amd64。

## 版本范围

- **CPython 源码构建：** pyenv 列表里的每个 CPython 版本，包括 2.x、预发布版和
  名字以 `t` 结尾的自由线程版本。
- **GraalPy：** 当前平台和架构有资源的版本，从 GraalPy 22.3 开始。Linux 和
  macOS 使用 pyenv 提供的版本列表；Windows 列出有 `windows-amd64` 资源的版本。
  Windows arm64 和 386 不支持。
- **Windows CPython 安装包：** 当前架构有 EXE 或 MSI 的稳定版本。只有源码的
  安全版本不在列表里，2.5 以前的版本也不列出；预发布安装包的文件名匹配不上稳定
  的精确文件名，Windows 上需要预发布版时请用 uv-build。
- **uv-build：** 索引里当前平台、架构和 libc 有的 CPython 包，包括
  `freethreaded` 构建。GraalPy 不在此模式中。

自由线程版本在每种来源上都用同样的 `t` 后缀选中：

```bash
vfox install python@3.13.1t
VFOX_PYTHON_USE_UV_BUILD=1 vfox install python@3.13t
```

部分版本号在每种模式下都会解析：`python@3.13t` 选出该模式列出的、最新的 3.13 自由线程版本；
只写 `python@3.13` 则不会选中自由线程构建。

Windows 的自由线程版本通过 uv-build 提供；稳定安装包列表里没有 `t` 构建。

## Linux 构建依赖

只有 **源码构建** 需要本节列出的包，而源码构建是 Linux 上 CPython 的默认方式。另外两条
路径都不需要这些包：

| 安装的内容 | 需要这些包吗？ |
| --- | --- |
| CPython，源码构建（默认） | 需要 |
| CPython，设置 `VFOX_PYTHON_USE_UV_BUILD=1` | 不需要 |
| GraalPy | 不需要 |

uv-build 下载的是预编译的 CPython 包，GraalPy 是 Oracle 的压缩包，两者都不运行编译器。
Linux 容器套件会检查 uv-build 这条路径：它启动一个没有编译器、也没有 `-dev` 包的
Ubuntu 24.04 镜像，安装 uv-build 的 CPython，然后导入 `ssl`、`sqlite3`、`bz2`、`lzma`、
`ctypes`、`readline`、`curses`、`zlib` 和 `hashlib`。

在 Ubuntu 上做源码构建，需要安装这些包：

```bash
sudo apt update
sudo apt install --assume-yes make build-essential libssl-dev zlib1g-dev \
  libbz2-dev libreadline-dev libsqlite3-dev wget curl llvm \
  libncursesw5-dev xz-utils tk-dev libxml2-dev libxmlsec1-dev \
  libffi-dev liblzma-dev
```

最容易漏掉的是 `zlib1g-dev`。没有 zlib 头文件，CPython 就不会编译 `zlib` 模块，`make install`
随后会在 ensurepip 步骤失败：pip 是从 wheel 安装的，而 wheel 是 zip 压缩包，读取它需要 zlib
（报错为 `No module named 'zlib'`）。

想在 Ubuntu 上省掉这一步，就用 uv-build。它不需要 `sudo`，也不需要 `apt`：

```bash
export VFOX_PYTHON_USE_UV_BUILD=1
vfox install python@3.12
```

`python@3.12` 会安装 uv-build 索引里最新的 3.12 版本，`vfox use -g python@3.12` 选中它。

Fedora 和 RHEL 的源码构建：

```bash
sudo dnf install --assumeyes make gcc zlib-devel bzip2 bzip2-devel \
  readline-devel sqlite sqlite-devel openssl-devel tk-devel \
  libffi-devel xz-devel
```

Alpine 的源码构建：

```bash
sudo apk add build-base zlib-dev bzip2-dev readline-dev sqlite-dev \
  openssl-dev tk-dev libffi-dev xz-dev
```

老版本可能需要旧版 OpenSSL，或者在新编译器上编译不过。`python-build` 的输出
会指出缺少的头文件；装上对应的包，或者在有预编译包时改用 uv-build。

## macOS

先装一次命令行工具：

```bash
xcode-select --install
```

Homebrew 的 `openssl`、`readline`、`sqlite` 和 `xz` 能帮老版本找到头文件和库。
`python-build` 会为 Homebrew 的 prefix 设置常用的 `CPPFLAGS` 和 `LDFLAGS`。
如果构建找不到 OpenSSL，可以自己设置：

```bash
export CPPFLAGS="$(brew --prefix openssl@3)/include"
export LDFLAGS="$(brew --prefix openssl@3)/lib"
export PKG_CONFIG_PATH="$(brew --prefix openssl@3)/lib/pkgconfig"
```

Apple silicon 上，CPython 3.8.7 会在 `configure` 阶段报 `Unexpected output of 'arch' on OSX`
而失败：这个版本的 configure 脚本只接受 `arch` 输出 `i386` 和 `ppc`。3.8.20 已在该检查里加入
`arm64`，请改用 3.8.20 或之后的 3.8 补丁版本。3.9.0 的 configure 同样没有 `arm64` 分支；之后的
3.9 补丁版本没有核对。

Apple silicon 上构建的是原生 arm64；在 Rosetta 的 x86_64 Shell 里构建的是
x86_64 Python，装进同一个 vfox 目录。

## Windows

CPython 来自 python.org。当 python.org 为该架构提供 **EXE** 安装包时，插件使用它；只有
没有 EXE 时才使用 **MSI**。检查顺序如下：

1. `python-<版本>-amd64.exe`、`python-<版本>-arm64.exe`，32 位则是 `python-<版本>.exe`。
   插件会对这个文件发一个 HEAD 请求，返回 200 就选中 EXE。
2. `python-<版本>.amd64.msi`、`python-<版本>.arm64.msi`，32 位则是 `python-<版本>.msi`，
   仅在第 1 步没找到时使用。

两者都不存在时，安装失败，提示 `No available installer found for current version`。
下面是 python.org 上的两个例子：

| 版本 | python.org 上发布的文件 | 使用的安装包 |
| --- | --- | --- |
| 3.12.10 | `python-3.12.10-amd64.exe`，没有 MSI | EXE |
| 2.7.18 | `python-2.7.18.amd64.msi`，没有 EXE | MSI |

- **EXE：** 这个文件是一个捆绑包。插件用自带的 WiX `dark.exe` 解出其中的 MSI，删除
  `launcher.msi`、`path.msi`、`appendpath.msi` 和 `pip.msi`，再用
  `msiexec /quiet /a <msi> TargetDir=<目录>` 把其余的 MSI 安装进版本目录，最后运行
  `ensurepip`。因为启动器、PATH 和 pip 的 MSI 都被跳过，vfox 的安装不会添加 `py.exe`，
  不改动 `PATH`，pip 由 `ensurepip` 提供。
- **MSI：** 插件用同样的方式安装 MSI，即 `msiexec /quiet /a <msi> TargetDir=<目录>`，
  然后运行 `ensurepip`，并创建和 EXE 路径相同的 `python3` 别名。python.org 只发布了 3.4.4
  的 MSI，Windows E2E 套件就用这种方式安装它。
- **老版本 MSI 需要它们的 C 运行库：** `msiexec /a` 安装不会复制 Visual C++ 合并模块原本要放进
  `System32` 的运行库。CPython 3.4 链接的是 Visual C++ 2010 的 `msvcr100.dll`。机器上没有这个
  DLL 时，`python.exe` 无法启动：`ensurepip` 步骤以退出码 `-1073741515`（0xC0000135，找不到 DLL）
  退出，安装失败。其他老版本需要各自 Visual Studio 版本对应的运行库。先在管理员 PowerShell 里
  安装运行库，再安装该版本：

  ```powershell
  Invoke-WebRequest -Uri https://download.microsoft.com/download/1/6/5/165255E7-1014-4D0A-B094-B6A430A6BFFC/vcredist_x64.exe -OutFile vcredist_x64.exe
  .\vcredist_x64.exe /quiet /norestart
  ```

两种安装路径（以及 uv-build）最终都把 `python.exe` 放在版本目录下的 `python-<版本>` 目录里，
比如 `%USERPROFILE%\.vfox\cache\python\v-3.12.10\python-3.12.10\python.exe`。

- 安装包通常把 `python3.exe`、`python3.12.exe` 和对应的 `pythonw` 放在共享目录。
  插件会在 `python.exe` 旁边补上这些别名，让选中的版本也有它们。
- 支持带空格、`%`、`!` 和单引号的路径。参数通过 base64 编码的 PowerShell 传递；
  路径里有 `%` 时，MSI 还会经过一个临时 junction，因为 Windows Installer 在
  复制文件时会展开 `%`。见 [development.md](development.md) 和 Windows CI 任务。
- 安装默认会注册到启动器，写入 `HKCU\Software\Python\VersionFox`，所以
  `py -V:VersionFox/<版本>` 可以选中它们。设置 `VFOX_PYTHON_REGISTER_PY_LAUNCHER=0`
  可以让之后的安装不再注册。插件不写 `PythonCore`；用法示例见
  [windows-launcher.md](windows-launcher.md)。
- GraalPy 从 Oracle 发布页下载 `graalpy*-windows-amd64.zip`，校验 SHA-256 后
  解压。`python.exe` 在 `bin` 下，pip 由 `ensurepip` 安装。PEP 514 的
  `SysVersion` 是 Python 语言版本。见 [GraalPy](graalpy.md)。

## uv-build

接口是：

```text
https://vault.vfox.dev/python/uv-build?os=<linux|windows|darwin>&arch=<x86_64|aarch64|...>&libc=<gnu|musl>
```

Linux 上会自动识别 libc，除非设置了 `VFOX_PYTHON_UV_LIBC`。Windows 和 macOS
不发送 `libc`。没有对应包的平台会在 vfox 下载任何东西之前就失败。包的选择和
校验见 [uv.md](uv.md)。

## 时间与磁盘

源码构建通常要 5 到 15 分钟，占几百 MB 临时空间。Windows 安装包和 uv-build
只要几秒到一分钟。GraalPy 安装就是下载加解压：Linux 上约 150 MB，Windows 上
约 600 MB。

`tests/e2e` 里的 E2E 套件覆盖这些路径。Linux 上，runner 会安装源码构建、镜像构建、
按小版本号安装的 uv-build、GraalPy 和 `vfox link`；没有构建包的 Ubuntu 容器会安装 uv-build 和
GraalPy。Windows 上，runner 会安装 EXE 安装包、只有 MSI 的 3.4.4、镜像构建、uv-build 和
GraalPy；Server Core 容器会安装 GraalPy。

## Python 2

源码列表或 Windows 发布页里还有的老 2.x 版本会出现在列表中。它们已经停止维护，
很多依赖也无法在当前系统上构建；只在无法迁移的老项目里使用。
