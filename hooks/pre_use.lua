require("util")

-- PreUse hook: Called before switching to a Python version
-- This ensures the target version is healthy and has correct shebang lines
function PLUGIN:PreUse(ctx)
    -- Only process on Unix systems (Windows doesn't have shebang issues)
    if OS_TYPE == "windows" then
        return {
            version = ctx.version
        }
    end

    local version = ctx.version
    local previousVersion = ctx.previousVersion
    local scope = ctx.scope
    local cwd = ctx.cwd
    local installedSdks = ctx.installedSdks

    print("Preparing Python " .. version .. " for use...")

    -- Find the target version in installed versions
    local targetVersion = nil
    for versionKey, sdkInfo in pairs(installedSdks) do
        if versionKey == version then
            targetVersion = sdkInfo
            break
        end
    end

    if not targetVersion then
        print("Warning: Target version " .. version .. " not found in installed versions")
        return {
            version = version
        }
    end

    local installPath = targetVersion.path
    print("Checking Python installation at: " .. installPath)

    -- Perform health check
    local healthReport = checkPythonHealth(installPath, version)
    
    -- Report health status and fix if needed
    local needsRecheck = false

    if healthReport.overallHealth == "healthy" then
        print("Python " .. version .. " is healthy and ready to use")
    elseif healthReport.overallHealth == "warning" then
        print("Python " .. version .. " has minor issues:")
        for _, problem in ipairs(healthReport.problemsFound) do
            print("  - " .. problem)
        end
        print("Attempting to fix issues...")

        -- Fix shebang issues
        local success, fixedCount = fixShebangForVersion(installPath, version)
        if success and fixedCount > 0 then
            print("Fixed " .. fixedCount .. " shebang issues")
            needsRecheck = true
        end
    elseif healthReport.overallHealth == "critical" then
        print("Python " .. version .. " has critical issues:")
        for _, problem in ipairs(healthReport.problemsFound) do
            print("  - " .. problem)
        end

        if #healthReport.problemsFound > 0 then
            print("Attempting to fix critical issues...")
            local success, fixedCount = fixShebangForVersion(installPath, version)
            if success and fixedCount > 0 then
                print("Fixed " .. fixedCount .. " critical issues")
                needsRecheck = true
            else
                print("Some issues may require manual intervention")
            end
        end
    end

    -- Only perform final health check if we made fixes
    if needsRecheck then
        print("Verifying fixes...")
        local finalHealthReport = checkPythonHealth(installPath, version)
        if finalHealthReport.overallHealth == "healthy" then
            print("Python " .. version .. " is now ready for use")
        else
            print("Python " .. version .. " still has some issues but should be usable")
            if #finalHealthReport.problemsFound > 0 then
                print("Remaining issues:")
                for _, problem in ipairs(finalHealthReport.problemsFound) do
                    print("  - " .. problem)
                end
            end
        end
    end

    -- Return the version in the correct format
    return {
        version = version
    }
end
