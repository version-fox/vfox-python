# 版本

[中文](versions.md) | [English](../versions.md)

## 写法

版本就是 CPython 的版本号，比如 `3.12.2`、`3.13.1` 或 `3.14.0a4`。自由线程
（free-threaded）构建在最后加 `t`：

```bash
vfox install python@3.13.1t
vfox install python@3.14.0a4t
```

`vfox install` 只写大版本号时，装这个系列里最新的版本；`vfox use` 只写大版本
号时，选这个系列里已安装的最新版本，和 vfox 对其他 SDK 的做法一样：

```bash
vfox install python@3.12       # 可用的 3.12.x 里最新的
vfox install python@3.12.2     # 正好这个版本
vfox use python@3.12           # 已安装的 3.12.x 里最新的
```

`latest` 由 `PreInstall` 解析成 `Available` 返回的第一个版本。列表按从新到旧
排列，所以它是这个平台列出的最新版本；有预发布版时，也可能是一个预发布版。

## 版本列表从哪里来

| 平台 | 来源 | 列出什么 |
| --- | --- | --- |
| Linux、macOS | 插件里的 pyenv 索引 | pyenv 收录的全部 CPython 版本，包括预发布版和 2.x |
| Windows | python.org 的 Windows 下载页 | 当前架构有安装包的稳定版本 |
| 任意平台，`VFOX_PYTHON_USE_UV_BUILD=1` | uv-build 索引 | 当前平台、架构和 libc 的 CPython 包 |

Windows 上，插件只读一次下载页，然后按当前架构只留下安装包名完全匹配的条目：
`python-<版本>-amd64.exe`，386 上是 `python-<版本>.exe`，arm64 上是
`python-<版本>-arm64.exe`，以及对应的 MSI 名。只有源码的安全版本、嵌入式 zip、
Python Manager 和重复的架构条目都不会留下。2.5 以前的版本不列出。预发布安装包的
文件名带后缀（比如 `python-3.13.0a1-amd64.exe`），匹配不上稳定的精确文件名，
所以不列出；Windows 上需要预发布版时请用 uv-build。

Linux 和 macOS 不从 python.org 取版本列表。插件向
`https://vault.vfox.dev/python/pyenv` 询问 pyenv 的 tag 和版本列表，再用这个
tag 里的 `python-build` 编译。这个列表和 `pyenv install --list` 显示的一样。
在较新的发行版上安装很老的版本时，源码可能已经编译不过；编译输出会指出缺少的
头文件或编译器。

`Available` 的结果默认由 vfox 缓存 12 小时；要提前刷新，见 vfox 的缓存设置。

## 安装后的名字

用这个插件安装的版本保留裸版本号：`3.12.2`、`3.14.0a4t`。`vfox list
python`、`vfox use` 和 `vfox uninstall` 显示、接收的都是这个名字。

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
system
```

- `3.12` 选已安装的 3.12.x 里最新的。
- `cpython-3.12.8` 选 `3.12.8`；只装了链接版本时，选 `3.12.8-system`。
- `+freethreaded` 形式选带 `t` 的版本。
- `system` 选最新的 `-system` 链接版本。
- 不处理 PyPy 等其他实现，也不处理路径或 `3.12.3/envs/...` 这样的条目。
- 文件里的版本没安装时不选任何版本，vfox 保持当前版本，不会在背后替你安装。

文件按 `specified` 策略读取。如果 vfox 配置里的
`legacyVersionFile.strategy` 是 `latest_installed`，条目缺失或读不懂时就退回到
已安装的最新 Python。

## Windows 安装包

Windows 上不编译，直接用 python.org 的安装包：

- `.exe` 安装包用插件自带的 WiX `dark.exe` 解开，再把里面的 MSI 安装进版本
  目录，并用 `ensurepip` 装好 pip。
- 老版本的 `.msi` 安装包直接用 `msiexec` 安装。
- python.org 安装包通常把 `python3.exe`、`python3.12.exe` 之类的别名放在目标
  目录外面，插件会在 `python.exe` 旁边补上这些别名。
- 带空格、百分号、`!` 和引号的路径通过 base64 参数的 PowerShell 命令处理，
  见 [development.md](development.md)。

## uv-build 的名字

uv-build 模式下，索引提供 `display_version` 时用它；否则 `freethreaded`
构建会加 `t`，也就是 `3.13.1` 配 `variant = "freethreaded"` 时叫 `3.13.1t`。
列表里只保留有 HTTPS 包地址的 CPython 构建。详见 [uv.md](uv.md)。
