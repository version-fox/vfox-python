require("util")
function PLUGIN:PreInstall(ctx)
    local version = ctx.version

    if version == "latest" then
        version = self:Available({})[1].version
    end

    if useUvBuild() then
        local package = uvBuildPreInstall(version)
        if package == nil or package.url == nil or package.url == "" or package.sha256 == nil or package.sha256 == "" then
            error("uv-build PreInstall did not provide required url and sha256 fields")
        end
        return package
    end

    if OS_TYPE == "windows" and not checkIsReleaseVersion(version) then
        error("The current version is not released")
        return
    end
    
    return {
       version = version,
    }
end
