# 开发

[中文](development.md) | [English](../development.md)

## 目录结构

```
metadata.lua                    插件名、版本、提示，以及 .python-version
hooks/available.lua             vfox search
hooks/pre_install.lua           vfox install：选择版本并命名
hooks/post_install.lua          vfox install：编译、运行安装包或解压 uv-build
hooks/pre_uninstall.lua         vfox uninstall：删除 PEP 514 注册
hooks/env_keys.lua              选中版本的 PATH
hooks/pre_use.lua               vfox use：修 shebang，跳过链接版本
hooks/parse_legacy_file.lua     .python-version
hooks/detect.lua                vfox link --detect：找出本机已有的 Python
lib/util.lua                    版本、下载、Windows 安装、uv-build、shebang
lib/windows_command.lua         base64 PowerShell 命令和 MSI junction
lib/pep514.lua                  Windows Python 启动器注册
lib/python_version.lua          版本解析和已安装名字匹配
lib/detect_python.lua           Detect 钩子的来源和过滤
tests/*_test.lua                离线的钩子测试，由 vfox plugin test 运行
tests/windows_install_layouts.lua  Windows 命令路径，进程调用用 stub 代替
tests/e2e/                      Go 端到端套件，覆盖 Linux 和 Windows，见 e2e.md
tests/fixtures/                 .python-version 测试用的文件
bin/WiX/                        解 Windows EXE 安装包用的 WiX 工具
.github/workflows/              test、lint、license、e2e 和 publish
docs/, docs/zh-CN/              中英文文档
Injection.lua                   vfox 注入对象的类型提示，不会被加载
stylua.toml, .luarc.json        Lua 格式化和语言服务器设置
.licenserc.yaml, .license.tpl   Apache 头检查
opencode.jsonc                  让本仓库里的 OpenCode 智能体会话不必确认就能执行
                                git push、gh pr create 和 gh pr comment
```

vfox 加载 `metadata.lua`，命令需要时调用相应的钩子，并向钩子提供 `PLUGIN`、
`RUNTIME`（`osType`、`archType`、`version`、`pluginDirPath`）以及
`OS_TYPE`/`ARCH_TYPE`。`lib/util.lua` 是一个脚本，为老钩子定义全局函数；较新的
模块（`python_version`、`detect_python`、`windows_command`、`pep514`）返回表。

## 一条命令会执行什么

| 你执行 | 调用的钩子 |
| --- | --- |
| `vfox search python` | `Available` |
| `vfox install python@3.12.2` | `PreInstall` 返回 URL 和版本名。vfox 下载并解压，然后调用 `PostInstall` |
| `vfox use python@3.12.2` | `PreUse` 返回要选中的已安装版本名，`EnvKeys` 提供 `PATH` |
| 进入有 `.python-version` 的目录 | `ParseLegacyFile` |
| `vfox link --detect python` | `Detect` 返回本机已有的 Python |
| `vfox uninstall python@3.12.2` | `PreUninstall` 删除 PEP 514 注册；vfox 删除版本目录 |

## 几条容易踩坑的约定

### PreInstall

返回 `version`、`url`、`headers`、`sha256` 和 `note`；vfox 下载 URL，有
`sha256` 时校验，解压后按 `version` 命名。部分版本号（如 `3.12`）会先解析。在 Linux 和 macOS 的默认模式下，若 uv-build 索引里有匹配版本，
就解析成它；否则（以及其他所有模式下）解析成 `Available({})` 里该模式最新的稳定版。精确版本号不会查列表。

- `version = "latest"` 会解析成 `Available({})[1].version`。CPython 在列表最
  前面、从新到旧排列，所以可能是预发布版；GraalPy 要用完整版本名。
- Windows 上，`Available` 只列出下载页里当前架构的精确安装包文件名。PreInstall 仍会先对 EXE、
  再对 MSI 发 HEAD 请求；两者都没有返回 200 时，在任何下载开始前停止，并提示
  `Python <版本> has no Windows installer on python.org`。
- GraalPy 会到 Oracle 的发布资源里找当前平台的对应版本，返回官方压缩包地址和
  SHA-256；Linux 和 macOS 用 `linux-*`/`macos-*` 的 tar.gz，Windows 用
  `windows-amd64.zip`。GitHub API 被限流时，钩子会根据版本构造资源地址，并在
  使用前校验对应的 `.sha256`。
