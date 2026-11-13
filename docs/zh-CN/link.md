# 使用本机已有的 Python

[中文](link.md) | [English](../link.md)

如果本机已经有 Python，`vfox link --detect python` 会直接采用它，而不用再下载
一份。需要 vfox 1.1.0 或更高版本（`vfox --version` 查看）。插件只找 CPython，
逐个询问解释器的版本和 prefix，然后列出可以链接的安装：

```bash
vfox link --detect python
```

vfox 会列出找到的 Python，选中哪个就链接哪个；`-y` 则全部链接，不再逐个确认：

```bash
vfox link --detect python -y
```

链接进来的版本是一个指向原安装的符号链接。不会复制任何文件，安装还在原来的
位置、仍归原来的主人所有，`vfox uninstall` 也只删除这个链接。`vfox list
python` 会标出链接进来的版本，`vfox info --json python@<版本>` 会显示
`origin: linked` 和 `target`。

## 会扫哪些地方

| 来源 | 插件查找的位置 | 名字后缀 |
| --- | --- | --- |
| `PATH` | `python3` 和 `python`，或 `python.exe` 和 `python3.exe` | 按位置判断 |
| uv | `UV_PYTHON_INSTALL_DIR`、`uv python dir`，或 uv 的默认目录 | `-uv` |
| pyenv | `$PYENV_ROOT/versions`，默认 `~/.pyenv/versions` | `-pyenv` |
| asdf | `$ASDF_DATA_DIR/installs/python`，默认 `~/.asdf/installs/python` | `-asdf` |
| mise | `$MISE_DATA_DIR/installs/python`，默认 `~/.local/share/mise/installs/python` | `-mise` |
| Conda | `CONDA_PREFIX`、`~/miniconda3`、`~/anaconda3`、`~/miniforge3`、`~/mambaforge`、`/opt/conda`、`/opt/miniconda3`、`/opt/miniforge3` | `-conda` |
| Linux 系统 | `/usr`、`/usr/local`、`/opt/python` | `-system`、`-local`、`-opt` |
| Homebrew | `/opt/homebrew`、`/home/linuxbrew/.linuxbrew` | `-brew` |
| Nix 和 Snap | `PATH` 上位于 `/nix/store` 或 `/snap` 的解释器 | `-nix`、`-snap` |
| macOS python.org | `/Library/Frameworks/Python.framework/Versions/*` | `-pythonorg` |
| Windows python.org | `%LOCALAPPDATA%\Programs\Python\Python*`、`%ProgramFiles%\Python*`、`%ProgramFiles(x86)%\Python*`、`C:\Python*` | `-pythonorg` |
| Windows py 启动器 | `py -0p` 报出的每个路径 | 按位置判断 |
| Microsoft Store | `%LOCALAPPDATA%\Microsoft\WindowsApps\PythonSoftwareFoundation.Python.*` | `-store` |
| Scoop | `~/scoop/apps/python/current` | `-scoop` |

uv 目录在 Windows 上是 `%APPDATA%\uv\python`，其他系统上是
`$XDG_DATA_HOME/uv/python` 或 `~/.local/share/uv/python`。

只会报告 CPython。PyPy、GraalPy、Jython 等其他实现不会出现：这个插件安装的是
CPython，把别的实现叫作 CPython 的版本号会误导人。

## 名字

名字是 `<版本>-<来源>`，比如 `3.12.8-system`、`3.13.1-uv` 或
`3.12.10-pythonorg`。自由线程构建保留 `t`：`3.14.0a4t-uv`。版本号来自解释器
本身，不是目录名，所以 uv 目录改了名也能报对版本。

`vfox link` 会拒绝已经被占用的名字，以及已经被某个版本链接到的目录。插件还会
跳过：

- 虚拟环境（`sys.prefix` 和 `sys.base_prefix` 不同）；它的基础 Python 会单独
  被找到，
- vfox 自己目录下的 Python，它已经是 vfox 的版本，
- 存在但无法运行的 Windows Store 别名，
- 会得到同一个名字的第二个安装。

链接后用 `vfox use python@3.12.8-system` 选中它。`vfox use python@3.12` 按
前缀匹配已安装版本，所以也可能选中链接进来的版本。

## 手工链接

`--detect` 没找到的安装可以手工链接。路径是 Python 的 prefix：Unix 上是包含
`bin` 的那一级目录，Windows 上是包含 `python.exe` 的那一级，不是 `bin` 本身。

```bash
vfox link python@3.12.8-system /usr
vfox link python@3.13.1-uv /home/me/.local/share/uv/python/cpython-3.13.1-linux-x86_64-gnu
vfox use python@3.12.8-system
```

已经链接过的名字可以用 `--force` 指向别处：

```bash
vfox link --force python@3.12.8-system /usr/local
```

`--force` 绝不会替换 vfox 安装的版本；要先卸载那个版本。

## 系统 Python

链接进来的系统 Python 就是发行版自带的 Python，因此有这些后果：

- Debian 和 Ubuntu 通常只有 `python3`，没有 `python`。选中
  `python@3.12.3-system` 会把 `/usr/bin` 放进 `PATH`；请运行 `python3`，不是
  `python`。
- 发行版不一定带 pip。`python3 -m pip` 会提示 `No module named pip`；装
  `python3-pip`，或者用虚拟环境。
- PEP 668 会把系统环境标记为 externally managed，pip 会拒绝往里安装。请创建
  虚拟环境：

  ```bash
  python3 -m venv .venv
  . .venv/bin/activate
  ```

  Debian 和 Ubuntu 需要 `sudo apt install python3-venv`；编译带 C 扩展的包还
  需要 `python3-dev`。
- 发行版升级可能把 `/usr/bin/python3` 换成新版本。链接版本跟着符号链接走，所以
  它报出的版本会变；需要新名字时重新运行 `vfox link --detect python`。
- 不要往链接进来的 Python 里 `pip install`，也不要用
  `uv pip install --system` 指向它。两者都会写进发行版的环境。用虚拟环境，或者
  安装一个由 vfox / uv 管理的 Python。

同样的规则适用于 uv 管理的基础解释器和 Conda 的 base 环境：链接它让工具能找到
它，但项目依赖放在虚拟环境里。

## 最佳实践

- 每个解释器只认一个主人。要么由 vfox 安装，要么留在系统 / uv / pyenv 里让
  vfox 链接；不要为同一件事留两份同一个版本。
- 系统 Python 留给那些需要发行版解释器的工具。项目用 vfox、uv 或 pyenv 的
  Python，创建环境时不会碰系统。
- 把 `.python-version`（或 `.tool-versions`）提交进仓库，让选中的版本可复现。
  插件两种约定都读。
- 全局选择留给到处都要 Python 的工具；项目版本在项目目录里选。
- 系统升级后重新运行 `vfox link --detect python`。消失的安装会显示为缺失的
  版本。
