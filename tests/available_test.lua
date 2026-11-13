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

-- The Windows download page lists installers for every architecture at once.
-- Available must leave only the ones the running vfox can install, in newest
-- first order, and must not probe each installer with a HEAD request.
local test = require("vfox.test")

local state = {
    requests = 0,
    response = nil,
    error = nil,
}

local plugin = test.load({
    os = "windows",
    arch = "amd64",
    -- An empty variable is what GitHub Actions passes for an unset matrix
    -- value; it must mean "no mirror", not an empty base URL.
    env = { VFOX_PYTHON_MIRROR = "" },
    http = function(request)
        state.requests = state.requests + 1
        assert(request.url == "https://www.python.org/downloads/windows/", request.url)
        if state.error then
            return nil, state.error
        end
        return state.response
    end,
})

local links = {
    "https://www.python.org/ftp/python/3.12.8/python-3.12.8-amd64.exe",
    "https://www.python.org/ftp/python/3.12.8/python-3.12.8-amd64.exe",
    "https://www.python.org/ftp/python/3.12.8/python-3.12.8.exe",
    "https://www.python.org/ftp/python/3.11.9/python-3.11.9-arm64.exe",
    "https://www.python.org/ftp/python/3.11.9/python-3.11.9-amd64.exe",
    "https://www.python.org/ftp/python/3.4.4/python-3.4.4.amd64.msi",
    "https://www.python.org/ftp/python/3.4.4/python-3.4.4.msi",
    "https://www.python.org/ftp/python/3.8.18/Python-3.8.18.tar.xz",
    "https://www.python.org/ftp/python/3.13.0/python-3.13.0a1-amd64.exe",
    "https://www.python.org/ftp/python/pymanager/python-manager-25.0.msi",
    "https://www.python.org/ftp/python/3.12.8/python-3.12.8-embed-amd64.zip",
    "https://www.python.org/ftp/python/2.4/python-2.4.msi",
}

local function page()
    local anchors = {}
    for _, href in ipairs(links) do
        anchors[#anchors + 1] = '<a href="' .. href .. '">' .. href .. "</a>"
    end
    return "<html><body>" .. table.concat(anchors, "\n") .. "</body></html>"
end

local function listing(arch, expected)
    RUNTIME.archType = arch
    state.response, state.error, state.requests = { status_code = 200, body = page() }, nil, 0
    local result = plugin:Available({})
    assert(#result == #expected, #result)
    for i, version in ipairs(expected) do
        assert(result[i].version == version, result[i].version)
    end
    assert(state.requests == 1, "the listing must take one request, got " .. state.requests)
end

listing("amd64", { "3.12.8", "3.11.9", "3.4.4" })
listing("386", { "3.12.8", "3.4.4" })
listing("arm64", { "3.11.9" })

local function fails(expected)
    local ok, err = pcall(function()
        plugin:Available({})
    end)
    assert(not ok and tostring(err):find(expected, 1, true), tostring(err))
end

RUNTIME.archType = "amd64"
state.response, state.error = nil, "timeout"
fails("timeout")
state.response, state.error = { status_code = 503 }, nil
fails("503")
state.response = { status_code = 200, body = "no installers" }
links = {}
fails("No Windows Python installers")
RUNTIME.archType = "mips"
links = { "https://www.python.org/ftp/python/3.12.8/python-3.12.8-amd64.exe" }
state.response = { status_code = 200, body = page() }
fails("Unsupported Windows Python architecture")

print("PASS: Windows installer listing, architecture filtering and failures")
