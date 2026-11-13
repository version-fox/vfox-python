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

package.path = "./lib/?.lua;" .. package.path
RUNTIME = { osType = "windows", archType = "amd64", pluginDirPath = "C:\\Plugin's & %USERNAME% ! store" }
OS_TYPE = "windows"
local state = { commands = {}, closeCount = 0 }
-- Answers for the installer HEAD requests, keyed by URL; other URLs are 404.
local heads = {}
local function reset()
    for key in pairs(state) do
        state[key] = nil
    end
    state.commands = {}
    state.closeCount = 0
end
package.preload.http = function()
    return {
        download_file = function()
            return nil
        end,
        head = function(request)
            return { status_code = heads[request.url] or 404 }, nil
        end,
    }
end
package.preload.html = function()
    return {}
end
package.preload.json = function()
    return {}
end
local oldExecute, oldPopen, oldOpen, oldClose, oldRemove = os.execute, io.popen, io.open, io.close, os.remove

-- Decode the command independently so the test inspects what PowerShell will
-- execute, rather than only checking a command string prefix.
local alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local function decodeBase64(value)
    local result, accumulator, bits = {}, 0, 0
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
            result[#result + 1] = string.char(math.floor(accumulator / scale))
            accumulator = accumulator % scale
        end
    end
    return table.concat(result)
end
local function decodeCommand(value)
    local payload = assert(
        value:match("^powershell %-NoProfile %-NonInteractive %-EncodedCommand ([A-Za-z0-9+/=]+)$"),
        "PowerShell command must contain only an unquoted base64 payload: " .. value
    )
    local utf16 = decodeBase64(payload)
    assert(#utf16 % 2 == 0, "incomplete UTF-16LE code unit")
    local bytes = {}
    for i = 1, #utf16, 2 do
        assert(utf16:byte(i) < 128 and utf16:byte(i + 1) == 0, "script must use ASCII UTF-16LE")
        bytes[#bytes + 1] = utf16:sub(i, i)
    end
    local script = table.concat(bytes)
    assert(script:find("$ErrorActionPreference = 'Stop'; ", 1, true) == 1, "error preference must execute")
    assert(
        script:find("$ProgressPreference = 'SilentlyContinue'; ", 1, true),
        "PowerShell progress must not pollute installer output"
    )
    return script
end

-- Returns the destination of every Copy-Item command, in the order they ran.
local function copyTargets()
    local targets = {}
    for _, command in ipairs(state.commands) do
        local script = decodeCommand(command)
        if script:find("Copy-Item", 1, true) then
            local values = {}
            for encoded in script:gmatch("FromBase64String%('([A-Za-z0-9+/=]*)'%)") do
                values[#values + 1] = decodeBase64(encoded)
            end
            targets[#targets + 1] = values[2]
        end
    end
    return targets
end
local function contains(list, value)
    for _, item in ipairs(list) do
        if item == value then
            return true
        end
    end
    return false
end
os.execute = function(command)
    state.commands[#state.commands + 1] = command
    -- Native paths must never be expanded as cmd variables or tokenized on spaces.
    assert(command:find("powershell ", 1, true), "unquoted Windows command: " .. command)
    assert(not command:find("%%") and not command:find("!"), "cmd expansion in command: " .. command)
    decodeCommand(command)
    return #state.commands == state.failOn and 1 or 0
end
io.popen = function(command)
    local exitCode = os.execute(command)
    local files, i = state.files or { "core.msi", "stdlib.msi" }, 0
    return {
        -- vfox 1.1.0's Windows handle exposes read, not lines.
        read = function(_, format)
            assert(format == "*l", format)
            i = i + 1
            if state.readFailure and i == 2 then
                error("read failed")
            end
            return files[i]
        end,
        close = function()
            state.closeCount = state.closeCount + 1
            if state.closeFailure then
                error("close failed")
            end
            -- GopherLua process pipes return a numeric exit status, including 0.
            return state.listExitCode or exitCode
        end,
    }
end
io.open = function()
    return { close = function() end }
end
io.close = function(file)
    return file:close()
end
os.remove = function()
    return true
end
require("util")
local path = "C:\\Users\\Mechael Jackson's & %USERNAME% !\\python-3.14.5"
windowsInstallExe(path, "https://example.invalid/python.exe", "3.14.5", "python.exe")
assert(#state.commands >= 7, "installer, enumeration, MSI, pip and aliases must be exercised")
reset()
windowsInstallMsi(path, "https://example.invalid/python.msi", "3.4.4", "python.msi")
-- The MSI, ensurepip, six python aliases and six venv launcher aliases.
assert(#state.commands == 14, "MSI, pip and every alias must run: " .. #state.commands)
local msiTargets = copyTargets()
for _, name in ipairs({
    "python3.exe",
    "python34.exe",
    "python3.4.exe",
    "pythonw3.exe",
    "pythonw34.exe",
    "pythonw3.4.exe",
}) do
    assert(contains(msiTargets, path .. "\\" .. name), "MSI install must create " .. name)
end
reset()
state.failOn = 3
local msiOk, msiErr = pcall(windowsInstallMsi, path, "https://example.invalid/python.msi", "3.4.4", "python.msi")
assert(not msiOk and tostring(msiErr):find("Failed to create Python executable alias", 1, true), tostring(msiErr))
for _, failure in ipairs({ { 1, "Extract failed" }, { 3, "Install msi failed" }, { 6, "executable alias" } }) do
    reset()
    state.failOn = failure[1]
    local ok, err = pcall(function()
        windowsInstallExe(path, "https://example.invalid/python.exe", "3.14.5", "python.exe")
    end)
    assert(not ok and tostring(err):find(failure[2], 1, true), tostring(err))
end
for _, failure in ipairs({
    {
        name = "partial listing exits nonzero",
        files = { "core.msi" },
        exitCode = 1,
        message = "Failed to list installer packages",
    },
    { name = "listing read failure", readFailure = true, message = "read failed" },
    { name = "listing close failure", closeFailure = true, message = "close failed" },
    { name = "no MSI packages", files = { "readme.txt" }, message = "No installer MSI packages" },
}) do
    reset()
    state.files = failure.files
    state.listExitCode = failure.exitCode
    state.readFailure = failure.readFailure
    state.closeFailure = failure.closeFailure
    local ok, err = pcall(windowsInstallExe, path, "https://example.invalid/python.exe", "3.14.5", "python.exe")
    assert(not ok and tostring(err):find(failure.message, 1, true), failure.name .. ": " .. tostring(err))
    assert(state.closeCount == 1, failure.name .. ": listing handle must be closed")
    assert(#state.commands == 2, failure.name .. ": no MSI or pip may run before enumeration succeeds")
end
-- Installer selection: python.org's EXE wins when it publishes one for the
-- architecture, the MSI is the fallback, and a release with neither fails.
local base = "https://www.python.org/ftp/python/"
-- Replaces the URLs that answer 200. The table is mutated rather than
-- reassigned: the preload's closure keeps the table it first captured.
local function setHeads(urls)
    for url in pairs(heads) do
        heads[url] = nil
    end
    for _, url in ipairs(urls) do
        heads[url] = 200
    end
end

local function selectInstaller(version, arch, published)
    setHeads(published)
    RUNTIME.archType = arch
    local ok, result = pcall(getReleaseForWindows, version)
    RUNTIME.archType = "amd64"
    if ok then
        return result
    end
    return nil, tostring(result)
end
assert(
    selectInstaller(
        "3.12.2",
        "amd64",
        { base .. "3.12.2/python-3.12.2-amd64.exe", base .. "3.12.2/python-3.12.2.amd64.msi" }
    ) == base .. "3.12.2/python-3.12.2-amd64.exe",
    "EXE must win over MSI"
)
assert(
    selectInstaller("3.4.4", "amd64", { base .. "3.4.4/python-3.4.4.amd64.msi" })
        == base .. "3.4.4/python-3.4.4.amd64.msi",
    "MSI must be the fallback"
)
assert(
    selectInstaller("3.12.2", "arm64", { base .. "3.12.2/python-3.12.2-arm64.exe" })
        == base .. "3.12.2/python-3.12.2-arm64.exe"
)
assert(
    selectInstaller("3.12.2", "arm64", { base .. "3.12.2/python-3.12.2.arm64.msi" })
        == base .. "3.12.2/python-3.12.2.arm64.msi"
)
assert(selectInstaller("3.12.2", "386", { base .. "3.12.2/python-3.12.2.exe" }) == base .. "3.12.2/python-3.12.2.exe")
assert(selectInstaller("3.12.2", "386", { base .. "3.12.2/python-3.12.2.msi" }) == base .. "3.12.2/python-3.12.2.msi")
local missing, missingErr = selectInstaller("3.12.2", "amd64", {})
assert(missing == nil and tostring(missingErr):find("No available installer found", 1, true), tostring(missingErr))

-- The dispatcher takes the same route: an MSI-only release runs the MSI path.
reset()
setHeads({ base .. "3.4.4/python-3.4.4.amd64.msi" })
windowsInstall({ sdkInfo = { python = { path = path, version = "3.4.4" } } })
assert(#state.commands == 14, "the MSI route must run the MSI, pip and every alias: " .. #state.commands)
setHeads({})

local windows = require("windows_command")
for _, value in ipairs({
    "",
    "f",
    "fo",
    "foo",
    "foob",
    "fooba",
    "foobar",
    "C:\\用户\\Mechael's & %USERNAME% !\\",
    'quotes"stay data',
}) do
    local script = decodeCommand(windows.native("program.exe", { value }))
    local arguments = {}
    for encoded in script:gmatch("FromBase64String%('([A-Za-z0-9+/=]*)'%)") do
        arguments[#arguments + 1] = decodeBase64(encoded)
    end
    assert(
        #arguments == 2 and arguments[1] == "program.exe" and arguments[2] == value,
        "native argument changed after payload decoding"
    )
    assert(script:find("; exit $LASTEXITCODE", 1, true), "native exit status must propagate")
end
for _, case in ipairs({
    {
        file = "C:\\MSI files\\core.msi",
        path = "C:\\User files\\Python",
        expected = '/quiet /a "C:\\MSI files\\core.msi" TargetDir="C:\\User files\\Python"',
    },
    {
        file = "C:\\MSI files & %TEMP% !\\stdlib.msi",
        path = "C:\\User's & !\\Python files\\",
        expected = '/quiet /a "C:\\MSI files & %TEMP% !\\stdlib.msi" TargetDir="C:\\User\'s & !\\Python files\\\\"',
    },
}) do
    local msi = decodeCommand(windows.msi(case.file, case.path))
    assert(msi:find("Start-Process -FilePath msiexec.exe -Wait -PassThru", 1, true))
    assert(msi:find("; exit $process.ExitCode", 1, true))
    local encoded = assert(msi:match("FromBase64String%('([A-Za-z0-9+/=]*)'%)"))
    local arguments = decodeBase64(encoded)
    assert(arguments == case.expected, "MSI arguments changed: " .. arguments)
    assert(not msi:find("Junction", 1, true), "ordinary paths must not need a junction")
end
local junction = decodeCommand(windows.msi("C:\\MSI %SOURCE% files\\core.msi", path))
local values = {}
for encoded in junction:gmatch("FromBase64String%('([A-Za-z0-9+/=]*)'%)") do
    values[#values + 1] = decodeBase64(encoded)
end
assert(values[1] == path, "junction target must retain the literal percent path")
assert(values[2] == '/quiet /a "C:\\MSI %SOURCE% files\\core.msi" TargetDir=', "MSI source must remain unchanged")
assert(junction:find("New-Item -ItemType Junction", 1, true), "percent paths need a temporary junction")
assert(junction:find("[IO.Path]::GetTempPath()", 1, true), "junction must be outside the SDK directory")
assert(junction:find("$temp.Contains('%')", 1, true), "a percent-containing TEMP must fail safely")
assert(junction:find("[Guid]::NewGuid()", 1, true), "junction name must be unique")
assert(junction:find("[IO.Directory]::Exists($target)", 1, true), "junction target must already exist")
assert(junction:find("+ [char]34 + $alias + [char]34", 1, true), "MSI TargetDir must use the quoted alias")
assert(
    junction:find("finally", 1, true) and junction:find("[IO.Directory]::Delete($alias)", 1, true),
    "junction must be cleaned without deleting the SDK"
)
assert(
    not junction:find("-Recurse", 1, true) and not junction:find("Remove-Item", 1, true),
    "cleanup must not recurse into the junction target"
)
assert(
    junction:find("-Wait -PassThru", 1, true) and junction:find("$exitCode = $process.ExitCode", 1, true),
    "MSI exit code must be preserved"
)
assert(junction:find("; exit $exitCode", 1, true), "cleanup must precede the MSI exit")
assert(not pcall(windows.msi, 'C:\\bad"path\\python.msi', path), "invalid Windows quote must fail")
assert(not pcall(windows.native, "bad\nprogram", {}), "control characters must fail")
os.execute, io.popen, io.open, io.close, os.remove = oldExecute, oldPopen, oldOpen, oldClose, oldRemove
print("Windows installer command paths and shell expansion regression passed")
