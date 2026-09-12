require("util")
function PLUGIN:Available(ctx)
    if useUvBuild() then
        return parseVersionFromUvBuild()
    end

    if OS_TYPE == "windows" then
        return parseWindowsVersions()
    else
        return parseVersionFromPyenv()
    end
end
