# uv 与 uv-build

[中文](uv.md) | [English](../uv.md)

这里有两个互不相干的东西都叫 uv：

1. **uv-build** 是这个插件可以安装的预编译 CPython 包，用来代替源码编译或
   Windows 安装包。
2. **uv 这个工具** 会在 `uv python dir` 下安装、管理自己的 Python。
   `vfox link --detect python` 会纳入这些 Python，两个工具可以共用一个解释器。

## uv-build

安装前设置 `VFOX_PYTHON_USE_UV_BUILD=1`：

```bash
export VFOX_PYTHON_USE_UV_BUILD=1
vfox install python@3.12.2
```

插件向 `https://vault.vfox.dev/python/uv-build` 询问当前平台、架构和 libc 的
构建，然后把包地址和 SHA-256 交给 vfox。vfox 下载、校验、解压，再调用
`PostInstall`：

- Unix 上，如果 `bin` 里脚本的 shebang 指向临时构建目录，会被修正。
- Windows 上，如果包里带了 `ensurepip` 却没有 pip 命令，会安装 pip，并生成
  `pip.cmd`、`pip3.cmd` 两个 shim。

列表里只有 CPython 的包。GraalPy 和其他实现不在 uv-build 里；在这个模式下
执行 `vfox install python@graalpy-24.2.0` 会失败，并提示取消
`VFOX_PYTHON_USE_UV_BUILD`。GraalPy 的安装路径见 [GraalPy](graalpy.md)。插件按
这个顺序优先：

1. `install_only_stripped`
2. `install_only`
3. `pgo+lto-full`
4. 其他非调试包
5. 其他扩展名受支持的包

`freethreaded` 构建会变成带 `t` 的版本；索引给了 `display_version` 时以它为准。
包地址必须是 HTTPS；没有可用 SHA-256 的构建会直接安装失败，而不是不校验就下载。

### 平台与 libc

请求里带着 `os`、`arch`，Linux 上还有 `libc`：

| 变量 | 作用 |
| --- | --- |
| `VFOX_PYTHON_USE_UV_BUILD` | `1`、`true`、`yes` 或 `on` 时改用 uv-build |
| `VFOX_PYTHON_UV_LIBC` | `gnu` 或 `musl`，覆盖 Linux 的识别结果 |
| `VFOX_PYTHON_UV_BUILD_MIRROR` | 让预编译包走镜像下载 |

Linux 上先运行 `ldd --version`，再找 musl 的加载器，最后问
`getconf GNU_LIBC_VERSION`；都失败时打印警告并按 `gnu` 处理。识别不对时设置
上面的变量。

镜像必须是 HTTPS 地址，并按 `<镜像>/<release>/<文件名>` 镜像 GitHub 的 release
下载。默认的 GitHub 地址会变成 `https://mirror.example/<release>/<文件名>`：

```bash
export VFOX_PYTHON_UV_BUILD_MIRROR=https://registry.npmmirror.com/-/binary/python-build-standalone/
```

它和 `VFOX_PYTHON_MIRROR` 不是一回事；后者镜像 python.org 的 FTP 目录，见
[mirror.md](mirror.md)。

## uv 管理的 Python

`uv python install` 把 CPython 下载到 uv 自己的目录：

```bash
uv python install 3.12
uv python dir
```

默认目录在 Windows 上是 `%APPDATA%\uv\python`，其他系统上是
`$XDG_DATA_HOME/uv/python` 或 `~/.local/share/uv/python`。
`UV_PYTHON_INSTALL_DIR` 可以改。`vfox link --detect python` 会问
`uv python dir`（也认这个变量），把每个安装列成 `-uv` 名字：

```bash
vfox link --detect python
# 3.13.1-uv  ~/.local/share/uv/python/cpython-3.13.1-linux-x86_64-gnu
```

安装仍然归 uv 所有。vfox 只是链接它，像别的版本一样选中它，卸载时只删链接。
详见 [link.md](link.md)。

## 让 uv 使用 vfox 选中的解释器

uv 默认优先使用自己管理的 Python。所以 vfox 已经选中同一个 CPython 版本时，
`uv venv` 还可能再下载一份。让 uv 优先用 `PATH` 上的解释器：

```bash
export UV_PYTHON_PREFERENCE=system
uv venv --python 3.12
```

`system` 表示“优先用非 uv 的解释器，没有匹配的再退回 uv 管理的版本”。
`only-system` 则绝不下载，没有匹配项就失败。`managed` 是 uv 的默认值，优先
uv 自己的副本；`only-managed` 完全不用系统解释器。

要固定某一个解释器，不管优先级：

```bash
uv venv --python "$(command -v python3)"
# 或者
UV_PYTHON=/path/to/python uv venv
```

`UV_PYTHON` 也可以写版本请求；由 `UV_PYTHON_PREFERENCE` 决定用哪个安装来满足。

`.python-version` 是双向的：uv 读写它，vfox 切换进项目目录时也读它。所以用 uv
建的项目，在 vfox 里会打开同一个版本——前提是这个版本已安装，而且名字能匹配
文件里的请求。文件里写路径或 PyPy 时，vfox 不选任何版本。

## 最佳实践

- 每个解释器只认一个主人。要么 vfox 安装，要么 uv 安装后由 vfox 链接；不要
  为同一个版本留一份 vfox 副本和一份 uv 副本。
- 不要用 `uv pip install --system` 往 uv 的基础 Python 里装项目依赖，也不要
  往链接进来的系统 Python 里装。创建虚拟环境：

  ```bash
  uv venv
  uv pip install requests
  ```

- Debian 和 Ubuntu 的系统 Python 是 externally managed（PEP 668）。
  `uv venv` 是最快的可写环境方案；`python3 -m venv` 要先装 `python3-venv`。
- 要让 uv 使用 vfox 选中的 Python，在 Shell 或项目环境里设置
  `UV_PYTHON_PREFERENCE=system`。机器上还依赖 uv 下载 vfox 没有的版本时，不要
  设成 `only-system`。
- 用 `UV_PYTHON_INSTALL_MIRROR` 镜像 uv 自己的 Python 下载，用
  `VFOX_PYTHON_UV_BUILD_MIRROR` 镜像本插件的 uv-build 包。两者是不同的下载
  路径。
- `.python-version` 提交 `3.12`、`cpython-3.12.8` 这样的版本，不要写某台机器
  的路径，两个工具才能都解析。
