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

-- A GitHub API rate limit (HTTP 403) must not block an install. PreInstall
-- constructs the official asset URL and verifies its .sha256 file. The
-- 25.3.4.1 release is tagged graal-25.3.4.
local test = require("vfox.test")

local GRAALPY_URL = "https://api.github.com/repos/oracle/graalpython/releases?per_page=100"
local base = "https://github.com/oracle/graalpython/releases/download/"

local plugin = test.load({
    os = "linux",
    arch = "amd64",
    env = {},
    http = function(request)
        if request.url == GRAALPY_URL then
            return { status_code = 403 }
        end
        if request.url == base .. "graal-24.2.0/graalpy-24.2.0-linux-amd64.tar.gz.sha256" then
            return { status_code = 200, body = string.rep("c", 64) }
        end
        if request.url == base .. "graal-25.3.4/graalpy3.13-25.3.4.1-linux-amd64.tar.gz.sha256" then
            return { status_code = 200, body = string.rep("d", 64) }
        end
        return { status_code = 404 }
    end,
})

local package = plugin:PreInstall({ version = "graalpy-24.2.0" })
assert(package.url == base .. "graal-24.2.0/graalpy-24.2.0-linux-amd64.tar.gz", tostring(package.url))
assert(package.sha256 == string.rep("c", 64), tostring(package.sha256))

local current = plugin:PreInstall({ version = "graalpy3.13-25.3.4.1" })
assert(current.url == base .. "graal-25.3.4/graalpy3.13-25.3.4.1-linux-amd64.tar.gz", tostring(current.url))
assert(current.sha256 == string.rep("d", 64), tostring(current.sha256))

print("PASS: GraalPy constructed URLs survive a GitHub API rate limit")
