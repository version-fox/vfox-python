require("util")
function PLUGIN:PostInstall(ctx)
    if OS_TYPE == "windows" then
        return windowsCompile(ctx)
    else
        return linuxCompile(ctx)
    end
end