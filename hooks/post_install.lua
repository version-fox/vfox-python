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
local pep514 = require("pep514")
function PLUGIN:PostInstall(ctx)
    local result
    local version = ctx.sdkInfo["python"].version
    if isGraalPyVersion(version) and parseGraalPyVersion(version) then
        result = graalPyInstall(ctx)
    elseif useUvBuild() then
        result = uvBuildInstall(ctx)
    elseif OS_TYPE == "windows" then
        result = windowsInstall(ctx)
    else
        result = linuxCompile(ctx)
    end

    pep514.register(ctx)
    return result
end
