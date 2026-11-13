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

-- A partial request such as "3.12" is resolved before vfox acts on it.
-- PreInstall picks the newest stable release the version list names, and
-- PreUse picks the newest installed name. Exact names pass through unchanged,
-- and PreInstall does not read the version list for them.
local test = require("vfox.test")

-- The pyenv version list that the Linux source-build path reads.
local listed = { "2.7.18", "3.13.1", "3.12.9", "3.12.16", "3.12.5t", "3.12.17a1", "3.13.0a4", "graalpy-24.2.0" }
local reads = 0

local plugin = test.load({
    os = "linux",
    arch = "amd64",
    env = {},
    http = function()
        reads = reads + 1
        local quoted = {}
        for i, version in ipairs(listed) do
            quoted[i] = '"' .. version .. '"'
        end
        return { status_code = 200, body = '{"tagName":"test","versions":[' .. table.concat(quoted, ",") .. "]}" }
    end,
})
local python_version = require("python_version")

local function set(list)
    local result = {}
    for _, name in ipairs(list) do
        result[name] = true
    end
    return result
end

-- The matcher on its own.
local names = set({
    "2.7.18",
    "3.11.18",
    "3.12.9",
    "3.12.16",
    "3.12.16-system",
    "3.13.18",
    "3.13.18t",
    "3.16.0a2",
    "3.16.0a2t",
    "graalpy-24.2.0",
})

for _, request in ipairs({ "3", "3.12", "3.13t" }) do
    assert(python_version.is_partial(request), request .. " must be a partial request")
end
for _, request in ipairs({ "3.12.2", "3.13.1t", "3.16.0a2", "graalpy-24.2.0", "latest", "" }) do
    assert(not python_version.is_partial(request), request .. " must not be a partial request")
end

local cases = {
    { "3.12", "3.12.16" }, -- the bare 3.12.16 beats 3.12.16-system and 3.12.9
    { "3", "3.13.18" }, -- the newest stable 3.x, never a free-threaded or pre-release name
    { "3.13", "3.13.18" }, -- a plain request does not select 3.13.18t
    { "3.13t", "3.13.18t" }, -- a free-threaded request selects free-threaded names only
    { "3.12.9", "3.12.9" }, -- an exact name returns itself
    { "3.16.0a2", "3.16.0a2" },
    { "3.16", nil }, -- only pre-releases exist for 3.16
    { "3.1", nil }, -- the request must end at a dot, so 3.11 and 3.12 do not match
    { "3.12.1", nil }, -- an exact-looking request is not resolved
    { "latest", nil },
}
for _, case in ipairs(cases) do
    local got = python_version.find_release(names, case[1])
    assert(got == case[2], case[1] .. " selected " .. tostring(got) .. ", want " .. tostring(case[2]))
end

-- PreInstall: a partial request reads the version list, an exact one does not.
local before = reads
local package = plugin:PreInstall({ version = "3.12" })
assert(package.version == "3.12.16", package.version)
assert(reads > before, "a partial request must read the version list")

before = reads
package = plugin:PreInstall({ version = "3.12.9" })
assert(package.version == "3.12.9", package.version)
assert(reads == before, "an exact request must not read the version list")

-- PreUse on Linux checks whether an installation is linked. The stub answers
-- "yes", so PreUse returns before the health check and only the name matters.
io.popen = function()
    return {
        read = function()
            return "yes\n"
        end,
        close = function()
            return 0
        end,
    }
end

local installed = {}
for _, name in ipairs({ "3.12.16", "3.12.16-system", "3.13.18t" }) do
    installed[name] = {
        name = "python",
        version = name,
        path = "/home/test/.vfox/cache/python/v-" .. name,
    }
end

local function use(version)
    return plugin:PreUse({
        version = version,
        previousVersion = "",
        scope = "global",
        cwd = "/home/test",
        installedSdks = installed,
    })
end

assert(use("3.12").version == "3.12.16", use("3.12").version)
assert(use("3.12.16").version == "3.12.16", use("3.12.16").version)
assert(use("3.13t").version == "3.13.18t", use("3.13t").version)
-- Only the free-threaded 3.13.18t is installed, and a plain request never picks it.
assert(use("3.13").version == "3.13", use("3.13").version)

print("PASS: partial versions resolve in PreInstall and PreUse")
