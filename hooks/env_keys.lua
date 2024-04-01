require("util")
function PLUGIN:EnvKeys(ctx)
    local mainPath = ctx.path
    if RUNTIME.osType == "windows" then
        return {
            {
                key = "PATH",
                value = mainPath,
            },
            {
                key = "PATH",
                value = mainPath .. "\\Scripts"
            }
        }
    else
        return {
            {
                key = "PATH",
                value = mainPath .. "/bin"
            }
        }
    end
end