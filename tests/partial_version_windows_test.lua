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

-- On Windows PreUse returns before the Unix health check. A partial request
-- must still be resolved before that early return, or `vfox use python@3.12`
-- reports the request as not installed.
local test = require("vfox.test")

local plugin = test.load({
    os = "windows",
    arch = "amd64",
    env = {},
})

local installed = {
    ["3.12.16"] = {
        name = "python",
        version = "3.12.16",
        path = "C:\\vfox\\cache\\python\\v-3.12.16",
    },
}

local function use(version)
    return plugin:PreUse({
        version = version,
        previousVersion = "",
        scope = "global",
        cwd = "C:\\src",
        installedSdks = installed,
    })
end

assert(use("3.12").version == "3.12.16", use("3.12").version)
assert(use("3.14").version == "3.14", use("3.14").version)

print("PASS: partial versions resolve in PreUse on Windows")
