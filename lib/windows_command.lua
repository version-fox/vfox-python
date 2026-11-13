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
    local chunks, result = {}, {}
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
        -- GopherLua runs out of registry space when one table holds a whole long script.
        if #result >= 256 then
            chunks[#chunks + 1] = table.concat(result)
            result = {}
        end
    end
    chunks[#chunks + 1] = table.concat(result)
    return table.concat(chunks)
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
        if ($exitCode -eq -1073741515) {
            Write-Output 'Missing DLL (0xC0000135): old CPython releases need the Visual C++ runtime they were built with, such as VC++ 2010 (msvcr100.dll) for 3.4.';
        }
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

function command.removeTree(path)
    return powershell(
        "if (Test-Path -LiteralPath "
            .. literal(path)
            .. ") { Remove-Item -LiteralPath "
            .. literal(path)
            .. " -Recurse -Force }"
    )
end

-- Reads the MSI packages out of the installer. Burn keeps them in a cabinet appended to the
-- EXE, and its manifest, stored in the UX cabinet, names each package. expand.exe, which ships
-- with Windows, unpacks both cabinets, so no extraction tool is bundled. The script copies each
-- MSI to <scratch>\msi under its own name, or throws with a message.
function command.bundlePackages(installerPath, scratchPath)
    return powershell(
        "$installer = "
            .. literal(installerPath)
            .. "; $scratch = "
            .. literal(scratchPath)
            .. ";\n"
            .. [[
$bytes = [IO.File]::ReadAllBytes($installer);
New-Item -ItemType Directory -Force -Path $scratch | Out-Null;
function ReadUInt32([int64]$offset) {
    return [int64][BitConverter]::ToUInt32($bytes, [int]$offset);
}
$peOffset = ReadUInt32 0x3C;
$sectionCount = [BitConverter]::ToUInt16($bytes, [int]($peOffset + 6));
$optionalHeaderSize = [BitConverter]::ToUInt16($bytes, [int]($peOffset + 20));
$sectionTable = $peOffset + 24 + $optionalHeaderSize;
$burn = -1;
for ($i = 0; $i -lt $sectionCount; $i++) {
    $entry = $sectionTable + 40 * $i;
    $sectionName = [Text.Encoding]::ASCII.GetString($bytes, [int]$entry, 8).TrimEnd([char]0);
    if ($sectionName -eq '.wixburn') { $burn = (ReadUInt32 ($entry + 20)) };
};
if ($burn -lt 0) { throw 'The installer has no .wixburn section.' };
if ((ReadUInt32 $burn) -ne 0x00F14300 -or (ReadUInt32 ($burn + 4)) -ne 2) { throw 'The installer has an unsupported Burn section.' };
$stubSize = ReadUInt32 ($burn + 24);
$signatureOffset = ReadUInt32 ($burn + 32);
$signatureSize = ReadUInt32 ($burn + 36);
$containerCount = ReadUInt32 ($burn + 44);
$sizes = @();
for ($i = 0; $i -lt $containerCount; $i++) { $sizes += (ReadUInt32 ($burn + 48 + 4 * $i)) };
if ($signatureOffset -ne 0) { $engineSize = $signatureOffset + $signatureSize } else { $engineSize = $stubSize + $sizes[0] };
function ContainerOffset([int]$index) {
    if ($index -eq 0) { return $stubSize };
    $offset = $engineSize;
    for ($j = 1; $j -lt $index; $j++) { $offset += $sizes[$j] };
    return $offset;
}
function ExpandContainer([int]$index, [string]$name) {
    $offset = ContainerOffset $index;
    $length = $sizes[$index];
    if ($offset + $length -gt $bytes.Length) { throw "Container $index lies outside the installer." };
    $cabPath = Join-Path $scratch "$name.cab";
    $cabBytes = New-Object byte[] ([int]$length);
    [Array]::Copy($bytes, [int]$offset, $cabBytes, 0, [int]$length);
    [IO.File]::WriteAllBytes($cabPath, $cabBytes);
    $folder = Join-Path $scratch $name;
    New-Item -ItemType Directory -Path $folder | Out-Null;
    & expand.exe '-F:*' $cabPath $folder | Out-Null;
    if ($LASTEXITCODE -ne 0) { throw "expand.exe could not unpack container $index of the installer." };
    return $folder;
}
$uxFolder = ExpandContainer 0 'ux';
$manifestPath = Join-Path $uxFolder '0';
if (-not (Test-Path -LiteralPath $manifestPath)) { throw 'The installer has no bundle manifest.' };
[xml]$manifest = [IO.File]::ReadAllText($manifestPath, [Text.Encoding]::UTF8);
$namespaces = [Xml.XmlNamespaceManager]::new($manifest.NameTable);
$namespaces.AddNamespace('b', $manifest.DocumentElement.NamespaceURI);
$primary = $manifest.SelectSingleNode("//b:Container[@Attached='yes' and @Primary='yes']", $namespaces);
if ($primary -eq $null) { throw 'The bundle manifest has no primary attached container.' };
$packages = ExpandContainer ([int]$primary.AttachedIndex) 'packages';
$msiFolder = Join-Path $scratch 'msi';
New-Item -ItemType Directory -Path $msiFolder | Out-Null;
$copied = @{};
foreach ($payload in $manifest.SelectNodes("//b:Payload[@Container='$($primary.Id)' and @Packaging='embedded']", $namespaces)) {
    $name = $payload.FilePath;
    if (-not $name.EndsWith('.msi', [StringComparison]::OrdinalIgnoreCase) -or $copied.ContainsKey($name)) { continue };
    Copy-Item -LiteralPath (Join-Path $packages $payload.SourcePath) -Destination (Join-Path $msiFolder $name);
    $copied[$name] = $true;
};
if ($copied.Count -eq 0) { throw 'The bundle manifest lists no MSI packages in its attached container.' };
]]
    )
end

return command
