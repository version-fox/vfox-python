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

-- GraalPy uses Oracle's release zips on Windows, keeps python.exe under bin,
-- and has its own naming for the Oracle and Community editions.
local test = require("vfox.test")

local GRAALPY_URL = "https://api.github.com/repos/oracle/graalpython/releases?per_page=100"
local base = "https://github.com/oracle/graalpython/releases/download/"
local assets = {
    {
        name = "graalpy-24.2.0-windows-amd64.zip",
        browser_download_url = base .. "graal-24.2.0/graalpy-24.2.0-windows-amd64.zip",
    },
    {
        name = "graalpy-community-24.2.0-windows-amd64.zip",
        browser_download_url = base .. "graal-24.2.0/graalpy-community-24.2.0-windows-amd64.zip",
    },
    {
        name = "graalpy3.13-25.5.5-windows-amd64.zip",
        browser_download_url = base .. "graal-25.5.5/graalpy3.13-25.5.5-windows-amd64.zip",
    },
    {
        name = "graalpy3.13-community-25.5.5-windows-amd64.zip",
        browser_download_url = base .. "graal-25.5.5/graalpy3.13-community-25.5.5-windows-amd64.zip",
    },
    {
        name = "graalpy-24.2.0-jvm-windows-amd64.zip",
        browser_download_url = base .. "graal-24.2.0/graalpy-24.2.0-jvm-windows-amd64.zip",
    },
}

local sha256Urls = {}
for _, asset in ipairs(assets) do
    sha256Urls[asset.browser_download_url .. ".sha256"] = true
end

local requests = {}
local plugin = test.load({
    os = "windows",
    arch = "amd64",
    env = {},
    http = function(request)
        requests[request.url] = (requests[request.url] or 0) + 1
        if request.url == GRAALPY_URL then
            return {
                status_code = 200,
                body = require("json").encode({ { tag_name = "graal-25.5.5", assets = assets } }),
            }
        end
        if sha256Urls[request.url] then
            return { status_code = 200, body = string.rep("a", 64) }
        end
        error("unexpected request: " .. request.url)
    end,
})

require("util")
local python_version = require("python_version")

local function fails(fn, expected)
    local ok, err = pcall(fn)
    assert(not ok and tostring(err):find(expected, 1, true), tostring(err))
end

local oracle = plugin:PreInstall({ version = "graalpy-24.2.0" })
assert(oracle.version == "graalpy-24.2.0", oracle.version)
assert(oracle.url == assets[1].browser_download_url, oracle.url)
assert(oracle.sha256 == string.rep("a", 64), tostring(oracle.sha256))
assert(oracle.note == "GraalPy", tostring(oracle.note))

local community = plugin:PreInstall({ version = "graalpy-community-24.2.0" })
assert(community.url == assets[2].browser_download_url, community.url)
assert(community.note == "GraalPy Community", tostring(community.note))

local current = plugin:PreInstall({ version = "graalpy3.13-25.5.5" })
assert(current.url == assets[3].browser_download_url, current.url)
assert(requests[assets[3].browser_download_url .. ".sha256"] == 1)

fails(function()
    plugin:PreInstall({ version = "graalpy-22.3.0" })
end, "No GraalPy windows-amd64 build found")

RUNTIME.archType = "arm64"
fails(function()
    plugin:PreInstall({ version = "graalpy-24.2.0" })
end, "GraalPy is not available for windows/arm64")
assert(#parseGraalPyWindowsVersions() == 0)
RUNTIME.archType = "amd64"

local parsed = assert(parseGraalPyVersion("graalpy-24.2.0"))
assert(parsed.release == "24.2.0" and parsed.community == false and parsed.pythonMinor == nil)
parsed = assert(parseGraalPyVersion("graalpy-community-24.2.0"))
assert(parsed.release == "24.2.0" and parsed.community == true)
parsed = assert(parseGraalPyVersion("graalpy3.13-25.5.5"))
assert(parsed.release == "25.5.5" and parsed.pythonMinor == "3.13")
parsed = assert(parseGraalPyVersion("graalpy3.13-community-25.5.5"))
assert(parsed.release == "25.5.5" and parsed.pythonMinor == "3.13" and parsed.community == true)
assert(parseGraalPyVersion("graalpython-20.3.0") == nil)
assert(isGraalPyVersion("graalpython-20.3.0"))

assert(python_version.parse_request("graalpy-24.2.0") == "graalpy-24.2.0")
assert(python_version.parse_request("graalpy3.13-community-25.5.5") == "graalpy3.13-community-25.5.5")
assert(python_version.parse_request("pypy3.10-7.3.15") == nil)

local root = "C:\\vfox\\cache\\python\\v-graalpy-community-24.2.0"
local prefix = root .. "\\graalpy-community-24.2.0-windows-amd64"
local executable = prefix .. "\\bin\\python.exe"
local oldOpen = io.open
io.open = function(path, mode)
    if mode == "r" and path == executable then
        return { close = function() end }
    end
    return nil
end

assert(resolvePythonInstallPath(root, "graalpy-community-24.2.0") == prefix)
local env = plugin:EnvKeys({ path = root, main = { version = "graalpy-community-24.2.0" } })
assert(#env == 2, #env)
assert(env[1].key == "PATH" and env[1].value == prefix .. "\\bin", env[1].value)
assert(env[2].key == "PATH" and env[2].value == prefix .. "\\Scripts", env[2].value)

io.open = oldOpen

print("PASS: GraalPy Windows listing, PreInstall, layout and EnvKeys")
