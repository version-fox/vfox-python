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

-- A mirror without a trailing slash must still build the same paths as one
-- with it; the Windows PreInstall check is the simplest request to inspect.
local test = require("vfox.test")

local source = "https://mirror.example/python/3.12.8/Python-3.12.8.tar.xz"
local installer = "https://mirror.example/python/3.12.8/python-3.12.8-amd64.exe"
local requests = {}
local plugin = test.load({
    os = "windows",
    arch = "amd64",
    env = { VFOX_PYTHON_MIRROR = "https://mirror.example/python" },
    http = function(request)
        requests[#requests + 1] = request.url
        assert(request.method == "HEAD", request.method)
        -- Both the source tarball and the Windows EXE exist on this mirror.
        if request.url == source or request.url == installer then
            return { status_code = 200 }
        end
        return { status_code = 404 }
    end,
})

local package = plugin:PreInstall({ version = "3.12.8" })
assert(package.version == "3.12.8", tostring(package.version))
-- The source release check runs first, then the Windows installer lookup.
assert(#requests == 2, tostring(#requests))
assert(requests[1] == source, requests[1])
assert(requests[2] == installer, requests[2])

print("PASS: VFOX_PYTHON_MIRROR trailing slash and source release check")
