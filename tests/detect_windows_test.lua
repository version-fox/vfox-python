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

-- Detect on Windows: python.org installers under Programs\Python and C:\,
-- the Microsoft Store package, uv, and the py launcher's list. vfox's own
-- installation and a Store alias that cannot run must stay out.
local test = require("vfox.test")

local localAppData = "C:\\Users\\Test\\AppData\\Local"
local appData = "C:\\Users\\Test\\AppData\\Roaming"
local uv = appData .. "\\uv\\python"
local store = localAppData .. "\\Microsoft\\WindowsApps"
local programs = localAppData .. "\\Programs\\Python"

local plugin = test.load({
    os = "windows",
    arch = "amd64",
    env = {
        USERPROFILE = "C:\\Users\\Test",
        LOCALAPPDATA = localAppData,
        APPDATA = appData,
        ProgramFiles = "C:\\Program Files",
        ["ProgramFiles(x86)"] = "C:\\Program Files (x86)",
        PATH = programs .. "\\Python311;C:\\Windows\\System32;C:\\Users\\Test\\.vfox\\sdks\\python\\v-3.12.9",
        VFOX_HOME = "C:\\Users\\Test\\.vfox",
        CONDA_PREFIX = false,
    },
})

local detect = require("detect_python")

local alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local decode = {}
for i = 1, #alphabet do
    decode[alphabet:sub(i, i)] = i - 1
end
local function decodeBase64(value)
    -- GopherLua's table.concat overflows its registry beyond a few thousand
    -- values, and the encoded PowerShell program is longer than that.
    local result = ""
    for i = 1, #value, 4 do
        local a, b, c, d = value:sub(i, i + 3):byte(1, 4)
        local x = decode[string.char(a)]
        local y = decode[string.char(b)]
        local z = c and c ~= 61 and decode[string.char(c)] or 0
        local w = d and d ~= 61 and decode[string.char(d)] or 0
        assert(x and y, "invalid base64")
        local number = x * 262144 + y * 4096 + z * 64 + w
        result = result .. string.char(math.floor(number / 65536) % 256)
        if c and c ~= 61 then
            result = result .. string.char(math.floor(number / 256) % 256)
        end
        if d and d ~= 61 then
            result = result .. string.char(number % 256)
        end
    end
    return result
end

local function decodeCommand(value)
    local payload = assert(
        value:match("^powershell %-NoProfile %-NonInteractive %-EncodedCommand ([A-Za-z0-9+/=]+)$"),
        "unexpected PowerShell command: " .. value
    )
    local utf16 = decodeBase64(payload)
    local bytes = {}
    for i = 1, #utf16, 2 do
        assert(utf16:byte(i) < 128 and utf16:byte(i + 1) == 0, "script must be ASCII UTF-16LE")
        bytes[#bytes + 1] = utf16:sub(i, i)
    end
    return table.concat(bytes)
end

local function programOf(command)
    local script = decodeCommand(command)
    for encoded in script:gmatch("FromBase64String%('([A-Za-z0-9+/=]*)'%)") do
        return decodeBase64(encoded)
    end
    return nil
end

local function hex(value)
    return (value:gsub(".", function(char)
        return string.format("%02x", string.byte(char))
    end))
end

local function output(version, prefix, executable, flags)
    return {
        "VERSION=" .. version,
        "IMPLEMENTATION=CPython",
        "ABIFLAGS=" .. (flags or ""),
        "PREFIX_HEX=" .. hex(prefix),
        "BASE_PREFIX_HEX=" .. hex(prefix),
        "EXECUTABLE_HEX=" .. hex(executable),
    }
end

local files = {}
local listings = {}
local outputs = {}

local function install(executable, version, prefix)
    files[executable] = true
    outputs[executable] = output(version, prefix, executable)
    return executable
end

install(programs .. "\\Python311\\python.exe", "3.11.9", programs .. "\\Python311")
install("C:\\Python312\\python.exe", "3.12.10", "C:\\Python312")
install(programs .. "\\Python310\\python.exe", "3.10.11", programs .. "\\Python310")
install(
    store .. "\\PythonSoftwareFoundation.Python.3.13_qbz5n2kfra8p0\\python.exe",
    "3.13.1",
    store .. "\\PythonSoftwareFoundation.Python.3.13_qbz5n2kfra8p0"
)
-- A Store app execution alias stays on disk after its package is removed; it
-- exists but cannot run, so it must be queried and then dropped.
files[store .. "\\PythonSoftwareFoundation.Python.3.9_qbz5n2kfra8p0\\python.exe"] = true
install(
    uv .. "\\cpython-3.12.8-windows-x86_64-none\\python.exe",
    "3.12.8",
    uv .. "\\cpython-3.12.8-windows-x86_64-none"
)
install(
    "C:\\Users\\Test\\.vfox\\sdks\\python\\v-3.12.9\\python.exe",
    "3.12.9",
    "C:\\Users\\Test\\.vfox\\sdks\\python\\v-3.12.9"
)

listings[programs] = { "Python311" }
listings["C:\\"] = { "Python312" }
listings[store] = {
    "PythonSoftwareFoundation.Python.3.13_qbz5n2kfra8p0",
    "PythonSoftwareFoundation.Python.3.9_qbz5n2kfra8p0",
}
listings[uv] = { "cpython-3.12.8-windows-x86_64-none" }
listings["C:\\Program Files"] = {}
listings["C:\\Program Files (x86)"] = {}

io.open = function(path, mode)
    if mode == "r" and files[path] then
        return {
            close = function()
                return true
            end,
        }
    end
    return nil
end

local function handle(lines)
    local index = 0
    return {
        read = function(_, format)
            assert(format == "*l", format)
            index = index + 1
            return lines[index]
        end,
        close = function()
            return 0
        end,
    }
end

io.popen = function(command, mode)
    local directory = command:match('^dir /b /ad "(.*)" 2>nul$')
    if directory then
        return handle(listings[directory] or {})
    end
    if command == "uv python dir 2>nul" then
        return handle({ uv })
    end
    if command == "py -0p 2>nul" then
        return handle({
            " -V:3.11 *        " .. programs .. "\\Python311\\python.exe",
            " -V:3.10 *        " .. programs .. "\\Python310\\python.exe",
        })
    end
    local program = programOf(command)
    if program then
        return handle(outputs[program] or {})
    end
    return handle({})
end

local found = plugin:Detect({})
assert(#found == 5, #found)
local by_version = {}
for _, item in ipairs(found) do
    by_version[item.version] = item
end

assert(by_version["3.11.9-pythonorg"].path == programs .. "\\Python311")
assert(by_version["3.10.11-pythonorg"].path == programs .. "\\Python310")
assert(by_version["3.12.10-pythonorg"].path == "C:\\Python312")
assert(by_version["3.13.1-store"].path == store .. "\\PythonSoftwareFoundation.Python.3.13_qbz5n2kfra8p0")
assert(by_version["3.12.8-uv"].path == uv .. "\\cpython-3.12.8-windows-x86_64-none")
assert(by_version["3.12.9-pythonorg"] == nil, "the vfox-managed Python must not be detected")
assert(by_version["3.9.5-store"] == nil, "a broken Store alias must not be detected")

print("PASS: Windows Detect sources, py launcher, vfox and broken alias filtering")
