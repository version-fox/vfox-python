# 开发

[中文](development.md) | [English](../development.md)

## 目录结构

```
metadata.lua                    插件名、版本、提示，以及 .python-version
hooks/available.lua             vfox search
hooks/pre_install.lua           vfox install：选择版本并命名
hooks/post_install.lua          vfox install：编译、运行安装包或解压 uv-build
hooks/env_keys.lua              选中版本的 PATH
hooks/pre_use.lua               vfox use：修 shebang，跳过链接版本
hooks/parse_legacy_file.lua     .python-version
hooks/detect.lua                vfox link --detect：找出本机已有的 Python
lib/util.lua                    版本、下载、Windows 安装、uv-build、shebang
lib/windows_command.lua         base64 PowerShell 命令和 MSI junction
lib/python_version.lua          版本解析和已安装名字匹配
lib/detect_python.lua           Detect 钩子的来源和过滤
tests/*_test.lua                离线的钩子测试，由 vfox plugin test 运行
tests/windows_install_layouts.lua  Windows 命令路径，进程调用用 stub 代替
tests/fixtures/                 .python-version 测试用的文件
bin/WiX/                        解 Windows EXE 安装包用的 WiX 工具
.github/workflows/              test、lint、license、e2e 和 publish
docs/, docs/zh-CN/              中英文文档
Injection.lua                   vfox 注入对象的类型提示，不会被加载
stylua.toml, .luarc.json        Lua 格式化和语言服务器设置
.licenserc.yaml, .license.tpl   Apache 头检查
```

vfox 加载 `metadata.lua`，命令需要时调用相应的钩子，并向钩子提供 `PLUGIN`、
`RUNTIME`（`osType`、`archType`、`version`、`pluginDirPath`）以及
`OS_TYPE`/`ARCH_TYPE`。`lib/util.lua` 是一个脚本，为老钩子定义全局函数；较新的
模块（`python_version`、`detect_python`、`windows_command`）返回表。

## 一条命令会执行什么

| 你执行 | 调用的钩子 |
| --- | --- |
| `vfox search python` | `Available` |
| `vfox install python@3.12.2` | `PreInstall` 返回 URL 和版本名。vfox 下载并解压，然后调用 `PostInstall` |
| `vfox use python@3.12.2` | `PreUse` 返回要选中的已安装版本名，`EnvKeys` 提供 `PATH` |
| 进入有 `.python-version` 的目录 | `ParseLegacyFile` |
| `vfox link --detect python` | `Detect` 返回本机已有的 Python |
| `vfox uninstall python@3.12.2` | 没有插件钩子；vfox 删除版本目录 |

## 几条容易踩坑的约定

### PreInstall

返回 `version`、`url`、`headers`、`sha256` 和 `note`；vfox 下载 URL，有
`sha256` 时校验，解压后按 `version` 命名。

- `version = "latest"` 会解析成 `Available({})[1].version`。列表从新到旧，
  所以可能是预发布版。
- Windows 上，没有当前架构的精确 EXE 或 MSI 时，在下载前就拒绝；
  `Available` 应该已经过滤掉。
- uv-build 模式返回索引里的包地址和校验和。地址必须是 HTTPS；校验和不可用时
  安装失败，而不是跳过校验。
- `note = "uv-build"` 会显示在 vfox 里。

### PostInstall

`ctx.rootPath` 是 vfox 目录，`ctx.sdkInfo["python"]` 里有版本目录（`path`）和
名字（`version`）。

- Linux 和 macOS 上，把 pyenv 克隆到 `ctx.rootPath .. "/pyenv"`，运行
  `python-build <版本> <path>`，结束后删掉克隆。
- Windows 上，用 `bin/WiX/dark.exe` 解开 EXE，把里面的 MSI 安装进 `path`，
  再用 `ensurepip` 装 pip。MSI 直接安装。别名可执行文件复制到 `python.exe`
  旁边。
- uv-build 模式下，包已经由 vfox 解压；钩子在 `path/python-<版本>` 下找
  payload，Unix 上修 shebang，Windows 上确保 pip 可用。
  `resolvePythonInstallPath` 两种布局都处理。
- uv-build 会拒绝 `ctx.rootPath` 之外的路径，避免错误的索引让钩子写到别处。

### PreUse

切换版本前，钩子检查 `bin/pip`、`bin/pip3` 和 `bin/easy_install`，并修正仍指向
`.version-fox/temp/...` 的 shebang。用 `vfox link` 链接进来的版本会跳过：安装
归它的主人所有，系统 Python 没有打包工具是正常的。`isLinkedPythonInstall` 用
`test -L` 检查版本目录里的 `python-<版本>` 链接。

### EnvKeys

- Unix：`PATH = ctx.path .. "/bin"`。
- Windows：`PATH = ctx.path` 和 `PATH = ctx.path .. "\\Scripts"`。

