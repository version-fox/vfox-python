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
    -- The source-build path: the default would also read the uv-build index.
    env = { VFOX_PYTHON_USE_UV_BUILD = "0" },
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

-- A source suffix is not part of the release. -opt does not make a name
-- free-threaded, and -uv keeps a free-threaded release free-threaded.
local linked = set({ "3.12.8-opt", "3.13.1t-uv", "3.14.0a4t-uv" })
local linkedCases = {
    { "3.12", "3.12.8-opt" },
    { "3.13", nil }, -- 3.13.1t-uv is free-threaded, so a plain request skips it
    { "3.13t", "3.13.1t-uv" },
    { "3.14t", nil }, -- 3.14.0a4t-uv is a pre-release
}
for _, case in ipairs(linkedCases) do
    local got = python_version.find_release(linked, case[1])
    assert(got == case[2], case[1] .. " selected " .. tostring(got) .. ", want " .. tostring(case[2]))
end

-- .python-version resolves a release line the way vfox use does, while an
-- exact version or a bare prefix still reaches a linked name.
assert(python_version.find_installed(set({ "3.13.0", "3.13.1t" }), "3.13") == "3.13.0")
assert(python_version.find_installed(set({ "3.13.1t", "3.13.0" }), "3.13t") == "3.13.1t")
assert(python_version.find_installed(set({ "3.14.0a4" }), "3.14") == nil)
assert(python_version.find_installed(set({ "3.14.0a4" }), "3.14.0a4") == "3.14.0a4")
assert(python_version.find_installed(set({ "3.12.8-opt" }), "3.12") == "3.12.8-opt")
assert(python_version.find_installed(set({ "3.12.8-system" }), "3.12.8") == "3.12.8-system")

-- Installs of one version: the bare name first, then the name that sorts first.
-- The result must not depend on the order in which the names are given.
assert(python_version.find_installed(set({ "3.12.8-system", "3.12.8-local" }), "3.12.8") == "3.12.8-local")
assert(python_version.find_installed(set({ "3.12.8-local", "3.12.8-system" }), "3.12.8") == "3.12.8-local")
assert(python_version.find_installed(set({ "3.13.1t-system", "3.13.1-system" }), "system") == "3.13.1-system")
assert(python_version.find_installed(set({ "3.13.1-system", "3.13.1t-system" }), "system") == "3.13.1-system")
assert(python_version.newest({ "3.12.8-system", "3.12.8-local" }) == "3.12.8-local")
assert(python_version.newest({ "3.12.8-local", "3.12.8-system" }) == "3.12.8-local")
assert(python_version.newest({ "3.12.8-local", "3.12.8" }) == "3.12.8")
assert(python_version.newest({ "3.12.8", "3.12.8-local" }) == "3.12.8")
assert(python_version.find_release(set({ "3.12.8-system", "3.12.8-local" }), "3.12") == "3.12.8-local")

-- "system" is a plain request too: it selects the newest regular CPython install
-- named -system. A free-threaded or pre-release install needs its full name, and
-- GraalPy's release numbers cannot be compared with CPython's.
assert(python_version.find_installed(set({ "3.13.2t-system", "3.13.1-system" }), "system") == "3.13.1-system")
assert(python_version.find_installed(set({ "3.14.0a4-system", "3.13.1-system" }), "system") == "3.13.1-system")
assert(python_version.find_installed(set({ "3.13.2t-system" }), "system") == nil)
assert(python_version.find_installed(set({ "3.13.2t-system" }), "3.13.2t-system") == "3.13.2t-system")
assert(python_version.find_installed(set({ "graalpy-24.2.0-system", "3.12.3-system" }), "system") == "3.12.3-system")
assert(python_version.find_installed(set({ "graalpy-24.2.0-system" }), "system") == nil)

-- The latest_installed fallback: the newest regular CPython install, or else the
-- newest installed name of any kind.
assert(python_version.newest_installed({ "graalpy-24.2.0", "3.12.3" }) == "3.12.3")
assert(python_version.newest_installed({ "3.13.2t", "3.13.1" }) == "3.13.1")
assert(python_version.newest_installed({ "3.14.0a4", "3.13.1-system" }) == "3.13.1-system")
assert(python_version.newest_installed({ "graalpy-24.2.0" }) == "graalpy-24.2.0")

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

-- newer_first orders a newest-first list: the release numbers decide, a final build
-- comes before its free-threaded build and before its pre-release, and a pyenv
-- snapshot comes after every release.
local function newestFirst(list)
    local copy = {}
    for i, name in ipairs(list) do
        copy[i] = name
    end
    table.sort(copy, python_version.newer_first)
    return table.concat(copy, " ")
end
assert(
    newestFirst({ "3.13.5", "3.13.18t", "3.12.16", "3.16-dev", "3.16.0a2", "3.16.0", "3.13.18" })
        == "3.16.0 3.16.0a2 3.13.18 3.13.18t 3.13.5 3.12.16 3.16-dev",
    newestFirst({ "3.13.5", "3.13.18t", "3.12.16", "3.16-dev", "3.16.0a2", "3.16.0", "3.13.18" })
)
-- A free-threaded build sorts by its release, not by the digits of its suffix.
assert(python_version.newer_first("3.13.18t", "3.13.5"), "3.13.18t is newer than 3.13.5")
assert(not python_version.newer_first("3.13.5", "3.13.18t"), "3.13.5 is not newer than 3.13.18t")
-- A final build outranks the pre-release of the same numbers.
assert(python_version.newer_first("3.16.0", "3.16.0a2"), "3.16.0 is newer than its pre-release")
-- latest skips free-threaded builds, and a plain request never picks one either.
assert(python_version.is_free_threaded("3.13.18t"), "3.13.18t is free-threaded")
assert(python_version.is_free_threaded("3.16.0a2t"), "3.16.0a2t is free-threaded")
assert(not python_version.is_free_threaded("3.13.18"), "3.13.18 is not free-threaded")
assert(not python_version.is_free_threaded("3.16.0a2"), "a pre-release is not free-threaded")
assert(not python_version.is_free_threaded("graalpy-24.2.0"), "GraalPy is not free-threaded")
assert(not python_version.is_free_threaded("3.16-dev"), "a snapshot is not free-threaded")

print("PASS: partial versions resolve in PreInstall and PreUse")