- uv-build 模式返回索引里的包地址和校验和。地址必须是 HTTPS；校验和不可用时
  安装失败，而不是跳过校验。GraalPy 会被拒绝，因为索引里只有 CPython。
- 默认模式（未设置 `VFOX_PYTHON_USE_UV_BUILD`，在 Linux 和 macOS 上，且未设置 `VFOX_PYTHON_MIRROR`，除非同时设置了 `VFOX_PYTHON_UV_BUILD_MIRROR`）只在索引里查 CPython 版本，
  非 CPython 的名字从不在那里查找。索引列出该版本时，结果与 uv-build 模式相同。索引没有列出时，
  PreInstall 会打印一行，并且不返回包，于是 vfox 运行 pyenv 源码构建。索引请求失败会报错，
  错误信息里写明 `VFOX_PYTHON_USE_UV_BUILD=0`。检测不到 libc 时，使用源码构建。
- `note = "uv-build"`、`"GraalPy"` 或 `"GraalPy Community"` 会显示在 vfox 里。

### PostInstall

`ctx.rootPath` 是 vfox 目录，`ctx.sdkInfo["python"]` 里有版本目录（`path`）和
名字（`version`）。

- Linux 和 macOS 上，把 pyenv 克隆到 `ctx.rootPath .. "/pyenv"`，运行
  `python-build <版本> <path>`，结束后删掉克隆。
- Windows 上，CPython 的 EXE 用 `bin/WiX/dark.exe` 解开，把里面的 MSI 安装进
  `path`，再用 `ensurepip` 装 pip。MSI 直接安装。别名可执行文件复制到
  `python.exe` 旁边。
- GraalPy 压缩包已经由 vfox 解压；钩子在 `graalpy*-<平台>` 目录下找 payload，
  运行包里自带的 `ensurepip`。Unix 上修 shebang；Windows 上用
  `bin/python.exe` 运行，缺少启动器时创建 pip shim。
- uv-build 模式下，以及默认模式里 PreInstall 返回了归档的情况下，包已经由 vfox 解压。
  PostInstall 在 PreInstall 设置的 `note` 为 `uv-build` 时走归档路径；vfox 会把 `note` 放进
  `sdkInfo` 传给 PostInstall，所以 PostInstall 不会再问一次索引。如果安装目录里已经有 Python，
  源码构建会停止：vfox 会清理失败或中断的安装目录，因此那个 Python 来自归档，直接覆盖会悄悄替换掉它。
  钩子负责在 Unix 上修 shebang，在 Windows 上确保 pip 可用。
  `resolvePythonInstallPath` 处理 MSI、uv-build 和 GraalPy 三种布局。
- uv-build 会拒绝 `ctx.rootPath` 之外的路径，避免错误的索引让钩子写到别处。
- 除非 `VFOX_PYTHON_REGISTER_PY_LAUNCHER` 设为 `0`、`false`、`no` 或 `off`，钩子都会按
  PEP 514 把版本注册到
  `HKCU\Software\Python\VersionFox\<tag>`。tag 用完整版本号，非默认架构加
  `-32`/`-arm64`，多个补丁版本可以并存。它不会写 `PythonCore`。GraalPy 的
  `SysVersion` 用 Python 语言版本，并省略可选的 `WindowedExecutablePath`。

### PreUninstall

`ctx.main` 里有版本目录（`path`）和名字（`version`）。Windows 上，钩子只在
`VfoxManaged` 为 `1` 且注册的 `InstallPath` 仍指向该版本目录时，删除
`HKCU\Software\Python\VersionFox\<tag>`；如果 `VersionFox` company key 已经
没有子项，也一并删除。即使 `VFOX_PYTHON_REGISTER_PY_LAUNCHER=0` 关闭了注册，钩子
仍会运行，所以卸载时不会留下旧的注册项。

`lib/pep514.lua` 在读写注册项之前会识别 MSI 布局（`path/python.exe`）、uv-build
布局（`path/python-<版本>/python.exe`）和 GraalPy 布局
（`path/graalpy*-windows-amd64/bin/python.exe`）。

### PreUse

部分版本号（如 `3.12`）会先解析成已安装版本里最新的匹配项（`lib/python_version.lua`
的 `find_release`），vfox 原样传入请求。然后再做下面的检查。切换版本前，钩子检查 `bin/pip`、`bin/pip3` 和 `bin/easy_install`，并修正仍指向
`.version-fox/temp/...` 的 shebang。用 `vfox link` 链接进来的版本会跳过：安装
归它的主人所有，系统 Python 没有打包工具是正常的。`isLinkedPythonInstall` 用
`test -L` 检查版本目录里的 `python-<版本>` 链接。

