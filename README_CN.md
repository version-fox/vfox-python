# vfox-python

[中文](README_CN.md) | [English](README.md)

[vfox](https://vfox.dev/) 的 Python 插件。

它在 Windows 上从 python.org 安装 CPython。在 Linux 和 macOS 上，有对应的 uv-build
预编译包时下载它，否则从源码编译 CPython。GraalPy 在所有支持的平台上都来自 Oracle 发布的
压缩包。它还能纳入本机已有的 Python——系统包管理器、uv、pyenv、Conda 等等——
并读取项目里的 `.python-version`，让为 pyenv 和 uv 写的项目按文件里写的版本
打开。

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

版本就是 CPython 的版本号，比如 `3.12.2`、`3.13.1` 或 `3.14.0a4`，或者
GraalPy 的版本名，比如 `graalpy-24.2.0` 或 `graalpy3.13-community-25.5.5`。
自由线程（free-threaded）的 CPython 构建在最后加 `t`，比如 `3.14.0a4t`。只写
大版本号时，选这个系列里已安装的最新版本：

```bash
vfox install python@3.12       # 3.12.x 里最新的
vfox install python@3.12.2     # 正好 3.12.2
vfox install python@3.14.0a4t  # 自由线程的 3.14.0a4
vfox install python@graalpy-24.2.0
```

可用的版本取决于平台：

| 平台 | 默认来源 | 版本范围 |
| --- | --- | --- |
| Linux | CPython 在 uv-build 索引列出该版本时用 uv-build 预编译包，否则用 pyenv 从源码编译；GraalPy 用 Oracle 压缩包 | pyenv 收录的全部版本，包括 GraalPy、PyPy 和 Conda，以及只有 uv-build 列出的 CPython 版本 |
| macOS | CPython 在 uv-build 索引列出该版本时用 uv-build 预编译包，否则用 pyenv 从源码编译；GraalPy 用 Oracle 压缩包 | pyenv 收录的全部版本，包括 GraalPy、PyPy 和 Conda，以及只有 uv-build 列出的 CPython 版本 |
| Windows | CPython 用 python.org 安装包；GraalPy 用 Oracle 压缩包 | 当前架构的稳定 CPython 安装包，以及 GraalPy 的 amd64 版本 |

Windows 上，python.org 没有为仅提供源码的安全版本发布安装包，稳定的安装包名也
覆盖不了预发布版和自由线程的 CPython 构建，所以这些版本不在列表里。设置
`VFOX_PYTHON_USE_UV_BUILD=0` 后，Linux 和 macOS 上的每个 CPython 都从源码编译；设置
`VFOX_PYTHON_USE_UV_BUILD=1` 后，只使用 uv-build 的预编译包，适用于 Linux、macOS 和
Windows；uv-build 只包含 CPython。详见
[docs/zh-CN/uv.md](docs/zh-CN/uv.md)。

`py.exe` 不读取 `PATH`。Windows 上的安装会自动注册到 vfox 自己的 PEP 514
key 下，因此可以用 `py -V:VersionFox/<版本>` 选中。设置
`VFOX_PYTHON_REGISTER_PY_LAUNCHER=0` 可以关闭注册，详见
[Windows Python 启动器](docs/zh-CN/windows-launcher.md)。

## GraalPy

[GraalPy](https://www.graalvm.org/python/) 是 Oracle 的 Python 实现。插件支持
两种发行版：

| 版本名 | 发行版 | 许可 |
| --- | --- | --- |
| `graalpy-24.2.0`、`graalpy3.13-25.5.5` | GraalPy built on Oracle GraalVM | GFTC |
| `graalpy-community-24.2.0`、`graalpy3.13-community-25.5.5` | GraalPy Community（GraalVM CE） | Community |

```bash
vfox install python@graalpy-24.2.0
vfox install python@graalpy-community-24.2.0
vfox use --global python@graalpy-24.2.0
```

Linux 和 macOS 上，插件下载 Oracle 官方的 tar.gz，再运行自带的 `ensurepip`；
版本列表仍然来自 pyenv。Windows 上下载 Oracle 官方的 amd64 压缩包；Oracle 没有
发布 arm64 和 386 版本，所以这两个架构不支持。`VFOX_PYTHON_MIRROR` 不适用于
GraalPy 下载。GraalPy 不在 uv-build 里，因此
`VFOX_PYTHON_USE_UV_BUILD=1` 只列出 CPython。`vfox link --detect python` 会
纳入已有的 GraalPy。版本命名规则、平台限制和 PEP 514 注册见
[GraalPy](docs/zh-CN/graalpy.md)。

## 本机已有的 Python

如果本机已经有 Python 或 GraalPy——系统包管理器、uv、pyenv、asdf、mise、Conda、
Homebrew、python.org 安装包或 Oracle 的 GraalPy 压缩包装的——
`vfox link --detect python` 会直接采用它，而不用再下载一份（需要 vfox 1.1.0 或
更高版本）：

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
echo graalpy-24.2.0 > .python-version
```

## uv

在 Linux 和 macOS 上，CPython 安装在 uv-build 索引列出该版本时使用它的预编译包，因此不需要编译器或构建依赖。
索引只列出部分版本，通常是每个版本线的最新补丁版，所以较旧的补丁版会用 pyenv 从源码编译，索引没有列出的版本也是如此。GraalPy 来自 Oracle 的压缩包；PyPy 和 Conda 用 pyenv 从源码编译。部分版本号（如 `python@3.12`）会先在 uv-build 索引里选出最新的 3.12 版本，并安装它的预编译包。只有索引没有列出的版本系列，才会改为选中 `vfox search python` 列出的、最新的匹配版本，并从源码编译。要编译索引里还没有的较新补丁版，请写出它的精确版本号：

```bash
vfox install python@3.12        # uv-build 索引里最新的 3.12，安装预编译包
vfox install python@3.12.16     # 精确的 3.12.16
```

设置 `VFOX_PYTHON_USE_UV_BUILD=0` 可以始终从源码编译；设置 `VFOX_PYTHON_USE_UV_BUILD=1` 则只使用 uv-build，索引里没有列出的版本会失败。若设置了 `VFOX_PYTHON_MIRROR`，CPython 的源码构建会继续经由该镜像，除非同时设置了 `VFOX_PYTHON_UV_BUILD_MIRROR`。
Linux 上会自动识别 libc；要覆盖识别结果，设置 `VFOX_PYTHON_UV_LIBC=gnu` 或
`VFOX_PYTHON_UV_LIBC=musl`。
`uv python install` 装的 Python 和别的安装一样，会被
`vfox link --detect python` 找到。预编译包的细节，以及怎样让 uv 使用 vfox
选中的解释器而不是再下载一份，见
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
- [GraalPy](docs/zh-CN/graalpy.md)：Oracle 和 Community 两种发行版、平台支持、`vfox link` 和 PEP 514
- [uv 与 uv-build](docs/zh-CN/uv.md)：预编译包、uv 管理的 Python，以及让 uv 配合 vfox 选中的解释器
- [本机已有的 Python](docs/zh-CN/link.md)：`vfox link --detect python`、它会纳入的系统与 uv 安装，以及安全用法
- [平台](docs/zh-CN/platforms.md)：哪些版本从源码编译、哪些直接下载，以及 Linux 需要的构建依赖
- [Windows Python 启动器](docs/zh-CN/windows-launcher.md)：默认开启的 `py.exe` PEP 514 注册，并附选中 vfox 版本的示例
- [镜像](docs/zh-CN/mirror.md)：python.org 和 uv-build 的镜像
- [变更记录](docs/zh-CN/changes.md)：每个版本改了什么

**参与开发**

- [从源码安装](docs/zh-CN/install-from-source.md)：在下一个版本发布前试用 `main`
- [端到端测试](docs/zh-CN/e2e.md)：Linux/Windows 容器套件和 runner 矩阵
- [开发](docs/zh-CN/development.md)：目录结构、钩子、测试、检查和发布

## 致谢

- [pyenv](https://github.com/pyenv/pyenv)，Linux 和 macOS 的源码构建用它的 `python-build`，`vfox search python` 列出的版本名也来自它
- [uv](https://github.com/astral-sh/uv)，提供预编译 Python 包和 `.python-version` 约定
- [python.org](https://www.python.org/)，提供各版本和 Windows 安装包
- [Oracle GraalPy](https://github.com/oracle/graalpython)，提供 GraalPy 各版本
