# 平台

[中文](platforms.md) | [English](../platforms.md)

## 安装的是什么

| 平台 | 默认 | `VFOX_PYTHON_USE_UV_BUILD=1` |
| --- | --- | --- |
| Linux x86_64 | 用 pyenv 从源码编译 | uv-build 预编译包 |
| Linux arm64 | 用 pyenv 从源码编译 | uv-build 预编译包 |
| Linux armv7 | 用 pyenv 从源码编译 | 有包时用 uv-build 预编译包 |
| Linux musl / Alpine | 用 pyenv 从源码编译 | uv-build 的 musl 预编译包 |
| macOS Intel 和 Apple silicon | 用 pyenv 从源码编译 | uv-build 预编译包 |
| Windows x86_64、arm64、386 | python.org 的 EXE 或 MSI | uv-build 预编译包 |

源码构建取 pyenv 的 tag 和版本列表，把 pyenv 克隆到那个 tag，再运行它的
`python-build`。它需要 C 工具链和 Python 链接的头文件。Windows 则下载官方
安装包，用自带的 WiX 工具解开 MSI，再运行 `ensurepip`，不需要编译器。

## 版本范围

- **源码构建：** pyenv 列表里的每个 CPython 版本，包括 2.x、预发布版，以及
  名字以 `t` 结尾的自由线程版本。
- **Windows 安装包：** 当前架构有 EXE 或 MSI 的稳定版本。只有源码的安全版本不在
  列表里，2.5 以前的版本也不列出；预发布安装包的文件名匹配不上稳定的精确文件名，
  Windows 上需要预发布版时请用 uv-build。
- **uv-build：** 索引里当前平台、架构和 libc 有的 CPython 包，包括
  `freethreaded` 构建。

自由线程版本在每种来源上都用同样的 `t` 后缀选中：

```bash
vfox install python@3.13.1t
VFOX_PYTHON_USE_UV_BUILD=1 vfox install python@3.13.1t
```

Windows 的自由线程版本通过 uv-build 提供；稳定安装包列表里没有 `t` 构建。

## Linux 构建依赖

Debian 和 Ubuntu：

```bash
sudo apt update
sudo apt install --assume-yes make build-essential libssl-dev zlib1g-dev \
  libbz2-dev libreadline-dev libsqlite3-dev wget curl llvm \
  libncursesw5-dev xz-utils tk-dev libxml2-dev libxmlsec1-dev \
  libffi-dev liblzma-dev
```

Fedora 和 RHEL：

```bash
sudo dnf install --assumeyes make gcc zlib-devel bzip2 bzip2-devel \
  readline-devel sqlite sqlite-devel openssl-devel tk-devel \
  libffi-devel xz-devel
```

Alpine：

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

Apple silicon 上构建的是原生 arm64；在 Rosetta 的 x86_64 Shell 里构建的是
x86_64 Python，装进同一个 vfox 目录。

## Windows

- `python-<版本>-amd64.exe` / `-arm64.exe` / `python-<版本>.exe`（386）用
  `bin/WiX/dark.exe` 解开。里面的 MSI 安装进版本目录，再用 `ensurepip` 装 pip。
- 老版本提供 MSI，用 `msiexec /a` 安装，pip 同样用 `ensurepip` 装。
- 安装包通常把 `python3.exe`、`python3.12.exe` 和对应的 `pythonw` 放在共享
  目录。插件会在 `python.exe` 旁边补上这些别名，让选中的版本也有它们。
- 支持带空格、`%`、`!` 和单引号的路径。参数通过 base64 编码的 PowerShell 传递；
  路径里有 `%` 时，MSI 还会经过一个临时 junction，因为 Windows Installer 在
  复制文件时会展开 `%`。见 [development.md](development.md) 和 Windows CI 任务。
- 设置 `VFOX_PYTHON_REGISTER_PY_LAUNCHER=1` 后，安装会按 PEP 514 注册到
  `HKCU\Software\Python\VersionFox`，供 `py.exe` 使用。插件不写 `PythonCore`；
  见 [windows-launcher.md](windows-launcher.md)。

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
只要几秒到一分钟。CI 的 E2E 任务会在 Linux 装一次源码构建，在 Windows 装一次
安装包和一次 uv-build，保证两条路径都能用。

## Python 2

源码列表或 Windows 发布页里还有的老 2.x 版本会出现在列表中。它们已经停止维护，
很多依赖也无法在当前系统上构建；只在无法迁移的老项目里使用。