Windows 上钩子直接返回，上面的检查都不运行。Unix 上，安装目录没有 `bin` 时，`vfox use`
会报错，并给出先 `vfox uninstall` 再 `vfox install` 的命令，不再对损坏的安装显示 “Now using”。

### EnvKeys

- Unix：`PATH = ctx.path .. "/bin"`；GraalPy 用 `<prefix>/bin`，prefix 从
  解压目录里解析。
- Windows CPython：`PATH = ctx.path` 和 `PATH = ctx.path .. "\\Scripts"`。
- Windows GraalPy：`PATH = <prefix>\\bin` 和 `PATH = <prefix>\\Scripts`，
  其中 `<prefix>` 是从解压目录里解析出来的。

所以链接到 `/usr` 的系统 Python 会把 `/usr/bin` 放进 `PATH`，那里的命令是
`python3`，不是 `python`。插件不会往链接进来的安装里创建别名。

### Detect

`Detect` 返回 `{ version, path, note }` 的列表。`path` 是 Python 的 prefix
（包含 `bin` 或 `python.exe` 的那一级），不是虚拟环境。vfox 会按自己的版本名
规则校验，忽略不可用条目、去重，并跳过已安装的名字和已经链接到的目录。

`lib/detect_python.lua`：

- 从 `PATH` 和已知目录收集候选可执行文件（uv、pyenv、asdf、mise、Conda、
  Homebrew、`/usr`、`/usr/local`、`/opt`、`~/graalpy*`、Windows 的
  `Programs\Python`、`C:\Python*`、`C:\graalpy*`、py 启动器和 Store），
- 用 `-E -s -c` 和一段单行程序询问每个解释器一次，
- 取 Python 版本和实现（`platform` 模块）、`sys.prefix`、`sys.base_prefix`、真实可执行文件和
  `sys.abiflags`，GraalPy 还取 `__graalpython__.get_graalvm_version()` 和
  Oracle/Community 发行版，
- 跳过 PyPy 等其他实现、虚拟环境、vfox 自己的目录和根目录，
- CPython 按 `<版本>[-t]-<来源>` 命名，GraalPy 按
  `graalpy[-community][<python>]-<release>-<来源>` 命名。

解释器把 UTF-8 路径打印成十六进制（`PREFIX_HEX=...`），这样非 ASCII 用户名
能穿过 Windows 控制台和管道编码。Python 程序本身是单行、用转义换行写的，因为
`windows_command` 不接受参数里的控制字符。

### ParseLegacyFile

`metadata.lua` 声明 `.python-version`。钩子读第一个非空、非注释行，转换
`cpython-<版本>` 和 uv 的 `+freethreaded` 写法，再和
`ctx.getInstalledVersions()` 匹配。

调用 `ctx.getInstalledVersions()` 时不能带参数。vfox 把它绑定成 Go 的
`func() []string`；`ctx:getInstalledVersions()` 会多传一个参数并静默失败。

钩子返回 `{ version = name }` 或 `{}`。没安装的版本不选任何东西。
`strategy = "latest_installed"` 时，条目缺失或读不懂就退回到最新的常规 CPython；没有 CPython 时，退回到已安装的最新名字。

部分版本号（如 `3.13`）在 `.python-version` 里用 `find_release` 解析，和 PreUse 用的是同一个函数，
所以不会选中自由线程或预发布版。其他请求（如 `3.12.8`）按前缀匹配，链接进来的 `3.12.8-system`
仍然算数。几个名字版本号相同时，先选裸名字，其余按名字排序取第一个，结果与列出的顺序无关。

### windows_command

`lib/windows_command.lua` 生成 `powershell -NoProfile -NonInteractive
-EncodedCommand <base64 UTF-16LE>`，其中每个程序和参数单独按 UTF-8 base64
编码。没有任何内容被拼进 cmd 或 PowerShell 的解析器，所以空格、`%`、`!`、
`&` 和单引号都只是数据。`command.msi` 会转义引号目标末尾的反斜杠；目标里有
`%` 时使用临时目录 junction，因为 Windows Installer 复制文件时会展开 `%`。
junction 在 `finally` 里删除，MSI 的退出码会保留。

## 测试

