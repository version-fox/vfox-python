# 端到端测试

[中文](e2e.md) | [English](../e2e.md)

E2E 分两层：

1. **容器套件**：`tests/e2e/` 在 Linux 容器和 Windows 容器里执行真实安装，隔离
   验证 GraalPy 下载、`ensurepip`、`PATH` 和 `.python-version` 行为。
2. **Runner 套件**：`.github/workflows/e2e.yml` 在 GitHub 的 Linux 和 Windows
   runner 上原生跑更广的矩阵：CPython 源码构建、python.org 和华为镜像、
   uv-build、`vfox link --detect` 和 PEP 514 注册。

两者都由 pull request 触发。离线 Lua 钩子测试在 `test.yml` 里，见
[开发](development.md)。

## Linux 容器

镜像基于 Ubuntu 24.04，安装校验和固定的 vfox 1.1.0，复制插件源码，然后完整
跑一遍 GraalPy：

```bash
docker build --file tests/e2e/linux/Dockerfile --tag vfox-python-e2e-linux .
docker run --rm -e GRAALPY_VERSION=graalpy-24.2.0 vfox-python-e2e-linux
```

工作流用 `graalpy-24.2.0` 和 `graalpy-community-24.2.0` 两个版本。每次运行检查：

- `vfox add` 能加载从当前 checkout 构建的插件，
- `vfox install` 下载 Oracle 的压缩包并校验 SHA-256，
- `python -V` 和 `sys.implementation.name` 报告 GraalPy，
- `python -m pip` 和 `pip` 都可用，
- 项目的 `.python-version` 能选中已安装的 GraalPy。

## Windows 容器

镜像基于 Windows Server Core，安装 PowerShell 7、vfox 1.1.0 和插件，然后安装
GraalPy amd64：

```powershell
docker build --file tests/e2e/windows/Dockerfile --tag vfox-python-e2e-windows .
docker run --rm -e GRAALPY_VERSION=graalpy3.13-community-25.5.5 vfox-python-e2e-windows
```

Windows 容器需要 Windows 主机并启用 Windows 容器模式。基础镜像是
`mcr.microsoft.com/windows/servercore:ltsc2025-KB5122871-amd64`，与 Java 插件
CI 使用的一致，保证 `windows-latest` 上的主机和容器系统版本匹配。

Windows 运行检查同样的安装、`python`、`pip` 和 `.python-version` 行为。PEP 514
注册由 runner 套件检查，因为 Server Core 镜像里没有 Python 启动器。

## 环境变量

| 变量 | 默认值 | 含义 |
| --- | --- | --- |
| `GRAALPY_VERSION` | Linux `graalpy-24.2.0`；Windows `graalpy3.13-community-25.5.5` | 要安装的 GraalPy 版本 |
| `GITHUB_TOKEN`、`GH_TOKEN` | 未设置 | 列出 GraalPy 发布时提高 GitHub API 限额 |

GitHub 发布下载偶尔会以瞬时 EOF 结束，所以安装会重试三次。
