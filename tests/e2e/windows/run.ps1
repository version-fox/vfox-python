# Copyright 2026 Han Li and contributors
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

$ErrorActionPreference = 'Stop'
$env:PATH = "C:\vfox;C:\Program Files\PowerShell\7;$env:PATH"

$version = $env:GRAALPY_VERSION
if ([string]::IsNullOrEmpty($version)) {
    $version = 'graalpy3.13-community-25.5.5'
}

Set-Location C:\e2e
Compress-Archive -Path metadata.lua, hooks, lib -DestinationPath C:\python-plugin.zip -Force
vfox add --source C:\python-plugin.zip
Invoke-Expression "$(vfox activate pwsh)"
$installed = $false
for ($attempt = 1; $attempt -le 3; $attempt++) {
    vfox install "python@$version"
    if ($LASTEXITCODE -eq 0) {
        $installed = $true
        break
    }
    Start-Sleep -Seconds 10
}
if (-not $installed) {
    throw "vfox install failed after 3 attempts"
}
vfox use --global "python@$version"
Invoke-Expression "$(vfox env --shell pwsh)"
vfox current
python -V
python -c "import sys; assert sys.implementation.name == 'graalpy', sys.implementation.name; print(sys.version)"
python -m pip --version
pip --version

$project = 'C:\python-version-project'
Remove-Item -Recurse -Force -LiteralPath $project -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Path $project | Out-Null
Set-Content -LiteralPath "$project\.python-version" -Value $version
Push-Location $project
try {
    Invoke-Expression "$(vfox env --shell pwsh)"
    python -V
    python -c "import sys; assert sys.implementation.name == 'graalpy'"
} finally {
    Pop-Location
}

Write-Output "PASS: Windows container GraalPy $version"
