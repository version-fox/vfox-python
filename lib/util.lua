local http = require("http")
local html = require("html")
local json = require("json")

-- get mirror
local PYTHON_URL = "https://www.python.org/ftp/python/"
local VFOX_PYTHON_MIRROR = os.getenv("VFOX_PYTHON_MIRROR")
if VFOX_PYTHON_MIRROR then
    PYTHON_URL = VFOX_PYTHON_MIRROR
    os.setenv("PYTHON_BUILD_MIRROR_URL_SKIP_CHECKSUM", 1)
    os.setenv("PYTHON_BUILD_MIRROR_URL", PYTHON_URL)
end

local version_vault_url = "https://version-vault.cdn.dog/python/pyenv"

-- request headers
local REQUEST_HEADERS = {
    ["User-Agent"] = "vfox"
}

-- download source
local DOWNLOAD_SOURCE = {
    MSI = PYTHON_URL .. "%s/python-%s.%s.msi",
    EXE = PYTHON_URL .. "%s/python-%s%s.exe",
    SOURCE = PYTHON_URL .. "%s/Python-%s.tar",
}

function checkIsReleaseVersion(version)
    local resp, err = http.head({
        url = DOWNLOAD_SOURCE.SOURCE:format(version, version) .. '.xz',
        headers = REQUEST_HEADERS
    })
    if err == nil and resp.status_code == 200 then
        return true
    end

    local resp, err = http.head({
        url = DOWNLOAD_SOURCE.SOURCE:format(version, version) .. '.bz2',
        headers = REQUEST_HEADERS
    })
    if err == nil and resp.status_code == 200 then
        return true
    end

    return false
end

function windowsInstall(ctx)
    local sdkInfo = ctx.sdkInfo['python']
    local path = sdkInfo.path
    local version = sdkInfo.version
    local url = getReleaseForWindows(version)
    local filename = url:match("[^/\\]+$")
    if string.sub(filename, -3) == "msi" then
        windowsInstallMsi(path, url, version, filename)
    elseif string.sub(filename, -3) == "exe" then
        windowsInstallExe(path, url, version, filename)
    end

end

function windowsInstallMsi(path, url, version, filename)
    -- WARNNING: 
    -- The msi installer for python 2.x must be downloaded to another directory
    -- it cannot be installed in the current directory.
    local qInstallFile = RUNTIME.pluginDirPath .. "\\" .. filename
    local qInstallPath = path

    -- download
    print("Downloading installer...")
    print("from:\t" .. url)
    print("to:\t" .. qInstallFile)
    local err = http.download_file({
        url = url,
        headers = REQUEST_HEADERS
    }, qInstallFile)

    if err ~= nil then
        error("Downloading installer failed")
    end

    -- Install msi
    print("Installing python...")
    local command = 'msiexec /quiet /a ' .. qInstallFile .. ' TargetDir=' .. qInstallPath
    local exitCode = os.execute(command)
    os.remove(qInstallFile)
    if exitCode ~= 0 then
        error("Install msi failed: " .. qInstallFile)
    end

    -- Install pip
    local ensurepipPath = qInstallPath .. "\\Lib\\ensurepip\\__init__.py"
    local file = io.open(ensurepipPath, "r")
    if file then
        io.close(file)
        print("Installing pip...")
        local command = qInstallPath .. '\\python -E -s -m ensurepip -U --default-pip > NUL'
        local exitCode = os.execute(command)
        if exitCode ~= 0 then
            error("Install pip failed. exit " .. exitCode)
        end
    end
end

