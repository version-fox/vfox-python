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
local python_version = require("python_version")

--- Resolves a partial request such as "3.12" to the newest stable release that
--- the version list for this mode names. An exact request is returned without
--- reading the list. A partial request that matches nothing is returned as it
--- is, so the install reports the request the user typed.
local function resolvePartialVersion(plugin, requested)
    if not python_version.is_partial(requested) then
        return requested
    end
    local names = {}
    for _, item in ipairs(plugin:Available({})) do
        names[item.version] = true
    end
    return python_version.find_release(names, requested) or requested
end

function PLUGIN:PreInstall(ctx)
    local version = ctx.version

    if version == "latest" then
        version = self:Available({})[1].version
    end
    version = resolvePartialVersion(self, version)

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

    -- A release can have a source tarball and still have no Windows installer:
    -- 3.12.12 does. Stop here instead of after the download in PostInstall (issue #630).
    if OS_TYPE == "windows" and findWindowsInstaller(version) == nil then
        error(
            "Python "
                .. version
                .. " has no Windows installer on python.org. Install a version that `vfox search python` lists."
        )
    end

    return {
        version = version,
    }
end
