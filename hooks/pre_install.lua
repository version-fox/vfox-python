require("util")
function PLUGIN:PreInstall(ctx)
    local version = ctx.version

    if version == "latest" then
        version = self:Available({})[1].version
    end

    if useUvBuild() then
        local uvBuildPackage = uvBuildPreInstall(version)
        if uvBuildPackage == nil or uvBuildPackage.url == nil or uvBuildPackage.url == "" or uvBuildPackage.sha256 == nil or uvBuildPackage.sha256 == "" then
            error("uv-build PreInstall did not provide required url and sha256 fields")
        end
        return uvBuildPackage
    end

    if OS_TYPE == "windows" and not checkIsReleaseVersion(version) then
        error("The current version is not released")
        return
    end
    
    return {
       version = version,
    }
end
