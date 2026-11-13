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

-- uv-build is the optional prebuilt source. The listing must keep only CPython
-- builds for this platform and variant, and PreInstall must prefer the
-- install_only_stripped archive, pass its checksum to vfox and route the
-- download through VFOX_PYTHON_UV_BUILD_MIRROR when that is set.
local test = require("vfox.test")

local github = "https://github.com/astral-sh/python-build-standalone/releases/download/20241016/"

local items = {
    {
        implementation = "cpython",
        version = "3.12.8",
        variant = "default",
        filename = "cpython-3.12.8+20241016-x86_64-unknown-linux-gnu-install_only.tar.gz",
        url = github .. "cpython-3.12.8+20241016-x86_64-unknown-linux-gnu-install_only.tar.gz",
        asset = { sha256 = string.rep("a", 64) },
    },
    {
        implementation = "cpython",
        version = "3.12.8",
        variant = "default",
        filename = "cpython-3.12.8+20241016-x86_64-unknown-linux-gnu-install_only_stripped.tar.gz",
        url = github .. "cpython-3.12.8+20241016-x86_64-unknown-linux-gnu-install_only_stripped.tar.gz",
        asset = { sha256 = string.rep("b", 64) },
    },
    {
        implementation = "cpython",
        version = "3.13.1",
        variant = "freethreaded",
        filename = "cpython-3.13.1+20241016-x86_64-unknown-linux-gnu-freethreaded-install_only_stripped.tar.gz",
        url = github .. "cpython-3.13.1+20241016-x86_64-unknown-linux-gnu-freethreaded-install_only_stripped.tar.gz",
        asset = { sha256 = string.rep("c", 64) },
    },
    {
        implementation = "pypy",
        version = "3.10.14",
        variant = "default",
        filename = "pypy.tar.gz",
        url = github .. "pypy.tar.gz",
        asset = { sha256 = string.rep("d", 64) },
    },
    {
        implementation = "cpython",
        version = "3.11.10",
        variant = "default",
        arch = { variant = "v2" },
        filename = "cpython-3.11.10+20241016-x86_64_v2-unknown-linux-gnu-install_only.tar.gz",
        url = github .. "cpython-3.11.10+20241016-x86_64_v2-unknown-linux-gnu-install_only.tar.gz",
        asset = { sha256 = string.rep("e", 64) },
    },
    {
        implementation = "cpython",
        version = "3.10.15",
        variant = "default",
        filename = "cpython-3.10.15+20241016-x86_64-unknown-linux-gnu-install_only.tar.gz",
        url = "http://insecure.example/cpython-3.10.15.tar.gz",
        asset = { sha256 = string.rep("f", 64) },
    },
    {
        implementation = "cpython",
        version = "3.11.11",
        variant = "default",
        filename = "cpython-3.11.11+20241016-x86_64-unknown-linux-gnu-install_only.tar.gz",
        url = github .. "cpython-3.11.11+20241016-x86_64-unknown-linux-gnu-install_only.tar.gz",
        asset = { sha256 = "not-a-checksum" },
    },
}

local state = {
    status = 200,
    items = items,
}

local plugin = test.load({
    os = "linux",
    arch = "amd64",
    env = {
        VFOX_PYTHON_USE_UV_BUILD = "1",
        VFOX_PYTHON_UV_LIBC = "musl",
        VFOX_PYTHON_UV_BUILD_MIRROR = "https://mirror.example/",
    },
    http = function(request)
        assert(request.url == "https://vault.vfox.dev/python/uv-build?os=linux&arch=x86_64&libc=musl", request.url)
        if state.status ~= 200 then
            return { status_code = state.status }
        end
        return { status_code = 200, body = '{"items":' .. require("json").encode(state.items) .. "}" }
    end,
})

local available = plugin:Available({})
assert(#available == 3, tostring(#available))
assert(available[1].version == "3.12.8", available[1].version)
assert(available[2].version == "3.13.1t", available[2].version)
-- The invalid checksum is rejected by PreInstall, not hidden from the list.
assert(available[3].version == "3.11.11", available[3].version)

local package = plugin:PreInstall({ version = "3.12.8" })
assert(package.version == "3.12.8", package.version)
assert(package.note == "uv-build", tostring(package.note))
assert(
    package.url
        == "https://mirror.example/20241016/cpython-3.12.8+20241016-x86_64-unknown-linux-gnu-install_only_stripped.tar.gz",
    package.url
)
assert(package.sha256 == string.rep("b", 64), tostring(package.sha256))

local latest = plugin:PreInstall({ version = "latest" })
assert(latest.version == "3.12.8", latest.version)

local function fails(version, expected)
    local ok, err = pcall(function()
        plugin:PreInstall({ version = version })
    end)
    assert(not ok and tostring(err):find(expected, 1, true), tostring(err))
end

fails("3.9.20", "No uv-build prebuilt Python found")
fails("3.11.11", "Invalid uv-build sha256")
fails("graalpy-24.2.0", "uv-build provides CPython only")

state.status = 503
local ok, err = pcall(function()
    plugin:Available({})
end)
assert(not ok and tostring(err):find("503", 1, true), tostring(err))

print("PASS: uv-build listing, archive priority, checksum and mirror")
