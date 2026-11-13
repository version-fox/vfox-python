-- Copyright 2026 Han Li and contributors
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--   http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.

--- Finds CPython and GraalPy installations that are already on the machine,
--- for `vfox link --detect python`. Each result is named the way `vfox install`
--- names a Python, with the source appended: 3.12.8-system, 3.13.1-uv,
--- graalpy-24.2.0-system.
---
--- The interpreter itself is asked for its version and prefix. Everything the
--- hook reports can be linked without copying: a linked version is a symlink
--- to the installation, and `vfox uninstall` removes only that link.
local python_version = require("python_version")
local windowsCommand = require("windows_command")

local detect = {}

local notes = {
    uv = "managed by uv",
    pyenv = "installed by pyenv",
    asdf = "installed by asdf",
    mise = "installed by mise",
    conda = "Conda installation",
    pythonorg = "python.org installer",
    store = "Microsoft Store",
    system = "system package manager",
    ["local"] = "installed under /usr/local",
    brew = "Homebrew",
    nix = "Nix",
    opt = "installed under /opt",
    snap = "Snap",
    scoop = "Scoop",
}

local function os_type()
    return string.lower((RUNTIME and RUNTIME.osType) or OS_TYPE or "")
end

local function is_windows()
    return os_type() == "windows"
end

local function is_darwin()
    return os_type() == "darwin" or os_type() == "macos"
end

local function env(name)
    return os.getenv(name)
end

--- Returns a non-empty environment value, or the fallback. GitHub Actions and
--- other runners often define a variable with an empty value, which Lua would
--- otherwise treat as a real path.
local function env_or(name, fallback)
    local value = env(name)
    if value == nil or value == "" then
        return fallback
    end
    return value
end

