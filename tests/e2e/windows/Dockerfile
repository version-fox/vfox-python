# escape=`
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

ARG BASE_IMAGE=mcr.microsoft.com/windows/servercore:ltsc2025-KB5122871-amd64
FROM ${BASE_IMAGE}

SHELL ["powershell", "-NoProfile", "-Command"]

COPY tests/e2e/windows/bootstrap-tools.ps1 C:\bootstrap-tools.ps1
RUN powershell -NoProfile -ExecutionPolicy Bypass -File C:\bootstrap-tools.ps1

ARG VFOX_VERSION=1.1.0
ARG VFOX_SHA256=1bbec8fffddbb62de0d93030c3f6203c69680662bc65257ca4a5e611cb607d0a
ENV VFOX_VERSION=${VFOX_VERSION}
ENV VFOX_SHA256=${VFOX_SHA256}

RUN $ErrorActionPreference = 'Stop'; `
    curl.exe -fsSL --retry 3 --retry-delay 5 --retry-all-errors `
        -o C:\vfox.zip `
        "https://github.com/version-fox/vfox/releases/download/v${env:VFOX_VERSION}/vfox_${env:VFOX_VERSION}_windows_x86_64.zip"; `
    if ($LASTEXITCODE -ne 0) { throw "vfox download failed: $LASTEXITCODE" }; `
    $hash = (Get-FileHash -LiteralPath C:\vfox.zip -Algorithm SHA256).Hash.ToLower(); `
    if ($hash -ne $env:VFOX_SHA256) { throw "vfox checksum mismatch: $hash" }; `
    Expand-Archive -LiteralPath C:\vfox.zip -DestinationPath C:\vfox -Force; `
    Remove-Item C:\vfox.zip; `
    if (-not (Test-Path C:\vfox\vfox.exe)) { throw 'vfox.exe is missing' }

ENV PATH="C:\vfox;C:\Program Files\PowerShell\7;${PATH}"

COPY metadata.lua C:\e2e\metadata.lua
COPY hooks C:\e2e\hooks
COPY lib C:\e2e\lib
COPY tests/e2e/windows/run.ps1 C:\e2e\run.ps1

ENTRYPOINT ["C:/Program Files/PowerShell/7/pwsh.exe", "-NoProfile", "-File", "C:/e2e/run.ps1"]
