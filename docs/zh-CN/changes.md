# 变更记录

[中文](changes.md) | [English](../changes.md)

## 未发布

- uv-build 索引和 pyenv 版本列表现在用同一个比较函数从新到旧排序。过去 `VFOX_PYTHON_USE_UV_BUILD=1`
  的列表保留索引返回的顺序，`latest` 依赖这个顺序；pyenv 列表则把带后缀的名字（如 `3.13.18t`）当成
  `3.13.0` 来比较。`latest` 现在选最新的常规版本，并跳过自由线程版；自由线程版只有写出名字时才会安装。
- 在 Linux 和 macOS 上，`vfox install python@<版本>` 现在会在 uv-build 索引列出某个 CPython 版本时，
  从它的 uv-build 预编译包安装；只有索引没有列出时才从源码构建。设置 `VFOX_PYTHON_USE_UV_BUILD=0`
  可以让每个 CPython 都继续从源码构建，设置 `VFOX_PYTHON_USE_UV_BUILD=1` 则只使用 uv-build。GraalPy、
  PyPy 和 Conda 的安装保持不变。`vfox search python` 会把 pyenv 的名字和只有 uv-build 列出的 CPython 版本一起列出。
  此变更之前已完成的安装不会被改动。若设置了 `VFOX_PYTHON_MIRROR`，CPython 保持走源码构建的路径，
  除非同时设置了 `VFOX_PYTHON_UV_BUILD_MIRROR`。
- 在 Linux 和 macOS 的默认模式下，部分版本号（如 `python@3.12`）先在 uv-build 索引里解析，
  所以会安装索引列出的最新 3.12 预编译包。精确版本号仍可选中任何版本，包括索引里没有的较新 pyenv 补丁版。
- 无法读取 pyenv 版本索引时，报错会写出 HTTP 状态码，而不是因为 Lua 字符串拼接错误而失败。
- 部分版本号（如 `python@3.12`）现在会选中名字带 `-opt` 的链接安装，如 `3.12.8-opt`；
  `python@3.13t` 会选中自由线程的链接安装，如 `3.13.1t-uv`。来源后缀不再被当作版本的一部分。
- `.python-version` 中的部分版本号（如 `3.13`）与 `vfox use` 遵循同一规则：不再选中自由线程
  （`t`）或预发布版。`3.13t` 仍然选中自由线程版本；预发布版请写完整名字，如 `3.14.0a4`。
- 两个安装的版本号相同（如 `3.12.8-local` 和 `3.12.8-system`）时，`.python-version`、`system`
  和 `latest_installed` 的回退都先选裸版本，其余按名字排序取第一个，不再取决于名字的列出顺序。
- `system` 和 `latest_installed` 的回退现在只选常规的 CPython 安装。过去它们把所有已安装名字的版本号放在一起比较，
  所以 `system` 会选中 `graalpy-24.2.0-system` 而不是 `3.12.3-system`，自由线程和预发布版也可能仅凭版本号更大而被选中。
  没有 CPython 安装时，回退仍然选已安装的任意名字。要选中自由线程、预发布版或 GraalPy，请写完整名字。
- Windows 上的 EXE 安装不再携带或运行 WiX 工具。插件用 Windows 自带的 `expand.exe` 从安装包里解出 MSI，
  `bin/` 目录已移除。杀毒软件因此没有 WiX 工具可以隔离。安装的 MSI 与以前相同。

## 0.6.3

- 源码构建失败时，报错会指出常见原因：缺少构建依赖，例如 Debian/Ubuntu 上的 `zlib1g-dev`，并链接到
  平台说明。没有 zlib 头文件时，`make install` 会在 ensurepip 步骤失败。
- Windows 上，如果 python.org 没有某个版本的安装包（如 3.12.12），`vfox install` 会在下载前
  停止，不再等下载完成后才失败。
- `vfox use` 遇到缺少 `bin` 目录的 Python 版本时会停止并提示重新安装，不再对损坏的安装报告
  “Now using”。
- Windows EXE 安装解压失败时，错误信息会指出缺失的 WiX `dark.exe`（杀毒软件可能会把它隔离），
  并报告 `dark.exe` 的退出码。
- 部分版本号（如 `python@3.12`）在所有模式下都能用于 `vfox install` 和 `vfox use`：安装选出该模式
  列出的最新稳定版（pyenv、python.org 或 uv-build 索引），使用则选出已安装的最新匹配项。uv-build
  安装记录完整版本名，Windows 的 MSI 安装和 EXE 安装一样创建 `python3` 别名。
- 支持 GraalPy：Linux、macOS 和 Windows amd64 都从 Oracle 官方的发布压缩包安装
  Oracle GraalVM 和 Community 两种发行版；Linux 和 macOS 的版本列表仍然来自
  pyenv。版本备注会标出发行版。Windows arm64/386 和 uv-build 仍然只支持
  CPython。
- `vfox link --detect python` 会纳入 GraalPy，命名为
  `graalpy[-community][<python>]-<release>-<来源>`。
- Windows 上的 GraalPy 安装可以按 PEP 514 注册给 `py.exe` 使用；`SysVersion`
  是 Python 语言版本，不写 `WindowedExecutablePath`。
- E2E 新增 `tests/e2e/` 下的 Linux 和 Windows 容器镜像，从 Oracle 的发布包
  安装 GraalPy，并检查 `python`、`pip` 和 `.python-version`，与原有 runner
  矩阵并存。
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
- Windows 安装默认会按 PEP 514 注册到 vfox 自己的 `VersionFox` company key，供
  `py.exe` 使用；设置 `VFOX_PYTHON_REGISTER_PY_LAUNCHER=0` 可以关闭。插件不写
  `PythonCore`；`py -3.x` 仍然只选 PythonCore，vfox 的版本用
  `py -V:VersionFox/<版本>` 选中。`PreUninstall` 在注册项仍指向该版本时删除它。
- Windows 上老版本的 MSI 安装（如 3.4.4）需要该版本构建时对应的 Visual C++ 运行库。
  `ensurepip` 以退出码 `-1073741515` 退出时，安装失败，输出会指出缺少的运行库；3.4 的 x64
  运行库和安装步骤见 [平台](platforms.md#windows)。

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
