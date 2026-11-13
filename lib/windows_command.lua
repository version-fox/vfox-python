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

local command = {}

local alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local function base64(value)
    local result = {}
    for i = 1, #value, 3 do
        local a, b, c = value:byte(i, i + 2)
        local number = a * 65536 + (b or 0) * 256 + (c or 0)
        local first = math.floor(number / 262144) + 1
        local second = math.floor(number / 4096) % 64 + 1
        local third = math.floor(number / 64) % 64 + 1
        local fourth = number % 64 + 1
        result[#result + 1] = alphabet:sub(first, first)
            .. alphabet:sub(second, second)
            .. (b and alphabet:sub(third, third) or "=")
            .. (c and alphabet:sub(fourth, fourth) or "=")
    end
    return table.concat(result)
end

-- Encode UTF-8 values separately so even non-ASCII paths produce an ASCII
-- PowerShell script, without exposing arguments to either shell's parser.
local function literal(value)
    if value:find("[\r\n%z]") then
        error("Windows command argument contains a control character")
    end
    return "([Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('" .. base64(value) .. "')))"
end

local function powershell(script)
    script = "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue'; " .. script
    -- GopherLua launches cmd.exe /c, which reinterprets a quoted -Command.
    -- -EncodedCommand takes UTF-16LE base64 with no quotes or metacharacters.
    local utf16 = script:gsub(".", function(char)
        assert(char:byte() < 128, "PowerShell script must contain only ASCII")
        return char .. "\0"
    end)
    return "powershell -NoProfile -NonInteractive -EncodedCommand " .. base64(utf16)
end

function command.native(program, args)
    local parts = { "&", literal(program) }
    for _, arg in ipairs(args) do
        table.insert(parts, literal(arg))
    end
    return powershell(table.concat(parts, " ") .. "; exit $LASTEXITCODE")
end

--- Runs a Python interpreter with its output written to files, prints that
--- output, and exits with the interpreter's exit code. A failing ensurepip on
--- an old CPython release printed nothing through the PowerShell host, so a
--- failure also prints what the start and the install root looked like.
function command.pythonLogged(program, args)
    local arguments = {}
    for _, arg in ipairs(args) do
        table.insert(arguments, literal(arg))
    end
    local script = "$program = "
        .. literal(program)
        .. "; $arguments = @("
        .. table.concat(arguments, ", ")
        .. [[);
$root = Split-Path -Parent $program;
$out = [IO.Path]::GetTempFileName();
$err = [IO.Path]::GetTempFileName();
$exitCode = 1;
try {
    $process = Start-Process -FilePath $program -ArgumentList $arguments -NoNewWindow -Wait -PassThru -RedirectStandardOutput $out -RedirectStandardError $err;
    $exitCode = $process.ExitCode;
} catch {
    Write-Output ('Could not start the interpreter: ' + $_.Exception.Message);
} finally {
    Get-Content -LiteralPath $out | ForEach-Object { Write-Output $_ };
    Get-Content -LiteralPath $err | ForEach-Object { Write-Output $_ };
    Remove-Item -LiteralPath $out, $err -Force -ErrorAction SilentlyContinue;
    if ($exitCode -ne 0) {
        Write-Output ('Interpreter exit code: ' + $exitCode);
        Write-Output ('Interpreter present: ' + (Test-Path -LiteralPath $program));
        if (Test-Path -LiteralPath $root) {
            Get-ChildItem -LiteralPath $root -File | Where-Object { $_.Extension -in '.exe', '.dll' } | ForEach-Object { Write-Output ('  ' + $_.Name) };
        }
    }
}; exit $exitCode]]
    return powershell(script)
end

function command.msi(file, path)
    local function argument(value)
        if value:find('"', 1, true) then
            error("Windows installer path contains an invalid quote")
        end
        -- A backslash immediately before the closing native quote is escaped.
        return '"' .. value:gsub("(\\+)$", "%1%1") .. '"'
    end
    local args = "/quiet /a " .. argument(file) .. " TargetDir=" .. argument(path)
    if path:find("%", 1, true) then
        -- Windows Installer expands percent variables during FileCopy even
        -- when TARGETDIR contains the literal path. Install through a temporary
        -- junction, keeping the real SDK directory in its final location.
        local script = "$target = "
            .. literal(path)
            .. [[;
$temp = [IO.Path]::GetTempPath();
if ($temp.Contains('%')) {
    throw 'Python MSI installation requires a TEMP directory without percent signs';
}
if (-not [IO.Directory]::Exists($target)) {
    throw 'Python MSI junction target directory does not exist';
}
$alias = [IO.Path]::Combine($temp, 'vfox-python-msi-' + [Guid]::NewGuid().ToString('N'));
$created = $false;
$exitCode = 1;
try {
    New-Item -ItemType Junction -Path $alias -Target $target | Out-Null;
    $created = $true;
    $arguments = ]]
            .. literal("/quiet /a " .. argument(file) .. " TargetDir=")
            .. [[ + [char]34 + $alias + [char]34;
    $process = Start-Process -FilePath msiexec.exe -Wait -PassThru -ArgumentList $arguments;
    $exitCode = $process.ExitCode;
} finally {
    if ($created) {
        [IO.Directory]::Delete($alias);
    }
}; exit $exitCode]]
        return powershell(script)
    end
    return powershell(
        "$process = Start-Process -FilePath msiexec.exe -Wait -PassThru -ArgumentList "
            .. literal(args)
            .. "; exit $process.ExitCode"
    )
