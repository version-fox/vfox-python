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

-- Windows PreInstall stops before the download when python.org publishes no
-- installer for the version (issue #630). 3.12.12 has a source tarball only.
local test = require("vfox.test")

local base = "https://www.python.org/ftp/python/"
local publishedInstallers = {
    [base .. "3.12.10/python-3.12.10-amd64.exe"] = true,
}
local requests = {}
local plugin = test.load({
    os = "windows",
    arch = "amd64",
    env = {},
    http = function(request)
        requests[#requests + 1] = request.method .. " " .. request.url
        assert(request.method == "HEAD", request.method)
        -- Every source tarball exists; only the installers listed above do.
        if request.url:match("/Python%-[%d%.]+%.tar%.xz$") or publishedInstallers[request.url] then
            return { status_code = 200 }
        end
        return { status_code = 404 }
    end,
})

local ok, err = pcall(function()
    return plugin:PreInstall({ version = "3.12.12" })
end)
assert(not ok, "3.12.12 has no Windows installer and must not be installed")
assert(tostring(err):find("has no Windows installer on python.org", 1, true), tostring(err))
-- The refusal happens before any download: only HEAD requests were sent.
for _, request in ipairs(requests) do
    assert(request:sub(1, 5) == "HEAD ", request)
end

local package = plugin:PreInstall({ version = "3.12.10" })
assert(package.version == "3.12.10", tostring(package.version))

print("PASS: Windows PreInstall rejects a version without an installer before download")
