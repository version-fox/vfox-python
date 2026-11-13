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
function PLUGIN:PreInstall(ctx)
    local version = ctx.version

    if version == "latest" then
        version = self:Available({})[1].version
    end

    if useUvBuild() then
        if isGraalPyVersion(version) then
            error(
                "uv-build provides CPython only; unset VFOX_PYTHON_USE_UV_BUILD to install "
                    .. version
                    .. " from pyenv or Oracle's GraalPy releases."
            )
        end
        return uvBuildPreInstall(version)
    end

    if isGraalPyVersion(version) then
        if parseGraalPyVersion(version) then
            return graalPyPreInstall(version)
        elseif OS_TYPE == "windows" then
            -- The legacy graalpython-* names have no Windows assets.
            error("Unsupported GraalPy version on Windows: " .. version)
        end
        -- On Linux and macOS the legacy graalpython-* names still go through
        -- pyenv's python-build definition.
    end

    if OS_TYPE == "windows" and not checkIsReleaseVersion(version) then
        error("The current version is not released")
        return
    end

    return {
        version = version,
    }
end
