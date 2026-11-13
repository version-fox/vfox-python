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

require("util")
function PLUGIN:Available(ctx)
    if useUvBuild() then
        return parseVersionFromUvBuild()
    end

    if OS_TYPE == "windows" then
        local result = parseWindowsVersions()
        -- GraalPy is a second upstream. A GitHub API failure must not take the
        -- python.org list down with it.
        local ok, graalPy = pcall(parseGraalPyWindowsVersions)
        if ok then
            for _, item in ipairs(graalPy) do
                result[#result + 1] = item
            end
        else
            print("Warning: Could not list GraalPy releases: " .. tostring(graalPy))
        end
        return result
    else
        return parseVersionFromPyenv()
    end
end
