require("util")
function PLUGIN:PreInstall(ctx)
    local version = ctx.version

    if version == "latest" then
        version = self:Available({})[1].version
    end

    if OS_TYPE == "windows" and not checkIsReleaseVersion(version) then
        error("The current version is not released")
        return
    end
    
    return {
       version = version,
    }
end
