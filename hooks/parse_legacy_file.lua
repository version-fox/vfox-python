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

local python_version = require("python_version")

--- Reads the first request in a .python-version file. pyenv, uv and asdf all
--- write one version per line; blank lines and comments are skipped.
local function read_request(filepath)
    local file = io.open(filepath, "r")
    if not file then
        return nil
    end
    local request
    while true do
        local line = file:read("*l")
        if line == nil then
            break
        end
        line = line:gsub("^%s+", ""):gsub("%s+$", "")
        if line ~= "" and line:sub(1, 1) ~= "#" then
            request = line
            break
        end
    end
    file:close()
    return request
end

--- Selects the installed Python a .python-version file names, so a project
--- managed with pyenv or uv opens on the same version in vfox:
---
---   3.12            -> the newest installed 3.12.x
---   cpython-3.12.8  -> 3.12.8, or its linked 3.12.8-system
---   system          -> the newest linked system Python
---
--- A version that is not installed selects nothing; vfox leaves the current
--- version in place rather than installing one behind the user's back.
function PLUGIN:ParseLegacyFile(ctx)
    local request = python_version.parse_request(read_request(ctx.filepath))
    if request == nil and ctx.strategy ~= "latest_installed" then
        return {}
    end

    local installed = {}
    local names = {}
    for _, name in ipairs(ctx.getInstalledVersions()) do
        installed[name] = true
        names[#names + 1] = name
    end

    local name = python_version.find_installed(installed, request)
    if name == nil and ctx.strategy == "latest_installed" then
        name = python_version.newest(names)
    end
    if name == nil then
        return {}
    end
    return { version = name }
end
