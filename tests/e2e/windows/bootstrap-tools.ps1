<#
 Copyright 2026 Han Li and contributors

 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
#>

$ErrorActionPreference = 'Stop'

# The Windows container runs the suite with PowerShell 7, like the runner and
# the plugin's CI steps. Server Core ships Windows PowerShell 5.1 only.
$pwshZip = "$env:TEMP\pwsh.zip"
$pwshUrl = 'https://github.com/PowerShell/PowerShell/releases/download/v7.6.6/PowerShell-7.6.6-win-x64.zip'
$pwshHome = 'C:\Program Files\PowerShell\7'

curl.exe -fsSL --retry 3 --retry-delay 5 --retry-all-errors -o $pwshZip $pwshUrl
if ($LASTEXITCODE -ne 0) { throw "FAIL the PowerShell download exited with $LASTEXITCODE" }

New-Item -ItemType Directory -Force -Path $pwshHome | Out-Null
tar.exe -xf $pwshZip -C $pwshHome
if ($LASTEXITCODE -ne 0) { throw "FAIL the PowerShell extraction exited with $LASTEXITCODE" }
Remove-Item $pwshZip
if (-not (Test-Path "$pwshHome\pwsh.exe")) { throw 'FAIL pwsh.exe is missing after the PowerShell extraction' }

[Environment]::SetEnvironmentVariable(
    'PATH',
    [Environment]::GetEnvironmentVariable('PATH', 'Machine') + ";$pwshHome",
    'Machine'
)
