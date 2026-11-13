# GraalPy

[中文](graalpy.md) | [English](../graalpy.md)

[GraalPy](https://www.graalvm.org/python/) 是 Oracle 的 Python 实现，提供 JVM
和 native-image 两种运行方式。插件支持 Oracle 发布的两种发行版：

| 版本名 | 发行版 | 许可 |
| --- | --- | --- |
| `graalpy-<release>` | GraalPy built on Oracle GraalVM | GFTC |
| `graalpy-community-<release>` | GraalPy Community，基于 GraalVM CE | GraalVM Community |

从 GraalPy 25.1 开始，版本名里还会带上 Python 语言版本：

| 版本名 | Python | 发行版 |
| --- | --- | --- |
| `graalpy-24.2.0` | 3.11 | Oracle GraalVM |
| `graalpy-community-24.2.0` | 3.11 | Community |
| `graalpy3.13-25.5.5` | 3.13 | Oracle GraalVM |
| `graalpy3.13-community-25.5.5` | 3.13 | Community |

版本名里的 release 是 GraalPy/GraalVM 的版本，不是 Python 语言版本。
`graalpy-24.2.0` 运行的是 Python 3.11.7，`graalpy3.13-25.5.5` 运行的是
Python 3.13。

## 安装

```bash
vfox install python@graalpy-24.2.0
vfox install python@graalpy-community-24.2.0
vfox install python@graalpy3.13-25.5.5
vfox use --global python@graalpy-24.2.0
python -V
```

`vfox search python` 会在备注里标出 GraalPy：

```text
 - graalpy-24.2.0 (GraalPy)
 - graalpy-community-24.2.0 (GraalPy Community)
```

`latest` 仍然是 CPython 的最新版本，不会选到 GraalPy。项目需要 GraalPy 时请
写出完整版本名。

## 平台支持

| 平台 | 来源 | 版本范围 |
| --- | --- | --- |
| Linux x86_64 / arm64 | Oracle 的发布压缩包 | 所有带 `linux-amd64` 或 `linux-aarch64` 资源的版本 |
| macOS Intel / Apple silicon | Oracle 的发布压缩包 | 所有带 `macos-amd64` 或 `macos-aarch64` 资源的版本 |
| Windows amd64 | Oracle 的发布压缩包 | 所有带 `windows-amd64` 资源的版本 |
| Windows arm64 / 386 | 不支持 | Oracle 没有发布对应构建 |
| 任意平台，`VFOX_PYTHON_USE_UV_BUILD=1` | 不支持 | uv-build 只包含 CPython |

插件从 [oracle/graalpython](https://github.com/oracle/graalpython/releases) 下载
压缩包，校验 SHA-256 后解压到版本目录。Linux 和 macOS 上是 `.tar.gz`，插件会
运行包里自带的 `ensurepip`，pip 不需要联网下载。Windows 上是 `.zip`，
`python.exe` 位于 `bin` 下，插件会把 `bin` 和 `Scripts` 都加入 `PATH`。

Linux 和 macOS 的版本列表仍然来自 pyenv，但 GraalPy 的下载和安装是直接进行的，
不需要 C 工具链。

Oracle 把 Windows 支持标为实验性；部分带原生扩展的包可能没有 GraalPy 构建。

Windows 上，`vfox search python` 通过 GitHub API 读取 GraalPy 发布列表。设置
`GITHUB_TOKEN` 或 `GH_TOKEN` 可以提高 GitHub 的匿名访问限额。安装一个已知
版本不依赖这个列表：插件会直接构造官方资源地址，并校验对应的 `.sha256` 文件。

`VFOX_PYTHON_MIRROR` 和 `VFOX_PYTHON_UV_BUILD_MIRROR` 不适用于 GraalPy 下载。

## PEP 514 与 `py.exe`

Windows 上的 GraalPy 和 CPython 一样，默认注册到
`HKCU\Software\Python\VersionFox`；设置 `VFOX_PYTHON_REGISTER_PY_LAUNCHER=0` 可以关闭。
PEP 514 的 `SysVersion` 使用 Python 语言版本（`3.11` 或 `3.13`），不是 GraalPy 的
release，所以可以用 `py -V:VersionFox/graalpy3.13-25.5.5` 选中。GraalPy 没有
`pythonw.exe`，因此可选的 `WindowedExecutablePath` 不会写入。见
[Windows Python 启动器](windows-launcher.md)。

## 本机已有的 GraalPy

`vfox link --detect python` 会像识别 CPython 一样识别 GraalPy，名字沿用安装
时的命名，并加上来源后缀：

```bash
vfox link --detect python
vfox use --global python@graalpy-24.2.0-pyenv
vfox use --global python@graalpy-community-24.2.0-system
```

手动链接时，路径是 GraalPy 的 prefix，也就是包含 `bin` 的目录（Windows 上是
包含 `bin\python.exe` 的目录）：

```bash
vfox link python@graalpy-24.2.0-system /opt/graalpy-24.2.0
```

`vfox link` 只纳入 CPython 和 GraalPy；PyPy、Jython 等其他实现仍然跳过。见
[本机已有的 Python](link.md)。

## `.python-version`

项目可以在文件里写已安装的 GraalPy 版本名：

```text
graalpy-24.2.0
graalpy3.13-community-25.5.5
```

只写 `3.13` 仍然表示 CPython，而不是运行 Python 3.13 的 GraalPy。文件支持的
其他写法见[版本](versions.md#python-version)。
