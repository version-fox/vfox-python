require("util")
function PLUGIN:PostInstall(ctx)
    if useUvBuild() then
        return uvBuildInstall(ctx)
    end

    if OS_TYPE == "windows" then
        return windowsInstall(ctx)
    else
        return linuxCompile(ctx)
    end
end