`vfox plugin test .`（vfox 1.0.13 起；`Detect` 需要 1.1.0）会发现
`tests/**/*_test.lua`。每个文件有独立的 VM 和强类型插件对象：

```lua
local test = require("vfox.test")
local plugin = test.load({ os = "linux", arch = "amd64", env = { HOME = "/home/test" } })
local versions = plugin:Available({})
```

- `env` 的值是字符串，或用 `false` 表示不存在。
- `http` 是接收 `{ method, url, headers }` 的函数；返回响应表或 `nil, err`。
  不提供时，请求默认被拒绝，除非加 `--online`。
- `os.execute` 和 `io.popen` 默认禁用，测试自己替换。Detect 测试用
  `io.open`/`io.popen` 的 stub 模拟文件和命令；PreUse 测试替换 `io.popen`。
- PEP 514 测试替换 `os.execute` 和 `io.open`，在 Linux 和 Windows 上检查注册
  与清理命令的生成，不会真的写注册表。
- 文件没有调用 `test.load()` 会失败；一个测试文件都没找到也会失败。

`tests/windows_install_layouts.lua` 由 GopherLua 运行，因为它在 stub 的进程调用
下执行 `PostInstall` 里真实的 shell 脚本。它检查原生参数编码、MSI 目标引号、
`%` junction、退出码传递和每条失败路径。

E2E 套件在 `tests/e2e` 里，使用 Go 编写。Linux 包在 runner 上安装 CPython
源码构建（`VFOX_PYTHON_USE_UV_BUILD=0`）、镜像构建、uv-build 和 GraalPy，还会运行 `vfox link --detect` 和项目
的 `.python-version`。Windows 包安装 CPython 和 uv-build，安装带 PEP 514 注册的
GraalPy，并检查 `.python-version`。两个包也在 Docker 容器里跑 GraalPy 检查：Linux 包通过
testcontainers-go，Windows 包直接调用 `docker` 命令行，因为 testcontainers-go 会为每个容器
创建 bridge 网络，而 Windows 引擎没有 bridge 驱动。目录结构和本地命令见
[端到端测试](e2e.md)。

本地命令：

```bash
vfox plugin test .
go run github.com/yuin/gopher-lua/cmd/glua@v1.1.1 tests/windows_install_layouts.lua
stylua --check .
lua-language-server --check . --checklevel=Warning
cd tests/e2e && go test -v ./linux
cd tests/e2e && go test -v ./windows
VFOX_SKIP_CONTAINER_E2E=1 go test -v ./linux
```

## 检查

| 检查 | 工具 | 工作流 |
| --- | --- | --- |
| Lua 格式 | StyLua 2.6.0，`--check .` | `lint.yml` |
| Lua 诊断 | LuaLS 3.19.1，warning 级别 | `lint.yml` |
| 工作流语法 | actionlint 1.7.7 | `lint.yml` |
| Apache 头 | Apache SkyWalking Eyes | `license.yml` |
| 钩子测试 | 在 Linux 和 Windows 上 `vfox plugin test .` | `test.yml` |
| Windows 命令路径 | GopherLua | `test.yml` |
| 原生和容器 E2E | Linux 和 Windows 上的 Go 测试 | `e2e.yml` |

`stylua.toml` 用四空格、120 列、Unix 换行；`.gitattributes` 让 checkout 保持
LF，这样 Windows 上的检查和 Linux 一致。LuaLS 读 `.luarc.json`，里面声明了
vfox 的全局变量，只关闭 `duplicate-set-field`（测试会有意替换 `io.popen` 等）。

许可证检查读 `.licenserc.yaml`，`.license.tpl` 是纯文本副本。Markdown、JSON、
`LICENSE`、`.tool-versions`、`tests/fixtures/**` 和 `bin/` 下的第三方 WiX
文件被忽略。新增的 Lua、YAML、TOML、Python 和 ignore 文件都要有头；
缺少时 `license-eye` 会打印修复命令。

## CI

- `test.yml` 在 `ubuntu-latest` 和 `windows-latest` 上用 vfox 1.1.0（校验和
  固定）跑离线测试，在 Linux 上跑 GopherLua 布局测试，并用带空格和 Shell 字符的路径，
  由发布版 vfox 1.0.12 在 Windows 上通过 EXE 安装包真实安装一次 CPython 3.14.5。