function windowsInstallExe(path, url, version, filename)
    --- Attention system difference
    local qInstallFile = path .. "\\" .. filename
    local qInstallPath = path
    local msiPath = path .. '\\AttachedContainer'

    -- download
    print("Downloading installer...")
    print("from:\t" .. url)
    print("to:\t" .. qInstallFile)
    local err = http.download_file({
        url = url,
        headers = REQUEST_HEADERS
    }, qInstallFile)

    if err ~= nil then
        error("Downloading installer failed")
    end

    -- Extract
    print("Extracting installer...")
    local wixBin = RUNTIME.pluginDirPath .. '\\bin\\WiX\\dark.exe'
    local command = wixBin .. " -x " .. qInstallPath .. '\\ ' .. qInstallFile .. ' > NUL'
    local exitCode = os.execute(command)
    if exitCode ~= 0 then
        error("Extract failed")
    end

    -- Cleaning up ...
    print("Cleaning installer...")
    os.remove(qInstallFile)
    local files = {'appendpath.msi', 'launcher.msi', 'path.msi', 'pip.msi'}
    for _, file in ipairs(files) do
        os.remove(msiPath .. '\\' .. file)
    end

    -- Install msi
    print("Installing python...")
    local files = io.popen("dir /b " .. msiPath):lines()
    for file in files do
        if file:match("%.msi$") then
            local command = "msiexec /quiet /a " .. msiPath .. '\\' .. file .. " TargetDir=" .. qInstallPath
            local exitCode = os.execute(command)
            if exitCode ~= 0 then
                error("Install msi failed: " .. file)
            end
            os.remove(qInstallPath .. '\\' .. file)
        end
    end

    -- Install pip
    print("Installing pip...")
    local ensurepipPath = qInstallPath .. "\\Lib\\ensurepip\\__init__.py"
    local file = io.open(ensurepipPath, "r")
    if file then
        io.close(file)
        local command = qInstallPath .. '\\python -E -s -m ensurepip -U --default-pip > NUL'
        local exitCode = os.execute(command)
        if exitCode ~= 0 then
            error("Install pip failed. exit " .. exitCode)
        end
    end

    -- Define paths for executables based on installation path
    local pythonExePath = qInstallPath .. "\\python.exe"
    local pythonwExePath = qInstallPath .. "\\pythonw.exe"
    local venvlauncherExePath = qInstallPath .. "\\Lib\\venv\\scripts\\nt\\python.exe"

    local pattern = "(%d+)%.(%d+)"
    local major, minor = string.match(version, pattern)
    local majorMinor = major .. minor
    local majorDotMinor = major .. "." .. minor

    -- Copy Python executables with versioned names
    -- python.exe
    local files = {qInstallPath .. "\\python" .. major .. ".exe", qInstallPath .. "\\python" .. majorMinor .. ".exe",
                   qInstallPath .. "\\python" .. majorDotMinor .. ".exe"}
    for _, file in ipairs(files) do
        local command = 'copy /y ' .. pythonExePath .. ' ' .. file .. ' > NUL'
        os.execute(command)
    end

    -- pythonw.exe
    local files = {qInstallPath .. "\\pythonw" .. major .. ".exe", qInstallPath .. "\\pythonw" .. majorMinor .. ".exe",
                   qInstallPath .. "\\pythonw" .. majorDotMinor .. ".exe"}
    for _, file in ipairs(files) do
        local command = 'copy /y ' .. pythonwExePath .. ' ' .. file .. ' > NUL'
        os.execute(command)
    end

    -- Check if venvlauncher exists
    local file = io.open(venvlauncherExePath, "r")
    if file then
        io.close(file)
        -- python.exe
        local files = {qInstallPath .. "\\Lib\\venv\\scripts\\nt\\python" .. major .. ".exe",
                       qInstallPath .. "\\Lib\\venv\\scripts\\nt\\python" .. majorMinor .. ".exe",
                       qInstallPath .. "\\Lib\\venv\\scripts\\nt\\python" .. majorDotMinor .. ".exe",
                       qInstallPath .. "\\Lib\\venv\\scripts\\nt\\pythonw" .. major .. ".exe",
                       qInstallPath .. "\\Lib\\venv\\scripts\\nt\\pythonw" .. majorMinor .. ".exe",
                       qInstallPath .. "\\Lib\\venv\\scripts\\nt\\pythonw" .. majorDotMinor .. ".exe"}
        for _, file in ipairs(files) do
            local command = 'copy /y ' .. venvlauncherExePath .. ' ' .. file .. ' > NUL'
            os.execute(command)
        end
    end

end

local pyenvBranch = ""