end

function command.files(path)
    return powershell(
        "Get-ChildItem -LiteralPath " .. literal(path) .. " -Filter '*.msi' -File | ForEach-Object { $_.Name }"
    )
end

function command.copy(source, target)
    return powershell("Copy-Item -LiteralPath " .. literal(source) .. " -Destination " .. literal(target) .. " -Force")
end

-- Registry values and paths are passed as UTF-8 base64 literals. The .NET
-- Registry API avoids PowerShell provider wildcard and default-value syntax.
-- PEP 514 puts the install path and the executable values under the
-- InstallPath subkey; the other values stay on the tag key.
function command.registrySet(subkey, installPath, tagValues, installValues)
    local lines = {
        "$base = [Microsoft.Win32.Registry]::CurrentUser;",
        "$key = $base.CreateSubKey(" .. literal(subkey) .. ");",
        "if ($null -eq $key) { throw 'Could not create the Python launcher registry key' };",
        "try {",
    }
    for _, item in ipairs(tagValues) do
        lines[#lines + 1] = "    $key.SetValue("
            .. literal(item.name)
            .. ", "
            .. literal(item.value)
            .. ", [Microsoft.Win32.RegistryValueKind]::String);"
    end
    lines[#lines + 1] = "    $install = $key.CreateSubKey(" .. literal("InstallPath") .. ");"
    lines[#lines + 1] = "    if ($null -eq $install) { throw 'Could not create the InstallPath registry key' };"
    lines[#lines + 1] = "    try {"
    lines[#lines + 1] = "        $install.SetValue('', "
        .. literal(installPath)
        .. ", [Microsoft.Win32.RegistryValueKind]::String);"
    for _, item in ipairs(installValues) do
        lines[#lines + 1] = "        $install.SetValue("
            .. literal(item.name)
            .. ", "
            .. literal(item.value)
            .. ", [Microsoft.Win32.RegistryValueKind]::String);"
    end
    lines[#lines + 1] = "    } finally {"
    lines[#lines + 1] = "        $install.Close();"
    lines[#lines + 1] = "    }"
    lines[#lines + 1] = "} finally {"
    lines[#lines + 1] = "    $key.Close();"
    lines[#lines + 1] = "}"
    lines[#lines + 1] = "exit 0"
    return powershell(table.concat(lines, "\n"))
end

function command.registryDeleteIfOwned(subkey, expectedPath)
    local lines = {
        "$base = [Microsoft.Win32.Registry]::CurrentUser;",
        "$key = $base.OpenSubKey(" .. literal(subkey) .. ");",
        "if ($null -eq $key) { exit 0 };",
        "$managed = $key.GetValue('VfoxManaged');",
        "$installPath = $null;",
        "$install = $key.OpenSubKey('InstallPath');",
        "if ($null -ne $install) {",
        "    $installPath = $install.GetValue('');",
        "    $install.Close();",
        "}",
        "if ([string]::IsNullOrEmpty($installPath)) { $installPath = $key.GetValue('') };",
        "$key.Close();",
        "if ($managed -ne '1') { exit 0 };",
        "if ([string]::IsNullOrEmpty($installPath)) { exit 0 };",
        "if ([string]::Compare($installPath, " .. literal(expectedPath) .. ", $true) -ne 0) { exit 0 };",
        "$base.DeleteSubKeyTree(" .. literal(subkey) .. ", $false);",
        "$company = $base.OpenSubKey('Software\\Python\\VersionFox');",
        "if ($null -ne $company) {",
        "    $hasChildren = $company.SubKeyCount -gt 0;",
        "    $company.Close();",
        "    if (-not $hasChildren) { $base.DeleteSubKey('Software\\Python\\VersionFox', $false) }",
        "}",
        "exit 0",
    }
    return powershell(table.concat(lines, "\n"))
end

return command
