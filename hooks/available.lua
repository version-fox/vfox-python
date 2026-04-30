require("util")
function PLUGIN:Available(ctx)
    if useUvBuild() then
        return parseVersionFromUvBuild()
    end

    if OS_TYPE == "windows" then
        return parseVersion()
    else
        return parseVersionFromPyenv()
    end
end
