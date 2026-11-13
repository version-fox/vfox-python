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

-- On Linux GraalPy is a .tar.gz from Oracle's releases, not a pyenv build.
-- The version list still comes from pyenv, but PreInstall, the extracted
-- layout and EnvKeys are platform-specific.
local test = require("vfox.test")

local GRAALPY_URL = "https://api.github.com/repos/oracle/graalpython/releases?per_page=100"
local base = "https://github.com/oracle/graalpython/releases/download/graal-24.2.0/"
local assets = {
    {
        name = "graalpy-24.2.0-linux-amd64.tar.gz",
        browser_download_url = base .. "graalpy-24.2.0-linux-amd64.tar.gz",
    },
    {
        name = "graalpy-community-24.2.0-linux-amd64.tar.gz",
        browser_download_url = base .. "graalpy-community-24.2.0-linux-amd64.tar.gz",
    },
    {
        name = "graalpy-24.2.0-windows-amd64.zip",
        browser_download_url = base .. "graalpy-24.2.0-windows-amd64.zip",
    },
}

local sha256Urls = {}
for _, asset in ipairs(assets) do
    sha256Urls[asset.browser_download_url .. ".sha256"] = true
end

local plugin = test.load({
    os = "linux",
    arch = "amd64",
    env = {},
    http = function(request)
        if request.url == GRAALPY_URL then
            return {
                status_code = 200,
                body = require("json").encode({ { tag_name = "graal-24.2.0", assets = assets } }),
            }
        end
        if sha256Urls[request.url] then
            return { status_code = 200, body = string.rep("b", 64) }
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

local package = plugin:PreInstall({ version = "graalpy-24.2.0" })
assert(package.url == assets[1].browser_download_url, package.url)
assert(package.sha256 == string.rep("b", 64), tostring(package.sha256))
assert(package.note == "GraalPy", tostring(package.note))

local legacy = plugin:PreInstall({ version = "graalpython-20.3.0" })
assert(legacy.version == "graalpython-20.3.0", legacy.version)
assert((legacy.url or "") == "", "legacy graalpython-* versions stay on pyenv")

RUNTIME.archType = "armv7"
fails(function()
    plugin:PreInstall({ version = "graalpy-24.2.0" })
end, "GraalPy is not available for linux/armv7")
RUNTIME.archType = "amd64"

local root = "/home/test/.vfox/cache/python/v-graalpy-24.2.0"
local prefix = root .. "/graalpy-24.2.0-linux-amd64"
local oldOpen = io.open
io.open = function(path, mode)
    if mode == "r" and (path == prefix .. "/bin" or path == prefix .. "/bin/python3") then
        return { close = function() end }
    end
    return nil
end

assert(resolvePythonInstallPath(root, "graalpy-24.2.0") == prefix)
local env = plugin:EnvKeys({ path = root, main = { version = "graalpy-24.2.0" } })
assert(#env == 1, #env)
assert(env[1].key == "PATH" and env[1].value == prefix .. "/bin", env[1].value)
io.open = oldOpen

assert(python_version.parse_request("graalpy3.13-community-25.5.5") == "graalpy3.13-community-25.5.5")
assert(python_version.parse_request("graalpython-20.3.0") == "graalpython-20.3.0")

print("PASS: Linux GraalPy archive, layout, EnvKeys and legacy fallback")
