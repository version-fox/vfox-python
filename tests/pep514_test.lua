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

local test = require("vfox.test")

local state = { commands = {}, exitCode = 0 }
local oldExecute = os.execute

os.execute = function(command)
    state.commands[#state.commands + 1] = command
    assert(
        command:find("^powershell %-NoProfile %-NonInteractive %-EncodedCommand [A-Za-z0-9+/=]+$"),
        "PowerShell command must contain only an unquoted base64 payload: " .. command
    )
    assert(not command:find("%", 1, true) and not command:find("!", 1, true), "cmd expansion in command: " .. command)
    return state.exitCode
end

local plugin = test.load({
    os = "windows",
    arch = "amd64",
    env = {},
})

local pep514 = require("pep514")
local oldGetenv, oldPrint, oldOpen = os.getenv, print, io.open
local messages = {}

print = function(...)
    local parts = {}
    for i = 1, select("#", ...) do
        parts[#parts + 1] = tostring(select(i, ...))
    end
    messages[#messages + 1] = table.concat(parts, " ")
end

local function setRegisterEnv(value)
    os.getenv = function(name)
        if name == "VFOX_PYTHON_REGISTER_PY_LAUNCHER" then
            return value
        end
        return oldGetenv(name)
    end
end

local nestedExecutable = nil
io.open = function(path)
    if nestedExecutable ~= nil and path == nestedExecutable then
        return { close = function() end }
    end
    return nil
end

-- Decode the command independently so the test inspects what PowerShell will
-- execute, rather than only checking a command string prefix.
local alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

local function decodeBase64(value)
    local result, accumulator, bits = "", 0, 0
    for char in value:gmatch(".") do
        if char == "=" then
            break
        end
        local index = assert(alphabet:find(char, 1, true), "invalid base64") - 1
        accumulator = accumulator * 64 + index
        bits = bits + 6
        if bits >= 8 then
            bits = bits - 8
            local scale = 2 ^ bits
            result = result .. string.char(math.floor(accumulator / scale))
            accumulator = accumulator % scale
        end
    end
    return result
end

local function decodeCommand(value)
    local payload = assert(
        value:match("^powershell %-NoProfile %-NonInteractive %-EncodedCommand ([A-Za-z0-9+/=]+)$"),
        "PowerShell command must contain only an unquoted base64 payload: " .. value
    )
    local utf16 = decodeBase64(payload)
    assert(#utf16 % 2 == 0, "incomplete UTF-16LE code unit")
    local script = ""
    for i = 1, #utf16, 2 do
        assert(utf16:byte(i) < 128 and utf16:byte(i + 1) == 0, "script must use ASCII UTF-16LE")
        script = script .. utf16:sub(i, i)
    end
    assert(script:find("$ErrorActionPreference = 'Stop'; ", 1, true) == 1, "error preference must execute")
    assert(
        script:find("$ProgressPreference = 'SilentlyContinue'; ", 1, true),
        "PowerShell progress must not pollute installer output"
    )
    return script
end

local function literals(command)
    local script = decodeCommand(command)
    local result = {}
    for encoded in script:gmatch("FromBase64String%('([A-Za-z0-9+/=]*)'%)") do
        result[#result + 1] = decodeBase64(encoded)
    end
    return result, script
end

local function valueOf(values, name)
    for i = 1, #values do
        if values[i] == name then
            return values[i + 1]
        end
    end
end

local function anyMessageContains(text)
    for _, message in ipairs(messages) do
        if message:find(text, 1, true) then
            return true
        end
    end
    return false
end

local function reset()
    state.commands = {}
    state.exitCode = 0
    messages = {}
end

local path = "C:\\Users\\Mechael Jackson's & %USERNAME% !\\python-3.14.5"
local ctx = { rootPath = "C:\\vfox", sdkInfo = { python = { path = path, version = "3.14.5" } } }

setRegisterEnv(nil)
assert(pep514.enabled(), "registration must be on by default on Windows")
setRegisterEnv("")
assert(pep514.enabled(), "an empty registration setting must keep the default")
setRegisterEnv("1")
assert(pep514.enabled(), "truthy registration setting must enable registration")
setRegisterEnv("YES")
assert(pep514.enabled(), "case-insensitive registration setting must enable registration")
setRegisterEnv("0")
assert(pep514.enabled() == false, "falsey registration setting must not enable registration")
setRegisterEnv("false")
assert(pep514.enabled() == false, "falsey registration setting must not enable registration")
setRegisterEnv("no")
assert(pep514.enabled() == false, "falsey registration setting must not enable registration")
setRegisterEnv("off")
assert(pep514.enabled() == false, "falsey registration setting must not enable registration")

assert(pep514.tagFor("3.14.5", "amd64") == "3.14.5")
assert(pep514.tagFor("3.14.5", "386") == "3.14.5-32")
assert(pep514.tagFor("3.14.5", "arm64") == "3.14.5-arm64")
assert(pep514.tagFor("3.14.0a4t", "amd64") == "3.14.0a4t")
assert(pep514.tagFor("3.12.10+local", "amd64") == "3.12.10-local")
assert(pep514.registryKey("3.14.5", "amd64") == "HKCU:\\Software\\Python\\VersionFox\\3.14.5")

reset()
setRegisterEnv("1")
pep514.register(ctx)
assert(#state.commands == 1, "enabled registration must run one PowerShell command")
local values, script = literals(state.commands[1])
assert(values[1] == "Software\\Python\\VersionFox\\3.14.5", values[1])
assert(valueOf(values, "InstallPath") == path, valueOf(values, "InstallPath"))
assert(valueOf(values, "DisplayName") == "Python 3.14.5 (vfox)")
assert(valueOf(values, "SysVersion") == "3.14")
assert(valueOf(values, "SysArchitecture") == "64bit")
assert(valueOf(values, "ExecutablePath") == path .. "\\python.exe")
assert(valueOf(values, "WindowedExecutablePath") == path .. "\\pythonw.exe")
assert(valueOf(values, "VfoxManaged") == "1")
assert(script:find("CreateSubKey", 1, true), "registration must create the company/tag key")
assert(script:find("SetValue('',", 1, true), "registration must set the default InstallPath value")
assert(script:find("[Microsoft.Win32.RegistryValueKind]::String", 1, true), "registration values must be strings")
assert(not script:find("PythonCore", 1, true), "registration must not write PythonCore")

local nestedRoot = "C:\\vfox\\python-3.14.5"
local nestedPath = nestedRoot .. "\\python-3.14.5"
nestedExecutable = nestedPath .. "\\python.exe"
reset()
setRegisterEnv("1")
pep514.register({ sdkInfo = { python = { path = nestedRoot, version = "3.14.5" } } })
values = literals(state.commands[1])
assert(valueOf(values, "InstallPath") == nestedPath, "uv-build archives must use the nested Python prefix")
nestedExecutable = nil

local graalpyRoot = "C:\\vfox\\v-graalpy-community-24.2.0"
local graalpyPrefix = graalpyRoot .. "\\graalpy-community-24.2.0-windows-amd64"
nestedExecutable = graalpyPrefix .. "\\bin\\python.exe"
reset()
setRegisterEnv("1")
pep514.register({ sdkInfo = { python = { path = graalpyRoot, version = "graalpy-community-24.2.0" } } })
values = literals(state.commands[1])
assert(valueOf(values, "InstallPath") == graalpyPrefix, valueOf(values, "InstallPath"))
assert(valueOf(values, "DisplayName") == "GraalPy Community 24.2.0 (vfox)")
assert(valueOf(values, "SysVersion") == "3.11")
assert(valueOf(values, "ExecutablePath") == graalpyPrefix .. "\\bin\\python.exe")
assert(valueOf(values, "WindowedExecutablePath") == nil, "GraalPy has no pythonw.exe")
nestedExecutable = nil

reset()
setRegisterEnv(nil)
pep514.register(ctx)
assert(#state.commands == 1, "registration must run by default on Windows")

reset()
setRegisterEnv("0")
pep514.register(ctx)
assert(#state.commands == 0, "opt-out registration must not run PowerShell")

reset()
setRegisterEnv("1")
pep514.register({})
assert(#state.commands == 0, "missing SDK information must not run PowerShell")
assert(anyMessageContains("missing SDK information"), "missing SDK information must be reported")

reset()
RUNTIME.archType = "386"
setRegisterEnv("1")
pep514.register(ctx)
values = literals(state.commands[1])
assert(values[1] == "Software\\Python\\VersionFox\\3.14.5-32", values[1])
assert(valueOf(values, "SysArchitecture") == "32bit")
RUNTIME.archType = "amd64"

reset()
setRegisterEnv("1")
state.exitCode = 1
pep514.register(ctx)
assert(
    anyMessageContains("Warning: Could not register Python with the Python launcher"),
    "registration failure must be reported as a warning"
)

reset()
setRegisterEnv(nil)
pep514.unregister({ main = { name = "python", path = path, version = "3.14.5" } })
assert(#state.commands == 1, "uninstall must clean up the registration while registration is on")
values, script = literals(state.commands[1])
assert(values[1] == "Software\\Python\\VersionFox\\3.14.5", values[1])
assert(values[2] == path, values[2])
assert(script:find("OpenSubKey", 1, true), "cleanup must read the existing registration")
assert(script:find("OpenSubKey('InstallPath')", 1, true), "cleanup must read the PEP 514 InstallPath key")
assert(script:find("GetValue('VfoxManaged')", 1, true), "cleanup must check ownership")
assert(script:find("GetValue('')", 1, true), "cleanup must check the registered install path")
assert(script:find("DeleteSubKeyTree", 1, true), "cleanup must remove the owned registration")
assert(script:find("SubKeyCount", 1, true), "cleanup must remove an empty company key")
assert(not script:find("PythonCore", 1, true), "cleanup must not touch PythonCore")

reset()
setRegisterEnv("0")
pep514.unregister({ main = { name = "python", path = path, version = "3.14.5" } })
assert(#state.commands == 1, "uninstall must clean up an existing registration when registration is off")

reset()
RUNTIME.osType = "linux"
OS_TYPE = "linux"
setRegisterEnv("1")
pep514.register(ctx)
pep514.unregister({ main = { name = "python", path = path, version = "3.14.5" } })
assert(#state.commands == 0, "non-Windows platforms must not touch the registry")
RUNTIME.osType = "windows"
OS_TYPE = "windows"

local installed = false
windowsInstall = function()
    installed = true
end
uvBuildInstall = function()
    error("uv-build path must not run")
end
linuxCompile = function()
    error("linux path must not run")
end

reset()
setRegisterEnv("1")
plugin:PostInstall(ctx)
assert(installed, "PostInstall must run the Windows installer")
assert(#state.commands == 1, "PostInstall must register the installed version")

reset()
setRegisterEnv(nil)
plugin:PreUninstall({
    main = { name = "python", path = path, version = "3.14.5" },
    sdkInfo = { python = { name = "python", path = path, version = "3.14.5" } },
})
assert(#state.commands == 1, "PreUninstall must clean up the registration")

os.execute, os.getenv, io.open = oldExecute, oldGetenv, oldOpen
oldPrint("PASS: PEP 514 Python launcher registration")