local function trim(value)
    return (value:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function home_dir()
    return env_or("HOME", env("USERPROFILE") or "")
end

--- Normalises a path for comparison: forward slashes, no trailing slash and,
--- on Windows, lower case. The value returned by the interpreter keeps its own
--- spelling for display.
local function normalize(path)
    if type(path) ~= "string" or path == "" then
        return ""
    end
    local value = path:gsub("\\", "/"):gsub("/+$", "")
    if value == "" then
        return "/"
    end
    if is_windows() then
        value = value:lower()
    end
    return value
end

local function path_under(path, parent)
    local value, root = normalize(path), normalize(parent)
    if value == "" or root == "" then
        return false
    end
    return value == root or value:sub(1, #root + 1) == root .. "/"
end

local function join(left, right)
    if left == nil or left == "" then
        return right or ""
    end
    if right == nil or right == "" then
        return left
    end
    if is_windows() then
        left = left:gsub("/", "\\")
        right = right:gsub("/", "\\")
        if left:sub(-1) == "\\" then
            return left .. right
        end
        return left .. "\\" .. right
    end
    if left:sub(-1) == "/" then
        return left .. right
    end
    return left .. "/" .. right
end

local function shell_quote(value)
    if is_windows() then
        return '"' .. value:gsub('"', '""') .. '"'
    end
    return "'" .. value:gsub("'", "'\\''") .. "'"
end

local function path_exists(path)
    local file = io.open(path, "r")
    if file then
        file:close()
        return true
    end
    return false
end

--- Runs a command and returns its non-empty output lines. Detection must keep
--- working when a candidate tool is absent or broken, so failures are empty.
local function run_lines(command)
    local handle = io.popen(command, "r")
    if not handle then
        return {}
    end
    local lines = {}
    local ok = pcall(function()
        -- read("*l") works with both GopherLua file handles and vfox's Windows
        -- io.popen table, which has no lines method on vfox 1.1.0.
        while true do
            local line, readErr = handle:read("*l")
            if line == nil then
                if readErr ~= nil then
                    error(readErr)
                end
                break
            end
            line = trim(line)
            if line ~= "" then
                lines[#lines + 1] = line
            end
        end
    end)
    pcall(function()
        handle:close()
    end)
    if not ok then
        return {}
    end
    return lines
end

--- Lists the immediate children of a directory, or {} when it cannot be read.
local function list_children(directory)
    if directory == nil or directory == "" then
        return {}
    end
    local command
    if is_windows() then
        directory = directory:gsub("/", "\\")
        if directory:find('"', 1, true) then
            return {}
        end
        command = 'dir /b /ad "' .. directory .. '" 2>nul'
    else
        command = "ls -1 " .. shell_quote(directory) .. " 2>/dev/null"
    end
    local result = {}
    for _, line in ipairs(run_lines(command)) do
        if line ~= "." and line ~= ".." then
            result[#result + 1] = line
        end
    end
    return result
end

--- Returns the directory of the uv-managed interpreters. UV_PYTHON_INSTALL_DIR
--- wins; otherwise uv is asked, because its configuration may move the
--- directory; the platform default is the fallback.
local function uv_python_dir()
    local configured = env("UV_PYTHON_INSTALL_DIR")
    if configured and configured ~= "" then
        return configured
    end
    local lines = run_lines("uv python dir 2>" .. (is_windows() and "nul" or "/dev/null"))
    if lines[1] and lines[1] ~= "" then
        return lines[1]
    end
    if is_windows() then
        local appData = env_or("APPDATA", join(home_dir(), "AppData/Roaming"))
        return join(appData, "uv/python")
    end
    local xdgData = env("XDG_DATA_HOME")
    if xdgData and xdgData ~= "" then
        return join(xdgData, "uv/python")
    end
    return join(home_dir(), ".local/share/uv/python")
end

local function vfox_home()
    local pluginDirectory = (RUNTIME and RUNTIME.pluginDirPath) or ""
    local home = normalize(pluginDirectory):match("^(.*)/plugins/[^/]+$")
    if home and home ~= "" then
        return home
    end
    local configured = env("VFOX_HOME")
    if configured and configured ~= "" then
        return normalize(configured)
    end
    return normalize(join(home_dir(), ".vfox"))
end

--- Whether a prefix is a directory vfox itself manages. Such an installation
--- must never be reported: it is already a vfox version, and linking it would
--- make the version point at itself.
local function is_vfox_path(prefix)
    if normalize(prefix):find("/.vfox/", 1, true) then
        return true
    end
    local home = vfox_home()
    return home ~= "" and path_under(prefix, home)
end

local function is_root(prefix)
    local value = normalize(prefix)
    return value == "" or value == "/" or value:match("^%a:$") ~= nil
end

local function decode_hex(value)
    if type(value) ~= "string" or value == "" then
        return ""
    end
    return (value:gsub("%x%x", function(pair)
        return string.char(tonumber(pair, 16))
    end))
end

-- The interpreter reports UTF-8 paths as hex so a non-ASCII user name or
-- installation directory survives every console code page and pipe encoding.
-- The program is one line (exec with escaped newlines) because a Windows
-- argument must not carry a control character into windows_command.
local QUERY = 'exec("'
    .. table.concat({
        "import binascii, os, platform, sys",
        "def emit(name, value):",
        "    try:",
        "        value = value.encode('utf-8')",
        "    except (AttributeError, UnicodeDecodeError):",
        "        pass",
        "    print(name + '_HEX=' + binascii.hexlify(value).decode('ascii'))",
        "print('VERSION=' + platform.python_version())",
        "print('IMPLEMENTATION=' + platform.python_implementation())",
        "if platform.python_implementation() == 'GraalVM':",
        "    try:",
        "        import __graalpython__",
        "        print('GRAALPY_VERSION=' + str(__graalpython__.get_graalvm_version()))",
        "        print('GRAALPY_EDITION=' + ('community' if 'GraalVM CE' in sys.version else 'oracle'))",
        "    except Exception:",
        "        pass",
        "print('ABIFLAGS=' + getattr(sys, 'abiflags', ''))",
        "emit('PREFIX', sys.prefix)",
        "emit('BASE_PREFIX', getattr(sys, 'base_prefix', sys.prefix))",
        "executable = sys.executable or ''",
        "emit('EXECUTABLE', os.path.realpath(executable) if executable else '')",
    }, "\\n")
    .. '")'

--- Names a GraalPy installation the way the plugin installs it. 24.x keeps the
--- short graalpy-<release> form; 25.1 and later add the Python language
--- version, as in graalpy3.13-25.5.5. The community edition keeps its marker.
local function graalpy_version_name(release, pythonVersion, edition)
    local pythonMinor = pythonVersion and pythonVersion:match("^(%d+%.%d+)")
    local major, minor = release:match("^(%d+)%.(%d+)")
    major, minor = tonumber(major), tonumber(minor)

    local prefix = "graalpy"
    if pythonMinor and major and (major > 25 or (major == 25 and minor >= 1)) then
        prefix = prefix .. pythonMinor
    end
    if edition == "community" then
        prefix = prefix .. "-community"
    end
    return prefix .. "-" .. release
end

--- Asks one interpreter what it is. Returns nil for anything the plugin cannot
--- link: a broken Windows Store alias, a virtual environment, a PyPy build, or
--- a Python that vfox itself manages.
local function query(executable)
    local command
    if is_windows() then
        command = windowsCommand.native(executable, { "-E", "-s", "-c", QUERY })
    else
        command = shell_quote(executable) .. " -E -s -c " .. shell_quote(QUERY) .. " 2>/dev/null"
    end

    local fields = {}
    for _, line in ipairs(run_lines(command)) do
        local key, value = line:match("^([A-Z_]+)=(.*)$")
        if key then
            fields[key] = value
        end
    end

    if fields.VERSION == nil then
        return nil
    end

    local version
    if fields.IMPLEMENTATION == "CPython" then
        version = fields.VERSION:match("^(%d+%.%d+[%w%.]*)")
        if version == nil then
            return nil
        end
        version = version:gsub("%.$", "")
        if fields.ABIFLAGS and fields.ABIFLAGS:find("t", 1, true) and version:sub(-1) ~= "t" then
            version = version .. "t"
        end
    elseif fields.IMPLEMENTATION == "GraalVM" and fields.GRAALPY_VERSION then
        version = graalpy_version_name(fields.GRAALPY_VERSION, fields.VERSION, fields.GRAALPY_EDITION)
    else
        return nil
    end

    local prefix = decode_hex(fields.PREFIX_HEX)
    local basePrefix = decode_hex(fields.BASE_PREFIX_HEX)
    local resolved = decode_hex(fields.EXECUTABLE_HEX)
    if prefix == "" or resolved == "" or is_root(prefix) then
        return nil
    end
    -- A virtual environment is not an installation to adopt: its base Python
    -- is, and it is found on its own.
    if basePrefix ~= "" and normalize(prefix) ~= normalize(basePrefix) then
        return nil
    end
    if is_vfox_path(prefix) then
        return nil
    end

    return {
        version = version,
        prefix = prefix,
        executable = resolved,
    }
end

--- Names the source of an installation for its version suffix. The prefix's
--- location decides first; a hint from a known directory is the fallback for a
--- tool that keeps its Pythons somewhere custom.
local function source_for(prefix, hint)
    local value = normalize(prefix)
    if value:find("/uv/python", 1, true) then
        return "uv"
    elseif value:find("/.pyenv/versions/", 1, true) then
        return "pyenv"
    elseif value:find("/.asdf/installs/python/", 1, true) then
        return "asdf"
    elseif value:find("/mise/installs/python/", 1, true) then
        return "mise"
    elseif
        value:find("miniconda", 1, true)
        or value:find("anaconda", 1, true)
        or value:find("miniforge", 1, true)
        or value:find("mambaforge", 1, true)
        or value:find("/conda/", 1, true)
        or value:find("/conda", 1, true)
    then
        return "conda"
    elseif value:find("/nix/store/", 1, true) then
        return "nix"
    elseif
        value == "/opt/homebrew"
        or value:find("/opt/homebrew/", 1, true) == 1
        or value == "/home/linuxbrew/.linuxbrew"
        or value:find("/linuxbrew/", 1, true)
    then
        return "brew"
    elseif value:find("/library/frameworks/python.framework/", 1, true) then
        return "pythonorg"
    elseif value:find("/windowsapps/pythonsoftwarefoundation", 1, true) then
        return "store"
    elseif
        value:find("/programs/python/", 1, true)
        or value:find("/program files/python", 1, true)
        or value:find("/program files (x86)/python", 1, true)
        or value:match("^%a:/python%d")
    then
        return "pythonorg"
    elseif value:find("/snap/", 1, true) then
        return "snap"
    elseif value == "/usr/local" or value:find("/usr/local/", 1, true) == 1 then
        return "local"
    elseif value == "/usr" or value:find("/usr/", 1, true) == 1 then
        return "system"
    elseif value:find("/opt/", 1, true) == 1 then
        return "opt"
    end
    if hint then
        return hint
    end
    return "system"
end

local function add_executable(candidates, seen, executable, source)
    if type(executable) ~= "string" or executable == "" then
        return
    end
    local key = normalize(executable)
    if key == "" or seen[key] then
        return
    end
    seen[key] = true
    candidates[#candidates + 1] = { executable = executable, source = source }
end

local function executable_in(prefix)
    if is_windows() then
        local executable = join(prefix, "python.exe")
        if path_exists(executable) then
            return executable
        end
        return nil
    end
    local python3 = join(prefix, "bin/python3")
    if path_exists(python3) then
        return python3
    end
    local python = join(prefix, "bin/python")
    if path_exists(python) then
        return python
    end
    return nil
end

local function add_root(roots, path, source, kind, pattern)
    if path == nil or path == "" then
        return
    end
    roots[#roots + 1] = {
        path = path,
        source = source,
        kind = kind or "children",
        pattern = pattern,
    }
end

local function known_roots()
    local roots = {}
    local home = home_dir()

    add_root(roots, uv_python_dir(), "uv", "children")
    add_root(roots, join(env_or("PYENV_ROOT", join(home, ".pyenv")), "versions"), "pyenv", "children")
    add_root(roots, join(env_or("ASDF_DATA_DIR", join(home, ".asdf")), "installs/python"), "asdf", "children")
    -- Oracle's standalone GraalPy zips are commonly unpacked directly under
    -- the user's home directory.
    add_root(roots, home, "system", "children", "^graalpy[%w%.%-]*$")
    add_root(
        roots,
        join(env("MISE_DATA_DIR") or join(home, ".local/share/mise"), "installs/python"),
        "mise",
        "children"
    )

    -- CONDA_PREFIX is added separately: it is often unset, and a nil first
    -- element would make ipairs stop before any of the standard roots.
    add_root(roots, env("CONDA_PREFIX"), "conda", "prefix")
    local condaRoots = {
        join(home, "miniconda3"),
        join(home, "anaconda3"),
        join(home, "miniforge3"),
        join(home, "mambaforge"),
        "/opt/conda",
        "/opt/miniconda3",
        "/opt/miniforge3",
    }
    for _, root in ipairs(condaRoots) do
        add_root(roots, root, "conda", "prefix")
    end

    if is_windows() then
        local localAppData = env_or("LOCALAPPDATA", join(home, "AppData/Local"))
        local programFiles = env_or("ProgramFiles", "C:/Program Files")
        local programFilesX86 = env_or("ProgramFiles(x86)", "C:/Program Files (x86)")
        add_root(roots, join(localAppData, "Programs/Python"), "pythonorg", "children", "^Python%d")
        add_root(roots, programFiles, "pythonorg", "children", "^Python%d")
        add_root(roots, programFilesX86, "pythonorg", "children", "^Python%d")
        add_root(roots, "C:/", "pythonorg", "children", "^Python%d")
        add_root(roots, "C:/", "system", "children", "^graalpy")
        add_root(
            roots,
            join(localAppData, "Microsoft/WindowsApps"),
            "store",
            "children",
            "^PythonSoftwareFoundation%.Python%."
        )
        add_root(roots, join(home, "scoop/apps/python/current"), "scoop", "prefix")
    else
        add_root(roots, "/usr", "system", "prefix")
        add_root(roots, "/usr/local", "local", "prefix")
        add_root(roots, "/opt/python", "opt", "prefix")
        add_root(roots, "/opt", "opt", "children", "^graalpy")
        add_root(roots, "/opt/homebrew", "brew", "prefix")
        add_root(roots, "/home/linuxbrew/.linuxbrew", "brew", "prefix")
        if is_darwin() then
            add_root(roots, "/Library/Frameworks/Python.framework/Versions", "pythonorg", "children", "^%d+%.%d+$")
        end
    end

    return roots
end

local function path_candidates(candidates, seen)
    local value = env("PATH") or ""
    local separator = is_windows() and ";" or ":"
    local names = is_windows() and { "python.exe", "python3.exe" } or { "python3", "python" }
    for directory in value:gmatch("[^" .. separator .. "]+") do
        if directory ~= "" then
            for _, name in ipairs(names) do
                local executable = join(directory, name)
                if path_exists(executable) then
                    add_executable(candidates, seen, executable, nil)
                end
            end
        end
    end
end

--- The Windows py launcher knows every Python it can start, including the ones
--- whose directories are not on PATH. Its path list is one line per install.
local function py_launcher_candidates(candidates, seen)
    if not is_windows() then
        return
    end
    for _, line in ipairs(run_lines("py -0p 2>nul")) do
        local executable = line:match("([A-Za-z]:\\.*[Pp]ython%.exe)$")
        if executable then
            add_executable(candidates, seen, executable, nil)
        end
    end
end

local function collect_candidates()
    local candidates, seen = {}, {}
    for _, root in ipairs(known_roots()) do
        if root.kind == "prefix" then
            add_executable(candidates, seen, executable_in(root.path), root.source)
        else
            local ok, children = pcall(list_children, root.path)
            if ok then
                for _, child in ipairs(children) do
                    if root.pattern == nil or child:match(root.pattern) then
                        add_executable(candidates, seen, executable_in(join(root.path, child)), root.source)
                    end
                end
            end
        end
    end
    path_candidates(candidates, seen)
    py_launcher_candidates(candidates, seen)
    return candidates
end

--- Returns the installations to link, newest first. The caller reports them;
--- vfox drops a name that is already taken and links the rest.
function detect.find_all()
    local results, names = {}, {}
    for _, candidate in ipairs(collect_candidates()) do
        local ok, found = pcall(query, candidate.executable)
        if ok and found then
            local source = source_for(found.prefix, candidate.source)
            local name = python_version.name(found.version, source)
            if python_version.is_valid_name(name) and not names[name] then
                names[name] = true
                results[#results + 1] = {
                    version = name,
                    path = found.prefix,
                    note = notes[source] or "found on this machine",
                }
            end
        end
    end
    table.sort(results, function(left, right)
        local leftGraalPy = left.version:match("^graalpy") ~= nil
        local rightGraalPy = right.version:match("^graalpy") ~= nil
        if leftGraalPy ~= rightGraalPy then
            return not leftGraalPy
        end
        local order = python_version.compare(left.version, right.version)
        if order ~= 0 then
            return order > 0
        end
        return left.version > right.version
    end)
    return results
end

return detect
