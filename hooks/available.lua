require("util")
function PLUGIN:Available(ctx)
    if OS_TYPE == "windows" then
        return parseVersion()
    else
        return parseVersionFromPyenv()
    end
end