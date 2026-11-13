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

require("util")
function PLUGIN:EnvKeys(ctx)
    local mainPath = ctx.path
    local version = (ctx.main and ctx.main.version)
        or (ctx.sdkInfo and ctx.sdkInfo["python"] and ctx.sdkInfo["python"].version)
        or ""

    if RUNTIME.osType == "windows" then
        if isGraalPyVersion(version) then
            -- GraalPy keeps python.exe under bin, like a Unix prefix.
            local prefix = resolvePythonInstallPath(mainPath, version)
            return {
                {
                    key = "PATH",
                    value = prefix .. "\\bin",
                },
                {
                    key = "PATH",
                    value = prefix .. "\\Scripts",
                },
            }
        end
        return {
            {
                key = "PATH",
                value = mainPath,
            },
            {
                key = "PATH",
                value = mainPath .. "\\Scripts",
            },
        }
    else
        local prefix = mainPath
        if isGraalPyVersion(version) then
            prefix = resolvePythonInstallPath(mainPath, version)
        end
        return {
            {
                key = "PATH",
                value = prefix .. "/bin",
            },
        }
    end
end
