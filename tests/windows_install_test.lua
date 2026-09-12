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
os.execute = function(command)
    state.commands[#state.commands + 1] = command
    -- Native paths must never be expanded as cmd variables or tokenized on spaces.
    assert(command:find('powershell ', 1, true), 'unquoted Windows command: ' .. command)
    assert(not command:find('%%') and not command:find('!'), 'cmd expansion in command: ' .. command)
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
assert(not pcall(windows.msi, 'C:\\bad"path\\python.msi', path), 'invalid Windows quote must fail')
assert(not pcall(windows.native, 'bad\nprogram', {}), 'control characters must fail')
os.execute, io.popen, io.open, io.close, os.remove = oldExecute, oldPopen, oldOpen, oldClose, oldRemove
print('Windows installer command paths and shell expansion regression passed')
