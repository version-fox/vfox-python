# 端到端测试

[中文](e2e.md) | [English](../e2e.md)

`tests/e2e` 是一个 Go module。Linux 和 Windows 包用 Go 测试框架驱动 vfox、插件和真实
安装，既在 runner 上跑，也在 Docker 容器里跑。`.github/workflows/e2e.yml` 只安装 Go 并
运行 `go test`；安装命令和所有断言都在 Go 里。

## 目录

| 路径 | 作用 |
| --- | --- |
| `common/` | 构建插件 zip、安装 vfox 1.1.0、运行主机命令、读取 uv-build 索引、断言 |
| `linux/e2e_test.go` | `TestNativeE2E`：源码构建、镜像、uv-build、GraalPy、`vfox link --detect`、`.python-version` |
| `linux/container_test.go` | `TestContainerE2E`：一个没有构建包的 Ubuntu 24.04 容器跑默认安装，每个 GraalPy 版本各一个容器 |
| `linux/Dockerfile` | Ubuntu 24.04，只装 `ca-certificates`、`curl`、`tar`、`xz-utils` 和 `zip`，另装 vfox 1.1.0（`/usr/local/bin/vfox`）；没有编译器，也没有 `-dev` 包 |
| `windows/e2e_test.go` | `TestNativeE2E`：python.org EXE 安装包、镜像、uv-build、带启动器注册的 GraalPy、`.python-version` |
| `windows/container_test.go` | `TestContainerE2E`：由 docker 命令行驱动的 Server Core 容器，装有 PowerShell 7、Visual C++ 运行时和 vfox，跑 GraalPy |
| `windows/Dockerfile`、`windows/bootstrap-tools.ps1` | 准备 Server Core 镜像：PowerShell 7、Visual C++ 运行时和 vfox |

Dockerfile 只负责准备环境。Go 测试把插件复制进容器，然后在容器里执行每一步。

## 各子测试检查什么

Linux，在 runner 上：

- `source build`：从源码构建 CPython 3.12.2，设置 `VFOX_PYTHON_USE_UV_BUILD=0`。
- `mirror`：通过华为云镜像从源码构建 CPython 3.12.1，设置 `VFOX_PYTHON_USE_UV_BUILD=0`。
- `uv-build`：`python@3.11` 安装最新的 CPython 3.11 uv-build 包，`vfox use` 选中它，检查完整版本号和 pip。
- `graalpy`：GraalPy 24.2.0，按实现名断言。
- `link`：`vfox link --detect python` 纳入已安装的 Python，`vfox list` 显示为已链接。
- `python-version`：项目里的 `.python-version` 指向 uv-build 的 CPython，并且优先于全局的
  GraalPy。检查输出的是实现名，所以 GraalPy 不可能通过这个检查。

Linux，在容器里：

- `default install without build packages`：用默认设置对 uv-build 索引列出的某个 CPython 精确版本执行 `vfox install`，会使用 uv-build 包。
  安装好的 CPython 能导入 `ssl`、`sqlite3`、`bz2`、`lzma`、`ctypes`、`readline`、`curses`、`zlib` 和 `hashlib`，pip 也能运行。这是
  [平台](platforms.md#linux-构建依赖) 里“uv-build 安装不需要 apt 包”这一说法的依据。
- `graalpy-24.2.0` 和 `graalpy-community-24.2.0`：GraalPy 能安装并运行、pip 可用，并且
  `.python-version` 能让 uv-build 的 CPython 优先于全局的 GraalPy。

Windows，在 runner 上：

- `installer`：CPython 3.12.2，下载地址是 EXE：`python-3.12.2-amd64.exe`。
- `MSI installer`：CPython 3.4.4，python.org 只发布了它的 MSI。下载地址是 `python-3.4.4.amd64.msi`，`python3` 会解析到插件创建的别名。子测试需要 `System32` 里有 `msvcr100.dll`：设置了 `CI=true`（GitHub Actions 会设置）且缺少该 DLL 时，子测试安装 Visual C++ 2010 x64 运行库；其他环境下则跳过，并给出原因。安装步骤见 [平台](platforms.md#windows)。
- `mirror`、`uv-build`、`graalpy`、`python-version`：和 Linux 一样。GraalPy 子测试在
  `py -0p` 里找到自己的项，因为启动器注册默认开启。

Windows，在容器里：GraalPy 25.5.5（Community，Python 3.13）。

## 运行

```bash
cd tests/e2e
go test -v ./linux
go test -v ./windows   # 在开启了 Windows 容器模式 Docker 的 Windows 主机上
```

设置 `VFOX_SKIP_CONTAINER_E2E=1` 只跑主机原生套件，比如机器上没有 Docker 时：

```bash
VFOX_SKIP_CONTAINER_E2E=1 go test -v ./linux
```

`-run` 用来选子测试。`python-version` 需要先运行 `uv-build` 子测试，所以两者要一起选：

```bash
go test -v -run 'TestNativeE2E/^(uv-build|graalpy|python-version)$' ./linux
```

要求：

- `source build` 和 `mirror` 子测试需要 [平台](platforms.md#linux-构建依赖) 里列出的 Linux
  构建包。GitHub 的 Ubuntu runner 有这些包；开发机不一定有，缺少时这两个子测试会失败。
  uv-build、GraalPy 和容器子测试都不需要这些包。
- Windows 容器测试需要开启 Windows 容器模式的 Docker。`windows-latest` runner 提供它。该测试直接调用 `docker` 命令行（`build`、`run`、`cp`、`exec`），没有使用 testcontainers-go：testcontainers 会为每个容器创建 bridge 网络，而 Windows 引擎没有 bridge 驱动。
- `GITHUB_TOKEN` 或 `GH_TOKEN` 是可选的。设置后，GraalPy 安装会用它访问 GitHub API，
  避开匿名访问的限额；不设置时，插件会退回到自己构造的资源地址。
