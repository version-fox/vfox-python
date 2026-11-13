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

-- A linked Python belongs to its owner. PreUse must recognise the version
-- directory's link and leave the installation alone instead of checking for
-- pip or rewriting the shebangs of the owner's scripts.
local test = require("vfox.test")

local plugin = test.load({
    os = "linux",
    arch = "amd64",
    env = {},
})

require("util")

local command
local output = "yes\n"
io.popen = function(value, mode)
    command = value
    local index = 0
    return {
        read = function()
            index = index + 1
            return index == 1 and output or nil
        end,
        close = function()
            return 0
        end,
    }
end

local versionPath = "/home/test/.vfox/cache/python/v-3.12.8-system"
assert(isLinkedPythonInstall(versionPath, "3.12.8-system") == true)
assert(command:find("test -L", 1, true) ~= nil, command)

local result = plugin:PreUse({
    version = "3.12.8-system",
    previousVersion = "",
    scope = "global",
    cwd = "/home/test",
    installedSdks = {
        ["3.12.8-system"] = {
            name = "python",
            version = "3.12.8-system",
            path = versionPath,
        },
    },
})
assert(result.version == "3.12.8-system", tostring(result.version))

output = ""
assert(isLinkedPythonInstall(versionPath, "3.12.8-system") == false)

print("PASS: linked Python versions skip the PreUse health check")