所以链接到 `/usr` 的系统 Python 会把 `/usr/bin` 放进 `PATH`，那里的命令是
`python3`，不是 `python`。插件不会往链接进来的安装里创建别名。

### Detect

`Detect` 返回 `{ version, path, note }` 的列表。`path` 是 Python 的 prefix
（包含 `bin` 或 `python.exe` 的那一级），不是虚拟环境。vfox 会按自己的版本名
规则校验，忽略不可用条目、去重，并跳过已安装的名字和已经链接到的目录。

`lib/detect_python.lua`：

- 从 `PATH` 和已知目录收集候选可执行文件（uv、pyenv、asdf、mise、Conda、
  Homebrew、`/usr`、`/usr/local`、`/opt`、Windows 的 `Programs\Python`、
  `C:\Python*`、py 启动器和 Store），
- 用 `-E -s -c` 和一段单行程序询问每个解释器一次，
- 取 `sys.version`、`sys.prefix`、`sys.base_prefix`、真实可执行文件和
  `sys.abiflags`，
- 跳过非 CPython、虚拟环境、vfox 自己的目录和根目录，
- 按 `<版本>[-t]-<来源>` 命名。

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
`strategy = "latest_installed"` 时，条目缺失或读不懂就退回到已安装的最新名字。

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
- 文件没有调用 `test.load()` 会失败；一个测试文件都没找到也会失败。

`tests/windows_install_layouts.lua` 由 GopherLua 运行，因为它在 stub 的进程调用
下执行 `PostInstall` 里真实的 shell 脚本。它检查原生参数编码、MSI 目标引号、
`%` junction、退出码传递和每条失败路径。

E2E 任务安装真实的 Python：Linux 上一次源码构建和一次镜像构建，Windows 上一次
安装包和一次 uv-build，Linux 上还有一次 uv-build。它还会在 Linux 上对 runner
的系统 Python 运行 `vfox link --detect python`，并在两个平台上检查
`vfox env` 是否按项目的 `.python-version` 选择版本。

本地命令：

```bash
vfox plugin test .
go run github.com/yuin/gopher-lua/cmd/glua@v1.1.1 tests/windows_install_layouts.lua
stylua --check .
lua-language-server --check . --checklevel=Warning
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
| 真实安装 | Linux 和 Windows 的 E2E | `e2e.yml` |

`stylua.toml` 用四空格、120 列、Unix 换行；`.gitattributes` 让 checkout 保持
LF，这样 Windows 上的检查和 Linux 一致。LuaLS 读 `.luarc.json`，里面声明了
vfox 的全局变量，只关闭 `duplicate-set-field`（测试会有意替换 `io.popen` 等）。

许可证检查读 `.licenserc.yaml`，`.license.tpl` 是纯文本副本。Markdown、JSON、
`LICENSE`、`.tool-versions`、`tests/fixtures/**` 和 `bin/` 下的第三方 WiX
文件被忽略。新增的 Lua、YAML、TOML、Python 和 ignore 文件都要有头；
缺少时 `license-eye` 会打印修复命令。

## CI

- `test.yml` 在 `ubuntu-latest` 和 `windows-latest` 上用 vfox 1.1.0（校验和
  固定）跑离线测试，在 Linux 上跑 GopherLua 布局测试，并用带空格和 Shell
  字符的路径跑一次真实的 Windows MSI 安装。
- `lint.yml` 跑 StyLua、LuaLS 和 actionlint。
- `license.yml` 跑许可证头检查。
- `e2e.yml` 在 Linux 和 Windows 上真实构建、安装 Python，包括镜像和
  uv-build 组合。
- `publish.yaml` 调用共享的 plugin-manifest 工作流。

## 发布

维护者在默认分支的 **Actions → Plugin → Run workflow** 里发布。输入不带 `v`
的稳定插件版本号；共享工作流会更新 `metadata.lua`，创建版本提交和 tag，并在
本仓库发布 ZIP 和 manifest。Pull request 只跑检查。发布失败时重跑原来失败的
任务即可继续。

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
| `VFOX_PYTHON_USE_UV_BUILD` | Available、PreInstall、PostInstall | 使用 uv-build 预编译包 |
| `VFOX_PYTHON_UV_LIBC` | Available、PreInstall | 覆盖 `gnu` / `musl` 识别 |
| `VFOX_PYTHON_UV_BUILD_MIRROR` | PreInstall | uv-build 包的 HTTPS 镜像 |
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
- 只检测 CPython。其他实现不在范围内。
- 链接版本跟着目标走；发行版把它移走后，版本名和解释器可能对不上，直到再次运行
  Detect。
- 插件不管理虚拟环境。用 `venv`、`uv venv` 或 Conda，再用 vfox 选基础解释器。
