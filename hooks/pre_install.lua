require("util")
function PLUGIN:PreInstall(ctx)
    local version = ctx.version
    if version == "latest" then
        version = self:Available({})[1].version
    end
    if not checkIsReleaseVersion(version) then
        error("The current version is not released")
        return
    end
    if OS_TYPE == "windows" then
        local url, filename = checkAvailableReleaseForWindows(version)
        return {
            version = version,
            url = url,
            note = filename
        }
    else
        return {
            version = version,
        }
    end
end