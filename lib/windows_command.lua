local command = {}

-- os.execute/io.popen pass through cmd.exe before PowerShell. Do not expose
-- percent expansion, delayed expansion, or quotes to that outer parser.
local function literal(value)
    if value:find('[\r\n%z]') then
        error('Windows command argument contains a control character')
    end
    value = value:gsub("'", "''")
    value = value:gsub('[%%!\"]', function(char)
        return "' + [char]" .. string.byte(char) .. " + '"
    end)
    return "('" .. value .. "')"
end

local function powershell(script)
    return 'powershell -NoProfile -NonInteractive -Command "' ..
        "$ErrorActionPreference = 'Stop'; " .. script .. '"'
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
    local args = '/quiet /a ' .. argument(file) .. ' ' .. argument('TargetDir=' .. path)
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