- `lint.yml` 跑 StyLua、LuaLS 和 actionlint。
- `license.yml` 跑许可证头检查。
- `e2e.yml` 在 Linux 和 Windows 上真实构建、安装 Python，包括镜像、uv-build
  和 GraalPy，并检查 Windows 上的 PEP 514 注册。
- `publish.yaml` 调用共享的 plugin-manifest 工作流。

## 发布

维护者在默认分支的 **Actions → Plugin → Run workflow** 里发布。输入不带 `v`
的稳定插件版本号；共享工作流会更新 `metadata.lua`，创建版本提交和 tag，并在
本仓库发布 ZIP 和 manifest。Pull request 只跑检查。发布失败时重跑原来失败的
任务即可继续。不需要本地打 tag，也不需要额外的发布 token。推送 `v*` tag 同样会运行发布任务；只要
`metadata.lua` 里的 `PLUGIN.version` 已与 tag 一致，就会正常发布。工作流调用的是共享的
`version-fox/plugin-manifest-action`，固定在 `@v1`；升级该工具本身不会发布本插件。

## 增加一个检测来源

1. 在 `lib/detect_python.lua` 的 `known_roots()` 里加一个根目录，写上来源后缀；
   如果它下面是一组安装，再加子目录名模式。
2. 把后缀加到 `notes`，以及 `docs/link.md`、`docs/zh-CN/link.md`、
   `docs/versions.md`、`docs/zh-CN/versions.md` 的表格里。
3. 来源有配置变量时，加到本文档和 `docs/link.md` 的环境变量表。
4. 在 `tests/detect_test.lua` 或 `tests/detect_windows_test.lua` 里加一个用例，
   包括一个必须被跳过的路径。
5. 运行 `vfox plugin test .` 和 `stylua --check .`。

## 环境变量

| 变量 | 使用者 | 含义 |
| --- | --- | --- |
| `VFOX_PYTHON_MIRROR` | PreInstall、PostInstall | python.org 镜像；结尾没有 `/` 会自动补上 |
| `VFOX_PYTHON_USE_UV_BUILD` | Available、PreInstall、PostInstall | 未设置：在 Linux 和 macOS 上，索引列出的 CPython 版本用 uv-build；`0`、`false`、`no` 或 `off`：源码构建；`1`、`true`、`yes` 或 `on`：只用 uv-build |
| `VFOX_PYTHON_UV_LIBC` | Available、PreInstall | 覆盖 `gnu` / `musl` 识别 |
| `VFOX_PYTHON_UV_BUILD_MIRROR` | PreInstall | uv-build 包的 HTTPS 镜像 |
| `VFOX_PYTHON_REGISTER_PY_LAUNCHER` | PostInstall、PreUninstall | 把 Windows 安装注册到 `HKCU\Software\Python\VersionFox`；默认开启，`0`、`false`、`no`、`off` 关闭 |
| `GITHUB_TOKEN`、`GH_TOKEN` | Available | 提高 Windows GraalPy 发布列表的 GitHub API 限额 |
| `UV_PYTHON_INSTALL_DIR` | Detect | uv 的 Python 目录 |
| `PYENV_ROOT` | Detect | pyenv 根目录 |
| `ASDF_DATA_DIR` | Detect | asdf 数据目录 |
| `MISE_DATA_DIR` | Detect | mise 数据目录 |
| `CONDA_PREFIX` | Detect | 当前 Conda 安装 |
| `XDG_DATA_HOME` | Detect | Unix 上 uv 的默认目录 |
| `VFOX_HOME` | Detect | 插件路径看不出 vfox 目录时，用它跳过 vfox 自己的安装 |
| `PATH` | Detect | 解释器候选 |
| `HOME`、`USERPROFILE` | Detect | 默认安装根目录 |
| `LOCALAPPDATA`、`APPDATA`、`ProgramFiles`、`ProgramFiles(x86)` | Detect | Windows 安装根目录 |
| `HTTPS_PROXY`、`HTTP_PROXY` | vfox、python-build | 下载代理 |

## 已知限制

- Detect 会运行本机解释器，不是沙箱。虚拟环境会跳过，但带慢速 sitecustomize
  的 Python 会拖慢检测，因为单条命令没有超时。
- 只检测 CPython 和 GraalPy。PyPy、Jython 等其他实现不在范围内。
- 链接版本跟着目标走；发行版把它移走后，版本名和解释器可能对不上，直到再次运行
  Detect。
- 插件不管理虚拟环境。用 `venv`、`uv venv` 或 Conda，再用 vfox 选基础解释器。
