require("util")
function PLUGIN:PostInstall(ctx)
    if OS_TYPE == "windows" then
        return windowsInstall(ctx)
    else
        return linuxCompile(ctx)
    end
end
