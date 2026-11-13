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

--- Version parsing and matching shared by the Detect and ParseLegacyFile
--- hooks. vfox installs Python under bare version names such as 3.12.8 and
--- 3.14.0a4t; versions adopted from the machine carry a source suffix, such as
--- 3.12.8-system or 3.13.1-uv.
local python_version = {}

local function trim(value)
    return (value:gsub("^%s+", ""):gsub("%s+$", ""))
end

--- Splits a version or name into its numbers, so 3.12.8, 3.12.8-system and
--- 3.12.8+freethreaded all compare as the release 3.12.8.
local function numbers(value)
    local result = {}
    for part in value:gmatch("%d+") do
        result[#result + 1] = tonumber(part)
    end
    return result
end

--- Compares two versions by their numbers, missing ones as 0. Like vfox, the
--- newest wins; a source suffix does not change the comparison.
function python_version.compare(left, right)
    local x, y = numbers(left), numbers(right)
    for i = 1, math.max(#x, #y) do
        local a, b = x[i] or 0, y[i] or 0
        if a ~= b then
            return a > b and 1 or -1
        end
    end
    return 0
end

--- Returns the newest name in a list, or nil for an empty list.
function python_version.newest(names)
    local best
    for _, name in ipairs(names) do
        if not best or python_version.compare(name, best) > 0 then
            best = name
        end
    end
    return best
end

--- Turns what pyenv or uv writes into a .python-version file into a version
--- the plugin can select, or nil for an entry it does not handle:
---
---   3.12.8                                  -> 3.12.8
---   3.12                                    -> 3.12
---   cpython-3.12.8                          -> 3.12.8
---   cpython-3.12.8+freethreaded-linux-x86_64 -> 3.12.8t
---   system                                  -> system
---   pypy3.10-7.3.15                         -> nil
---   3.12.3/envs/example                     -> nil
---
--- A path is not a request: `vfox use` takes names, not directories.
function python_version.parse_request(text)
    if type(text) ~= "string" then
        return nil
    end
    local value = trim(text)
    if value == "" then
        return nil
    end
    if value == "system" then
        return "system"
    end
    if value:sub(1, 1) == "/" or value:sub(1, 1) == "~" or value:match("^%a:[/\\]") or value:find("[/\\]") then
        return nil
    end

    -- GraalPy version names already carry their implementation and release,
    -- such as graalpy-24.2.0 or graalpy3.13-community-25.5.5.
    if value:match("^graalpy[%w%.]*%-") or value:match("^graalpython%-") then
        return value
    end

    local implementation = value:match("^([A-Za-z][A-Za-z0-9]*)%-")
    if implementation then
        implementation = implementation:lower()
        if implementation == "python" or implementation == "cpython" then
            value = value:gsub("^[A-Za-z][A-Za-z0-9]*-", "", 1)
        else
            return nil
        end
    end

    if value:find("freethreaded", 1, true) then
        local release = value:match("^(%d+%.%d+[%w%.]*)")
        if not release then
            return nil
        end
        if release:sub(-1) ~= "t" then
            release = release .. "t"
        end
        return release
    end

    if not value:match("^%d") then
        return nil
    end
    return value
end

--- Finds the installed name a request selects. The exact name wins; then the
--- newest installed version that starts with the request. A request of
--- "system" takes the newest linked system Python. When two names share a
--- version, a bare install comes before a source-suffixed one, as vfox's own
--- matching does.
function python_version.find_installed(installed, request)
    if type(request) ~= "string" or request == "" then
        return nil
    end

    if request == "system" then
        local systems = {}
        for name in pairs(installed) do
            if name:sub(-7) == "-system" then
                systems[#systems + 1] = name
            end
        end
        return python_version.newest(systems)
    end

    if installed[request] then
        return request
    end

    local best, best_rank
    for name in pairs(installed) do
        if name:sub(1, #request) == request then
            local boundary = name:sub(#request + 1, #request + 1)
            local rank
            if boundary == "" then
                rank = 4
            elseif boundary == "." or boundary == "+" then
                rank = 3
            elseif boundary == "-" then
                rank = 2
            end
            if rank then
                local order = best and python_version.compare(name, best) or 1
                if not best or order > 0 or order == 0 and rank > best_rank then
                    best, best_rank = name, rank
                end
            end
        end
    end
    return best
end

--- Builds the name Detect links a Python under: the version, then the source,
--- as in 3.12.8-system or 3.13.1-uv.
function python_version.name(version, source)
    if source and source ~= "" then
        return version .. "-" .. source
    end
    return version
end

--- Mirrors vfox's version-name check, so Detect never reports a name `vfox
--- link` would refuse.
function python_version.is_valid_name(name)
    return type(name) == "string" and name ~= "latest" and name:match("^[A-Za-z0-9][A-Za-z0-9._+%-]*$") ~= nil
end

return python_version
