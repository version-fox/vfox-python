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

local windowsCommand = require("windows_command")

local REGISTRY_ROOT = "Software\\Python\\VersionFox"
local REGISTER_ENV = "VFOX_PYTHON_REGISTER_PY_LAUNCHER"

local function commandSucceeded(status)
    return status == 0 or status == true
end

local function isWindows()
    return string.lower(RUNTIME.osType or OS_TYPE or "") == "windows"
end

local function envEnabled(name)
    local value = os.getenv(name)
    if value == nil then
        return false
    end
    value = string.lower(value)
    return value == "1" or value == "true" or value == "yes" or value == "on"
end

local function architectureSuffix(archType)
    local arch = string.lower(archType or "")
    if arch == "386" or arch == "i386" or arch == "x86" then
        return "-32"
    elseif arch == "arm64" or arch == "aarch64" then
        return "-arm64"
    end
    return ""
end

local function tagFor(version, archType)
    -- PEP 514 tags are alphanumeric; keep dots and hyphens for readable versions.
    local tag = string.gsub(version, "[^%w%.%-]", "-")
    return tag .. architectureSuffix(archType)
end

local function sysVersion(version)
    return string.match(version, "^(%d+%.%d+)") or version
end

local function sysArchitecture(archType)
    local arch = string.lower(archType or "")
    if arch == "386" or arch == "i386" or arch == "x86" then
        return "32bit"
    end
    return "64bit"
end

local function fileExists(path)
    local file = io.open(path, "r")
    if file then
        file:close()
        return true
    end
    return false
end

-- uv-build archives unpack below the SDK directory; the MSI installs directly
-- into it. Both layouts must point the launcher at the directory with python.exe.
local function installPrefix(path, version)
    if fileExists(path .. "\\python.exe") then
        return path
    end
    local nestedPath = path .. "\\python-" .. version
    if fileExists(nestedPath .. "\\python.exe") then
        return nestedPath
    end
    return path
end

local function registrySubkey(version, archType)
    return REGISTRY_ROOT .. "\\" .. tagFor(version, archType)
end

local function registryValues(version, path)
    return {
        { name = "DisplayName", value = "Python " .. version .. " (vfox)" },
        { name = "SysVersion", value = sysVersion(version) },
        { name = "SysArchitecture", value = sysArchitecture(RUNTIME.archType) },
        { name = "ExecutablePath", value = path .. "\\python.exe" },
        { name = "WindowedExecutablePath", value = path .. "\\pythonw.exe" },
        { name = "VfoxManaged", value = "1" },
    }
end

local pep514 = {}

function pep514.enabled()
    return envEnabled(REGISTER_ENV)
end

function pep514.tagFor(version, archType)
    return tagFor(version, archType)
end

function pep514.registryKey(version, archType)
    return "HKCU:\\" .. registrySubkey(version, archType)
end

function pep514.register(ctx)
    if not isWindows() then
        return
    end
    if not pep514.enabled() then
        return
    end

    local sdkInfo = ctx.sdkInfo and ctx.sdkInfo["python"]
    if not sdkInfo or not sdkInfo.path or not sdkInfo.version then
        print("Warning: Cannot register Python with the Python launcher: missing SDK information")
        return
    end

    local version = sdkInfo.version
    local path = installPrefix(sdkInfo.path, version)
    local subkey = registrySubkey(version, RUNTIME.archType)

    print("Registering Python " .. version .. " with the Python launcher...")
    local ok, result = pcall(function()
        return os.execute(windowsCommand.registrySet(subkey, path, registryValues(version, path)))
    end)
    if not ok then
        print("Warning: Could not register Python with the Python launcher: " .. tostring(result))
    elseif not commandSucceeded(result) then
        print("Warning: Could not register Python with the Python launcher")
    end
end

function pep514.unregister(ctx)
    if not isWindows() then
        return
    end

    local main = ctx.main or (ctx.sdkInfo and ctx.sdkInfo["python"])
    if not main or not main.path or not main.version then
        return
    end

    local path = installPrefix(main.path, main.version)
    local subkey = registrySubkey(main.version, RUNTIME.archType)

    local ok, result = pcall(function()
        return os.execute(windowsCommand.registryDeleteIfOwned(subkey, path))
    end)
    if not ok then
        print("Warning: Could not remove the Python launcher registration: " .. tostring(result))
    elseif not commandSucceeded(result) then
        print("Warning: Could not remove the Python launcher registration")
    end
end

return pep514
