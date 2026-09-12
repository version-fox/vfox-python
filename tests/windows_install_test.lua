package.path = './lib/?.lua;' .. package.path
RUNTIME = {osType = 'windows', archType = 'amd64', pluginDirPath = "C:\\Plugin's & %USERNAME% ! store"}
OS_TYPE = 'windows'
local state = {commands = {}, closeCount = 0}
local function reset()
    for key in pairs(state) do state[key] = nil end
    state.commands = {}
    state.closeCount = 0
end
package.preload.http = function() return {download_file = function() return nil end} end
package.preload.html = function() return {} end
package.preload.json = function() return {} end
local oldExecute, oldPopen, oldOpen, oldClose, oldRemove = os.execute, io.popen, io.open, io.close, os.remove

-- Decode the command independently so the test inspects what PowerShell will
-- execute, rather than only checking a command string prefix.
local alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
local function decodeBase64(value)
    local result, accumulator, bits = {}, 0, 0
    for char in value:gmatch('.') do
        if char == '=' then break end
        local index = assert(alphabet:find(char, 1, true), 'invalid base64') - 1
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
    local payload = assert(value:match('^powershell %-NoProfile %-NonInteractive %-EncodedCommand ([A-Za-z0-9+/=]+)$'),
        'PowerShell command must contain only an unquoted base64 payload: ' .. value)
    local utf16 = decodeBase64(payload)
    assert(#utf16 % 2 == 0, 'incomplete UTF-16LE code unit')
    local bytes = {}
    for i = 1, #utf16, 2 do
        assert(utf16:byte(i) < 128 and utf16:byte(i + 1) == 0, 'script must use ASCII UTF-16LE')
        bytes[#bytes + 1] = utf16:sub(i, i)
    end
    local script = table.concat(bytes)
    assert(script:find("$ErrorActionPreference = 'Stop'; ", 1, true) == 1, 'error preference must execute')
    return script
end

os.execute = function(command)
    state.commands[#state.commands + 1] = command
    -- Native paths must never be expanded as cmd variables or tokenized on spaces.
    assert(command:find('powershell ', 1, true), 'unquoted Windows command: ' .. command)
    assert(not command:find('%%') and not command:find('!'), 'cmd expansion in command: ' .. command)
    decodeCommand(command)
    return #state.commands == state.failOn and 1 or 0
end
io.popen = function(command)
    local exitCode = os.execute(command)
    return {
        lines = function()
            local files, i = state.files or {'core.msi', 'stdlib.msi'}, 0
            return function()
                i = i + 1
                if state.readFailure and i == 2 then error('read failed') end
                return files[i]
            end
        end,
        close = function()
            state.closeCount = state.closeCount + 1
            if state.closeFailure then error('close failed') end
            -- GopherLua process pipes return a numeric exit status, including 0.
            return state.listExitCode or exitCode
        end,
    }
end
io.open = function()
    return {close = function() end}
end
io.close = function(file) return file:close() end
os.remove = function() return true end
require('util')
local path = "C:\\Users\\Mechael Jackson's & %USERNAME% !\\python-3.14.5"
windowsInstallExe(path, 'https://example.invalid/python.exe', '3.14.5', 'python.exe')
assert(#state.commands >= 7, 'installer, enumeration, MSI, pip and aliases must be exercised')
reset()
windowsInstallMsi(path, 'https://example.invalid/python.msi', '3.4.4', 'python.msi')
assert(#state.commands == 2, 'MSI and ensurepip must both run')
for _, failure in ipairs({{1, 'Extract failed'}, {3, 'Install msi failed'}, {6, 'executable alias'}}) do
    reset()
    state.failOn = failure[1]
    local ok, err = pcall(function()
        windowsInstallExe(path, 'https://example.invalid/python.exe', '3.14.5', 'python.exe')
    end)
    assert(not ok and tostring(err):find(failure[2], 1, true), tostring(err))
end
for _, failure in ipairs({
    {name = 'partial listing exits nonzero', files = {'core.msi'}, exitCode = 1, message = 'Failed to list installer packages'},
    {name = 'listing read failure', readFailure = true, message = 'read failed'},
    {name = 'listing close failure', closeFailure = true, message = 'close failed'},
    {name = 'no MSI packages', files = {'readme.txt'}, message = 'No installer MSI packages'},
}) do
    reset()
    state.files = failure.files
    state.listExitCode = failure.exitCode
    state.readFailure = failure.readFailure
    state.closeFailure = failure.closeFailure
    local ok, err = pcall(windowsInstallExe, path, 'https://example.invalid/python.exe', '3.14.5', 'python.exe')
    assert(not ok and tostring(err):find(failure.message, 1, true), failure.name .. ': ' .. tostring(err))
    assert(state.closeCount == 1, failure.name .. ': listing handle must be closed')
    assert(#state.commands == 2, failure.name .. ': no MSI or pip may run before enumeration succeeds')
end
local windows = require('windows_command')
for _, value in ipairs({'', 'f', 'fo', 'foo', 'foob', 'fooba', 'foobar', "C:\\用户\\Mechael's & %USERNAME% !\\", 'quotes"stay data'}) do
    local script = decodeCommand(windows.native('program.exe', {value}))
    local arguments = {}
    for encoded in script:gmatch("FromBase64String%('([A-Za-z0-9+/=]*)'%)") do
        arguments[#arguments + 1] = decodeBase64(encoded)
    end
    assert(#arguments == 2 and arguments[1] == 'program.exe' and arguments[2] == value,
        'native argument changed after payload decoding')
    assert(script:find('; exit $LASTEXITCODE', 1, true), 'native exit status must propagate')
end
local msi = decodeCommand(windows.msi('C:\\MSI files\\core.msi', path))
assert(msi:find('Start-Process -FilePath msiexec.exe -Wait -PassThru', 1, true))
assert(msi:find('; exit $process.ExitCode', 1, true))
assert(not pcall(windows.msi, 'C:\\bad"path\\python.msi', path), 'invalid Windows quote must fail')
assert(not pcall(windows.native, 'bad\nprogram', {}), 'control characters must fail')
os.execute, io.popen, io.open, io.close, os.remove = oldExecute, oldPopen, oldOpen, oldClose, oldRemove
print('Windows installer command paths and shell expansion regression passed')
