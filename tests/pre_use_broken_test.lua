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

-- A Python whose bin directory is missing cannot be run. PreUse must stop with
-- a reinstall hint instead of reporting "Now using" (issue #642).
local test = require("vfox.test")

local plugin = test.load({
    os = "linux",
    arch = "amd64",
    env = {},
})

require("util")

-- Not a link, so the health check runs. The directory does not exist.
local output = ""
io.popen = function()
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

local ok, err = pcall(function()
    return plugin:PreUse({
        version = "3.12.13",
        previousVersion = "",
        scope = "global",
        cwd = "/home/test",
        installedSdks = {
            ["3.12.13"] = {
                name = "python",
                version = "3.12.13",
                path = "/nonexistent-vfox-test/cache/python/v-3.12.13",
            },
        },
    })
end)
assert(not ok, "a Python without a bin directory must not be selected")
assert(tostring(err):find("is not installed correctly", 1, true), tostring(err))
assert(tostring(err):find("Bin directory not found", 1, true), tostring(err))
assert(tostring(err):find("vfox install python@3.12.13", 1, true), tostring(err))

print("PASS: PreUse refuses a Python install with no bin directory")
