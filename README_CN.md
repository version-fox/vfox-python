# vfox-python

[中文](README_CN.md) | [English](README.md)

[vfox](https://vfox.dev/) 的 Python 插件。

它可以从 python.org 安装 CPython，在 Linux 和 macOS 上从源码编译，也可以下载
uv-build 的预编译包。它还能纳入本机已有的 Python——系统包管理器、uv、pyenv、
Conda 等等——并读取项目里的 `.python-version`，让为 pyenv 和 uv 写的项目按文件
里写的版本打开。

## 安装

先安装 [vfox](https://github.com/version-fox/vfox)，然后安装插件和 Python，并选中它：

```bash
vfox add python
vfox install python@3.12.2
vfox use --global python@3.12.2
python -V
```

`vfox search python` 会列出可用的版本。要装最新的版本，用 `latest`：

```bash
vfox install python@latest
```

`python -V` 会显示当前选中的解释器。要让 `python` 出现在 `PATH` 里，需要先把
vfox 挂载到 Shell，见 vfox 的[快速入门](https://vfox.dev/zh-hans/guides/quick-start.html)。

## 版本

版本就是 CPython 的版本号，比如 `3.12.2`、`3.13.1` 或 `3.14.0a4`。自由线程
（free-threaded）构建在最后加 `t`，比如 `3.14.0a4t`。只写大版本号时，选这个
系列里已安装的最新版本：

```bash
vfox install python@3.12       # 3.12.x 里最新的
vfox install python@3.12.2     # 正好 3.12.2
vfox install python@3.14.0a4t  # 自由线程的 3.14.0a4
```

可用的版本取决于平台：

| 平台 | 默认来源 | 版本范围 |
| --- | --- | --- |
| Linux | 用 pyenv 从源码编译 | pyenv 收录的全部版本 |
| macOS | 用 pyenv 从源码编译 | pyenv 收录的全部版本 |
| Windows | python.org 安装包 | 当前架构有 EXE 或 MSI 的稳定版本 |

Windows 上，python.org 没有为仅提供源码的安全版本发布安装包，稳定的安装包名也
覆盖不了预发布版和自由线程构建，所以这些版本不在列表里。设置
`VFOX_PYTHON_USE_UV_BUILD=1` 后，Linux、macOS 和 Windows 都改为下载 uv-build
的预编译包，详见 [docs/zh-CN/uv.md](docs/zh-CN/uv.md)。

`py.exe` 不读取 `PATH`。安装前设置 `VFOX_PYTHON_REGISTER_PY_LAUNCHER=1`，
版本会注册到 vfox 自己的 PEP 514 key 下，详见
[Windows Python 启动器](docs/zh-CN/windows-launcher.md)。

## 本机已有的 Python

如果本机已经有 Python——系统包管理器、uv、pyenv、asdf、mise、Conda、Homebrew
或 python.org 安装包装的——`vfox link --detect python` 会直接采用它，而不用再
下载一份（需要 vfox 1.1.0 或更高版本）：

```bash
vfox link --detect python
vfox use --global python@3.12.8-system
```

插件会列出找到的安装，选中哪个就链接哪个；加 `-y` 则全部链接，不再逐个确认。
链接进来的版本只是一个符号链接：Python 还在原来的位置，`vfox uninstall` 也只
删除这个链接。它会扫哪些目录、起什么版本名、跳过哪些东西，见
[docs/zh-CN/link.md](docs/zh-CN/link.md)。

vfox 切换到某个项目时，`.python-version` 会选中一个已安装的版本，所以为 pyenv
或 uv 写的项目不用改：

```bash
echo 3.12 > .python-version
```

## uv

uv-build 是可选的预编译来源：

```bash
export VFOX_PYTHON_USE_UV_BUILD=1
vfox install python@3.12.2
```

Linux 上会自动识别 libc；要覆盖识别结果，设置
`VFOX_PYTHON_UV_LIBC=gnu` 或 `VFOX_PYTHON_UV_LIBC=musl`。`uv python install`
装的 Python 和别的安装一样，会被 `vfox link --detect python` 找到。预编译包
的细节，以及怎样让 uv 使用 vfox 选中的解释器而不是再下载一份，见
[docs/zh-CN/uv.md](docs/zh-CN/uv.md)。

## 镜像

把 `VFOX_PYTHON_MIRROR` 指向一个和 `https://www.python.org/ftp/python/` 目录
结构相同的镜像：

```bash
export VFOX_PYTHON_MIRROR=https://mirrors.huaweicloud.com/python/
```

uv-build 的下载可以走 `VFOX_PYTHON_UV_BUILD_MIRROR`。两个变量和镜像需要包含
什么，见 [docs/zh-CN/mirror.md](docs/zh-CN/mirror.md)。

## 文档

**使用插件**

- [版本](docs/zh-CN/versions.md)：版本写法、自由线程构建、`latest`，以及各平台有哪些版本
- [uv 与 uv-build](docs/zh-CN/uv.md)：预编译包、uv 管理的 Python，以及让 uv 配合 vfox 选中的解释器
- [本机已有的 Python](docs/zh-CN/link.md)：`vfox link --detect python`、它会纳入的系统与 uv 安装，以及安全用法
- [平台](docs/zh-CN/platforms.md)：哪些版本从源码编译、哪些直接下载，以及 Linux 需要的构建依赖
- [Windows Python 启动器](docs/zh-CN/windows-launcher.md)：可选的 `py.exe` PEP 514 注册
- [镜像](docs/zh-CN/mirror.md)：python.org 和 uv-build 的镜像
- [变更记录](docs/zh-CN/changes.md)：每个版本改了什么

**参与开发**

- [从源码安装](docs/zh-CN/install-from-source.md)：在下一个版本发布前试用 `main`
- [开发](docs/zh-CN/development.md)：目录结构、钩子、测试、检查和发布

## 致谢

- [pyenv](https://github.com/pyenv/pyenv)，Linux 和 macOS 的默认安装沿用它的版本列表和 `python-build`
- [uv](https://github.com/astral-sh/uv)，提供预编译 Python 包和 `.python-version` 约定
- [python.org](https://www.python.org/)，提供各版本和 Windows 安装包