function linuxCompile(ctx)
    local sdkInfo = ctx.sdkInfo['python']
    local path = sdkInfo.path
    local version = sdkInfo.version
    local pyenv_url = "https://github.com/pyenv/pyenv.git"
    local dest_pyenv_path = ctx.rootPath .. "/pyenv"
    local branch = ""
    if pyenvBranch ~= "" then
        branch = "--branch " .. pyenvBranch
    end
    local status = os.execute("git -c advice.detachedHead=false clone --depth 1 " .. branch .. " "  .. pyenv_url .. " " .. dest_pyenv_path)
    if status ~= 0 then
        error("git clone failed")
    end
    local pyenv_build_path = dest_pyenv_path .. "/plugins/python-build/bin/python-build"
    print("Building python ...")
    status = os.execute(pyenv_build_path .. " " .. version .. " " .. path)
    if status ~= 0 then
        error("python build failed")
    end
    print("Build python success!")

    -- Fix shebang lines in Python scripts after successful build
    fixShebangLines(path)

    print("Cleaning up ...")
    status = os.execute("rm -rf " .. dest_pyenv_path)
    if status ~= 0 then
        error("remove build tool failed")
    end
end

function getReleaseForWindows(version)
    local archType = RUNTIME.archType
    if archType == "386" then
        archType = ""
    end

    -- try get exe file
    local url = DOWNLOAD_SOURCE.EXE:format(version, version, '-' .. archType)
    local resp, err = http.head({
        url = url,
        headers = REQUEST_HEADERS
    })
    if err == nil and resp.status_code == 200 then
        return url
    end

    -- try get msi file
    local url = DOWNLOAD_SOURCE.MSI:format(version, version, archType)
    local resp, err = http.head({
        url = url,
        headers = REQUEST_HEADERS
    })
    if err == nil and resp.status_code == 200 then
        return url
    end
    print("url:\t" .. url)
    error("No available installer found for current version")
end

function fixHeaders() 
    REQUEST_HEADERS["User-Agent"] = "vfox v" .. RUNTIME.version;
end

function parseVersion()
    fixHeaders()

    local resp, err = http.get({
        url = PYTHON_URL,
        headers = REQUEST_HEADERS
    })
    if err ~= nil or resp.status_code ~= 200 then
        error("paring release info failed." .. err)
    end
    local result = {}
    html.parse(resp.body):find("a"):each(function(i, selection)
        local href = selection:attr("href")
        local sn = string.match(href, "^%d")
        local es = string.match(href, "/$")
        if sn and es then
            local vn = string.sub(href, 1, -2)
            if RUNTIME.osType == "windows" then
                if compare_versions(vn, "2.5.0") >= 0 then
                    table.insert(result, {
                        version = string.sub(href, 1, -2),
                        note = ""
                    })
                end
            else
                table.insert(result, {
                    version = vn,
                    note = ""
                })
            end
        end
    end)
    table.sort(result, function(a, b)
        return compare_versions(a.version, b.version) > 0
    end)
    return result
end

