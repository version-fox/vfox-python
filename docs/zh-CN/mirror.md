# 镜像

[中文](mirror.md) | [English](../mirror.md)

## python.org

`VFOX_PYTHON_MIRROR` 让 python.org 的下载走镜像。它必须是和
`https://www.python.org/ftp/python/` 目录结构相同的地址；结尾没有 `/` 时会
自动补上：

```bash
export VFOX_PYTHON_MIRROR=https://mirrors.huaweicloud.com/python/
```

它会影响：

- Windows 上从 `<镜像>/<版本>/python-<版本>-<架构>.exe`（或 MSI）下载安装包。
- Linux 和 macOS 上，插件通过 `PYTHON_BUILD_MIRROR_URL` 把镜像交给
  python-build，源码包从镜像下载。
- `PreInstall` 检查源码版本是否存在时，问的是镜像，不是 python.org。

版本列表仍来自 pyenv 索引或 python.org 的 Windows 发布页；镜像改变的是下载
地址，不是有哪些版本。

设置这个变量后，插件还会设置 `PYTHON_BUILD_MIRROR_URL_SKIP_CHECKSUM=1`，
因为镜像里的源码包不一定带 python-build 记录的校验和。只使用你信任的镜像。

### 镜像需要包含什么

```
<镜像>/
  3.12.2/
    Python-3.12.2.tar.xz
    Python-3.12.2.tar.bz2        # 只有 bz2 的版本
    python-3.12.2-amd64.exe      # Windows
    python-3.12.2-amd64.msi      # 较老的 Windows 版本
```

不是每个版本都有每个文件。`VFOX_PYTHON_MIRROR` 同时作用于源码和 Windows 安装
包路径，所以两个平台都要用时，镜像要同时包含两类文件。

## uv-build

`VFOX_PYTHON_UV_BUILD_MIRROR` 镜像 uv-build 的预编译包。它必须是 HTTPS，并按
GitHub release 下载的结构存放：

```
<镜像>/<release>/<文件名>
```

默认的 GitHub 地址
`https://github.com/astral-sh/python-build-standalone/releases/download/<release>/<文件名>`
会变成 `<镜像>/<release>/<文件名>`。例如：

```bash
export VFOX_PYTHON_UV_BUILD_MIRROR=https://registry.npmmirror.com/-/binary/python-build-standalone/
```

解压前，插件会用 uv-build 索引里的 SHA-256 校验每个包。镜像提供的字节不一致时
安装会以 `Checksum error` 失败，这是有意的：应该改索引或镜像，不要绕过校验。

## GraalPy

两个镜像变量都不适用于 GraalPy。所有平台都直接从 GitHub 下载 Oracle 的发布
压缩包，并校验 SHA-256。需要走代理时用下面的代理变量。见
[GraalPy](graalpy.md)。

## 代理

vfox 的 HTTP 客户端和 python-build 的 `curl`/`wget` 都认常用的代理变量：

```bash
export HTTPS_PROXY=http://proxy.example:8080
export HTTP_PROXY=http://proxy.example:8080
```

如果只是连接慢，代理比镜像简单；下载本身被封锁时，镜像更有用。

## 用哪个变量

| 目的 | 变量 |
| --- | --- |
| python.org 安装包和源码包 | `VFOX_PYTHON_MIRROR` |
| uv-build 预编译包 | `VFOX_PYTHON_UV_BUILD_MIRROR` |
| uv 自己 `uv python install` 的下载 | `UV_PYTHON_INSTALL_MIRROR` |
| uv-build 的 Linux libc 覆盖 | `VFOX_PYTHON_UV_LIBC` |

前两个属于插件；uv 那个属于 uv，只在你亲自运行 uv 时生效。详见
[uv.md](uv.md)。
