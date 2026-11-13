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
require("util")

local REGISTRY_ROOT = "Software\\Python\\VersionFox"
local REGISTER_ENV = "VFOX_PYTHON_REGISTER_PY_LAUNCHER"

local function commandSucceeded(status)
    return status == 0 or status == true
end

local function isWindows()
    return string.lower(RUNTIME.osType or OS_TYPE or "") == "windows"
end

-- Registration is on by default on Windows. Setting
-- VFOX_PYTHON_REGISTER_PY_LAUNCHER=0/false/no/off disables it.
local function registrationEnabled(name)
    local value = os.getenv(name)
    if value == nil or value == "" then
        return true
    end
    value = string.lower(value)
    return value ~= "0" and value ~= "false" and value ~= "no" and value ~= "off"
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
-- into it. GraalPy keeps python.exe under bin in its extracted archive. All
-- layouts must point the launcher at the directory that contains the interpreter.
local function installPrefix(path, version)
    if fileExists(path .. "\\python.exe") then
        return path
    end
    local nestedPath = path .. "\\python-" .. version
    if fileExists(nestedPath .. "\\python.exe") then
        return nestedPath
    end
    if isGraalPyVersion(version) then
        local graalPyPath = resolvePythonInstallPath(path, version)
        if fileExists(graalPyPath .. "\\bin\\python.exe") then
            return graalPyPath
        end
    end
    return path
end

local function displayName(version)
    local parsed = parseGraalPyVersion(version)
    if parsed then
        local name = parsed.community and "GraalPy Community" or "GraalPy"
        return name .. " " .. parsed.release .. " (vfox)"
    end
    return "Python " .. version .. " (vfox)"
end

local function executablePath(path, version)
    if isGraalPyVersion(version) then
        return path .. "\\bin\\python.exe"
    end
    return path .. "\\python.exe"
end

-- GraalPy release names track the GraalVM release, not the Python language
-- version. PEP 514 SysVersion has to be the latter.
local function graalPySysVersion(version)
    local parsed = parseGraalPyVersion(version)
    if parsed == nil then
        return nil
    end
    if parsed.pythonMinor then
        return parsed.pythonMinor
    end
    local major = tonumber(parsed.release:match("^(%d+)"))
    if major == 25 or major == 24 then
        return "3.11"
    elseif major == 23 then
        return "3.10"
    end
    return nil
end

local function registrySubkey(version, archType)
    return REGISTRY_ROOT .. "\\" .. tagFor(version, archType)
end

local function registryValues(version, path)
    local tagValues = {
        { name = "DisplayName", value = displayName(version) },
        {
            name = "SysVersion",
            value = (isGraalPyVersion(version) and graalPySysVersion(version)) or sysVersion(version),
        },
        { name = "SysArchitecture", value = sysArchitecture(RUNTIME.archType) },
        { name = "VfoxManaged", value = "1" },
    }
    local installValues = {
        { name = "ExecutablePath", value = executablePath(path, version) },
    }
    -- GraalPy has no pythonw.exe; PEP 514 treats the value as optional.
    if not isGraalPyVersion(version) then
        installValues[#installValues + 1] = { name = "WindowedExecutablePath", value = path .. "\\pythonw.exe" }
    end
    return tagValues, installValues
end

local pep514 = {}

function pep514.enabled()
    return registrationEnabled(REGISTER_ENV)
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
    local tagValues, installValues = registryValues(version, path)
    local ok, result = pcall(function()
        return os.execute(windowsCommand.registrySet(subkey, path, tagValues, installValues))
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