function compare_versions(v1, v2)
    local v1_parts = {}
    for part in string.gmatch(v1, "[^.]+") do
        table.insert(v1_parts, tonumber(part))
    end

    local v2_parts = {}
    for part in string.gmatch(v2, "[^.]+") do
        table.insert(v2_parts, tonumber(part))
    end

    for i = 1, math.max(#v1_parts, #v2_parts) do
        local v1_part = v1_parts[i] or 0
        local v2_part = v2_parts[i] or 0
        if v1_part > v2_part then
            return 1
        elseif v1_part < v2_part then
            return -1
        end
    end

    return 0
end

function parseVersionFromPyenv()
    fixHeaders()
    local resp, err = http.get({
        url = version_vault_url,
        headers = REQUEST_HEADERS
    })
    if err ~= nil or resp.status_code ~= 200 then
        error("paring release info failed." .. err)
    end
    local result = {}
    local jsonObj = json.decode(resp.body)

    local tagName = jsonObj.tagName;
    if tagName then
        pyenvBranch = tagName;
    end

    local versions = jsonObj.versions;

    local numericVersions = {}
    local namedVersions = {}

    for _, version in ipairs(versions) do
        if string.match(version, "^%d") then
            table.insert(numericVersions, version)
        else
            table.insert(namedVersions, version)
        end
    end

    table.sort(numericVersions, function(a, b)
        return compare_versions(a, b) > 0
    end)

    table.sort(namedVersions, function(a, b)
        return compare_versions(a, b) > 0
    end)

    for _, version in ipairs(numericVersions) do
        table.insert(result, {
            version = version,
            note = ""
        })
    end

    for _, version in ipairs(namedVersions) do
        table.insert(result, {
            version = version,
            note = ""
        })
    end

    return result
end

-- Fix shebang lines in Python scripts that point to temporary directories
function fixShebangLines(installPath)
    return fixShebangForVersion(installPath, nil)
end

-- Fix shebang lines for a specific Python version installation
function fixShebangForVersion(installPath, version)
    local versionInfo = version and (" for version " .. version) or ""
    print("Fixing shebang lines in Python scripts" .. versionInfo .. "...")

    local binPath = installPath .. "/bin"
    local pythonExecutable = installPath .. "/bin/python"

    -- Check if bin directory exists
    local binDirCheck = io.open(binPath, "r")
    if not binDirCheck then
        print("No bin directory found at " .. binPath .. ", skipping shebang fix")
        return false, 0
    end
    binDirCheck:close()

    -- Use find command to get all files in bin directory (macOS compatible)
    local findCmd = "find " .. binPath .. " -type f -perm +111 2>/dev/null"
    local findResult = io.popen(findCmd)
    if not findResult then
        print("Could not scan bin directory, skipping shebang fix")
        return false, 0
    end

    local fixedCount = 0
    local checkedCount = 0

    -- Process each executable file
    for filePath in findResult:lines() do
        if filePath and filePath ~= "" then
            checkedCount = checkedCount + 1
            -- Check if it's a Python script by examining the first line
            local file = io.open(filePath, "r")
            if file then
                local firstLine = file:read("*l")
                file:close()

                -- Check if it has a shebang line pointing to a temporary directory
                if firstLine and firstLine:match("^#!/.*%.version%-fox/temp/[^/]+/") then
                    local filename = filePath:match("([^/]+)$")
                    print("Fixing shebang in: " .. filename)
                    if fixSingleShebang(filePath, pythonExecutable) then
                        fixedCount = fixedCount + 1
                    end
                end
            end
        end
    end

    findResult:close()
    print("Shebang fix completed" .. versionInfo .. ". Checked " .. checkedCount .. " files, fixed " .. fixedCount .. " files.")
    return true, fixedCount
end

-- Fix shebang line in a single file
function fixSingleShebang(filePath, newPythonPath)
    -- Read the entire file
    local file = io.open(filePath, "r")
    if not file then
        print("Warning: Could not open file for reading: " .. filePath)
        return false
    end

    local content = file:read("*all")
    file:close()

    if not content or content == "" then
        print("Warning: File is empty: " .. filePath)
        return false
    end

    -- Replace the shebang line - match any path containing .version-fox/temp/
    local newContent, replacements = content:gsub("^#!/[^\n]*%.version%-fox/temp/[^/]+/[^\n]*", "#!" .. newPythonPath)

    if replacements == 0 then
        -- No replacement made, file might not have the problematic shebang
        return false
    end

    -- Create backup of original file
    local backupPath = filePath .. ".bak"
    local backupFile = io.open(backupPath, "w")
    if backupFile then
        backupFile:write(content)
        backupFile:close()
    end

    -- Write the file back
    local file = io.open(filePath, "w")
    if not file then
        print("Warning: Could not open file for writing: " .. filePath)
        return false
    end

    file:write(newContent)
    file:close()

    -- Preserve executable permissions
    local chmodResult = os.execute("chmod +x " .. filePath)
    if chmodResult ~= 0 then
        print("Warning: Could not set executable permissions on: " .. filePath)
    end

    -- Remove backup file if everything succeeded
    os.remove(backupPath)

    return true
end

-- Check Python installation health and return detailed status
function checkPythonHealth(installPath, version)
    local versionInfo = version and (" " .. version) or ""
    print("Checking Python" .. versionInfo .. " installation health...")

    local binPath = installPath .. "/bin"
    local pythonExecutable = installPath .. "/bin/python"

    local healthReport = {
        installPath = installPath,
        version = version,
        binPath = binPath,
        pythonExecutable = pythonExecutable,
        binDirExists = false,
        pythonExists = false,
        scriptsChecked = {},
        problemsFound = {},
        overallHealth = "unknown"
    }

    -- Check if bin directory exists
    local binDirCheck = io.open(binPath, "r")
    if not binDirCheck then
        healthReport.overallHealth = "critical"
        table.insert(healthReport.problemsFound, "Bin directory not found: " .. binPath)
        return healthReport
    end
    binDirCheck:close()
    healthReport.binDirExists = true

    -- Check if Python executable exists
    local pythonCheck = io.open(pythonExecutable, "r")
    if not pythonCheck then
        healthReport.overallHealth = "critical"
        table.insert(healthReport.problemsFound, "Python executable not found: " .. pythonExecutable)
        return healthReport
    end
    pythonCheck:close()
    healthReport.pythonExists = true

    -- Check critical Python scripts
    local criticalScripts = {"pip", "pip3", "easy_install"}
    local problemCount = 0

    for _, scriptName in ipairs(criticalScripts) do
        local scriptPath = binPath .. "/" .. scriptName
        local scriptInfo = {
            name = scriptName,
            path = scriptPath,
            exists = false,
            executable = false,
            shebangOk = false,
            shebangLine = ""
        }

        -- Check if script exists
        local scriptFile = io.open(scriptPath, "r")
        if scriptFile then
            scriptInfo.exists = true
            local firstLine = scriptFile:read("*l")
            scriptFile:close()

            if firstLine then
                scriptInfo.shebangLine = firstLine
                -- Check if shebang points to temporary directory
                if firstLine:match("^#!/.*%.version%-fox/temp/[^/]+/") then
                    scriptInfo.shebangOk = false
                    problemCount = problemCount + 1
                    table.insert(healthReport.problemsFound, scriptName .. " has problematic shebang: " .. firstLine)
                else
                    scriptInfo.shebangOk = true
                end
            end

            -- Check if script is executable
            local execCheck = os.execute("test -x " .. scriptPath .. " 2>/dev/null")
            scriptInfo.executable = (execCheck == 0)
            if not scriptInfo.executable then
                problemCount = problemCount + 1
                table.insert(healthReport.problemsFound, scriptName .. " is not executable")
            end
        else
            table.insert(healthReport.problemsFound, scriptName .. " not found")
        end

        table.insert(healthReport.scriptsChecked, scriptInfo)
    end

    -- Determine overall health
    if problemCount == 0 then
        healthReport.overallHealth = "healthy"
    elseif problemCount <= 2 then
        healthReport.overallHealth = "warning"
    else
        healthReport.overallHealth = "critical"
    end

    return healthReport
end

-- Fix shebang issues for all installed Python versions
function fixAllPythonVersions(sdkCachePath)
    print("Starting batch fix for all Python installations...")

    if not sdkCachePath then
        print("Error: SDK cache path not provided")
        return false
    end

    local pythonCachePath = sdkCachePath .. "/python"

    -- Check if Python cache directory exists
    local pythonCacheCheck = io.open(pythonCachePath, "r")
    if not pythonCacheCheck then
        print("No Python installations found at: " .. pythonCachePath)
        return false
    end
    pythonCacheCheck:close()

    -- Find all Python version directories
    local findCmd = "find " .. pythonCachePath .. " -maxdepth 1 -type d -name 'v-*' 2>/dev/null"
    local findResult = io.popen(findCmd)
    if not findResult then
        print("Could not scan Python installations directory")
        return false
    end

    local totalFixed = 0
    local versionsProcessed = 0

    for versionPath in findResult:lines() do
        if versionPath and versionPath ~= "" then
            local version = versionPath:match("v%-(.+)$")
            if version then
                versionsProcessed = versionsProcessed + 1
                print("\n--- Processing Python " .. version .. " ---")

                -- Check health first
                local healthReport = checkPythonHealth(versionPath, version)

                if healthReport.overallHealth == "healthy" then
                    print("Python " .. version .. " is healthy, skipping")
                else
                    print("Python " .. version .. " has " .. #healthReport.problemsFound .. " issues, fixing...")
                    local success, fixedCount = fixShebangForVersion(versionPath, version)
                    if success then
                        totalFixed = totalFixed + fixedCount
                    end
                end
            end
        end
    end

    findResult:close()

    print("\n=== Batch Fix Summary ===")
    print("Versions processed: " .. versionsProcessed)
    print("Total files fixed: " .. totalFixed)
    print("Batch fix completed!")

    return true
end
