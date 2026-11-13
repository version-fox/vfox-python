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

-- .python-version is shared with pyenv, uv and asdf. The hook selects an
-- installed name, including the source-suffixed names Detect creates, and
-- leaves the current version alone when the request is not installed.
local test = require("vfox.test")

local plugin = test.load({
    os = "linux",
    arch = "amd64",
    env = {},
})

assert(PLUGIN.legacyFilenames[1] == ".python-version", "metadata must register .python-version")

local fixtures = RUNTIME.pluginDirPath .. "/tests/fixtures/"

local function parse(file, installed, strategy)
    return plugin:ParseLegacyFile({
        filepath = fixtures .. file,
        filename = ".python-version",
        strategy = strategy or "specified",
        installedVersions = installed,
    })
end

local result = parse("python-version", { "3.12.9", "3.12.8-system", "3.11.9" })
assert(result.version == "3.12.9", tostring(result.version))

result = parse("python-version", { "3.12.8-system", "3.11.9" })
assert(result.version == "3.12.8-system", tostring(result.version))

result = parse("python-version-freethreaded", { "3.12.8", "3.12.8t-system" })
assert(result.version == "3.12.8t-system", tostring(result.version))

result = parse("python-version-system", { "3.11.9-system", "3.12.3-system" })
assert(result.version == "3.12.3-system", tostring(result.version))

-- A release line follows the rule vfox use follows: 3.12 in a .python-version
-- file never selects a free-threaded or pre-release install.
result = parse("python-version", { "3.12.9t", "3.12.8" })
assert(result.version == "3.12.8", tostring(result.version))

result = parse("python-version", { "3.12.17a1" })
assert(result.version == nil or result.version == "", tostring(result.version))

result = parse("python-version", { "3.12.8-opt" })
assert(result.version == "3.12.8-opt", tostring(result.version))

result = parse("python-version-pypy", { "3.10.14" })
assert(result.version == nil or result.version == "", tostring(result.version))

result = parse("python-version-pypy", { "3.10.14" }, "latest_installed")
assert(result.version == "3.10.14", tostring(result.version))

print("PASS: .python-version requests and installed-name matching")
