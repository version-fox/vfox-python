local command = {}

local alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
local function base64(value)
    local result = {}
    for i = 1, #value, 3 do
        local a, b, c = value:byte(i, i + 2)
        local number = a * 65536 + (b or 0) * 256 + (c or 0)
        local first = math.floor(number / 262144) + 1
        local second = math.floor(number / 4096) % 64 + 1
        local third = math.floor(number / 64) % 64 + 1
        local fourth = number % 64 + 1
        result[#result + 1] = alphabet:sub(first, first) .. alphabet:sub(second, second) ..
            (b and alphabet:sub(third, third) or '=') ..
            (c and alphabet:sub(fourth, fourth) or '=')
    end
    return table.concat(result)
end

-- Encode UTF-8 values separately so even non-ASCII paths produce an ASCII
-- PowerShell script, without exposing arguments to either shell's parser.
local function literal(value)
    if value:find('[\r\n%z]') then
        error('Windows command argument contains a control character')
    end
    return "([Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('" .. base64(value) .. "')))"
end

local function powershell(script)
    script = "$ErrorActionPreference = 'Stop'; " .. script
    -- GopherLua launches cmd.exe /c, which reinterprets a quoted -Command.
    -- -EncodedCommand takes UTF-16LE base64 with no quotes or metacharacters.
    local utf16 = script:gsub('.', function(char)
        assert(char:byte() < 128, 'PowerShell script must contain only ASCII')
        return char .. '\0'
    end)
    return 'powershell -NoProfile -NonInteractive -EncodedCommand ' .. base64(utf16)
end

function command.native(program, args)
    local parts = {'&', literal(program)}
    for _, arg in ipairs(args) do
        table.insert(parts, literal(arg))
    end
    return powershell(table.concat(parts, ' ') .. '; exit $LASTEXITCODE')
end

function command.msi(file, path)
    local function argument(value)
        if value:find('"', 1, true) then
            error('Windows installer path contains an invalid quote')
        end
        -- A backslash immediately before the closing native quote is escaped.
        return '"' .. value:gsub('(\\+)$', '%1%1') .. '"'
    end
    local args = '/quiet /a ' .. argument(file) .. ' TargetDir=' .. argument(path)
    return powershell("$process = Start-Process -FilePath msiexec.exe -Wait -PassThru -ArgumentList " ..
        literal(args) .. '; exit $process.ExitCode')
end

function command.files(path)
    return powershell('Get-ChildItem -LiteralPath ' .. literal(path) ..
        " -Filter '*.msi' -File | ForEach-Object { $_.Name }")
end

function command.copy(source, target)
    return powershell('Copy-Item -LiteralPath ' .. literal(source) ..
        ' -Destination ' .. literal(target) .. ' -Force')
end

return command
