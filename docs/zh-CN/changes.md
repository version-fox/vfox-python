# 变更记录

[中文](changes.md) | [English](../changes.md)

## 未发布

- `vfox link --detect python` 纳入系统、uv、pyenv、asdf、mise、Conda、
  Homebrew、Nix、Snap、python.org、Store 和 py 启动器的 Python（需要 vfox
  1.1.0 或更高版本）。链接进来的版本命名为 `<版本>-<来源>`。
- 通过 `ParseLegacyFile` 读取 `.python-version`，vfox 进入目录时，为 pyenv 和
  uv 写的项目会选中自己的 Python。
- `PreUse` 不再检查链接安装的打包工具，也不再改它的 shebang。
- 中英文文档：版本、uv、链接、平台、镜像、开发和变更记录。
- CI：Linux 和 Windows 上用校验和固定的 vfox 1.1.0 跑离线测试，加 GopherLua
  布局测试、StyLua、LuaLS、actionlint、Apache 许可证头，以及 Linux 和
  Windows 的 E2E 安装。
- Apache 头、`.gitattributes`（LF）、StyLua、LuaLS 和许可证配置，以及
  Detect、`.python-version`、uv-build、镜像和链接版本的新离线测试。
- E2E 覆盖 Linux 上的 `vfox link --detect python`，以及 Linux 和 Windows
  上的项目 `.python-version`。
- `VFOX_PYTHON_MIRROR` 允许结尾不带 `/`，并忽略空值（CI 对未设置的矩阵项
  会传空值）。

## 0.6.2

- Windows 安装路径中的空格、百分号、`!` 和单引号通过 base64 PowerShell 命令
  传递；目标含 `%` 时，MSI 安装期间使用临时 junction。
- Windows 安装检查退出码，并清理临时文件和 junction。

## 0.6.1

- 安装请求带认证，安装冒烟测试选择一个可用的 uv-build 版本。
- 按 python.org 实际为当前架构发布的安装包过滤 Windows Python 版本。

## 0.6.0

- 增加可选的 uv-build 预编译包，支持 libc 识别和 SHA-256 校验。
- 源码和 uv-build 安装后修复 shebang。
