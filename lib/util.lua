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

local version_vault_url = "https://vault.vfox.dev/python/pyenv"
local uv_build_vault_url = "https://vault.vfox.dev/python/uv-build"
local UV_BUILD_GITHUB_RELEASE_PATTERN = "/releases/download/([^/]+)/([^/]+)$"
local URL_ENCODED_DOT = "%%2[eE]"

-- request headers
local REQUEST_HEADERS = {
    ["User-Agent"] = "vfox"
}

-- pip.cmd lives under Scripts, so %~dp0..\python.exe resolves to the install root's python.exe.
-- Windows command scripts conventionally use CRLF line endings.
local WINDOWS_PIP_SHIM_CONTENT = "@echo off\r\n\"%~dp0..\\python.exe\" -m pip %*\r\n"

local UV_BUILD_ENV = "VFOX_PYTHON_USE_UV_BUILD"
local UV_BUILD_MIRROR_ENV = "VFOX_PYTHON_UV_BUILD_MIRROR"

-- download source
local DOWNLOAD_SOURCE = {
    MSI = PYTHON_URL .. "%s/python-%s%s.msi",
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

function useUvBuild()
    local value = os.getenv(UV_BUILD_ENV)
    if value == nil then
        return false
    end
    value = string.lower(value)
    return value == "1" or value == "true" or value == "yes" or value == "on"
end

local function containsTraversalSegment(value)
    local normalizedValue = string.gsub(value, "\\", "/")
    if string.find(normalizedValue, URL_ENCODED_DOT) then
        return true
    end
    for segment in string.gmatch(normalizedValue, "[^/]+") do
        if segment == ".." then
            return true
        end
    end
    return false
end

local function findUnsupportedControlCharacter(value)
    local firstControlCharPos = nil
    for _, char in ipairs({ "\r", "\n", string.char(0) }) do
        local position = string.find(value, char, 1, true)
        if position and (firstControlCharPos == nil or position < firstControlCharPos) then
            firstControlCharPos = position
        end
    end
    return firstControlCharPos
end

local function shellQuote(value)
    local controlCharStart = findUnsupportedControlCharacter(value)
    if controlCharStart then
        error("Path contains unsupported control character at position " .. controlCharStart)
    end
    if containsTraversalSegment(value) then
        error("Path contains unsupported traversal segment: " .. value)
    end

    if RUNTIME.osType == "windows" or OS_TYPE == "windows" then
        if string.find(value, '"', 1, true) then
            error("Path contains unsupported quote character: " .. value)
        end
        return '"' .. value .. '"'
    end

    return "'" .. string.gsub(value, "'", "'\\''") .. "'"
end

local function powerShellQuote(value)
    local controlCharStart = findUnsupportedControlCharacter(value)
    if controlCharStart then
        error("PowerShell argument contains unsupported control character at position " .. controlCharStart)
    end
    if containsTraversalSegment(value) then
        error("PowerShell argument contains unsupported traversal segment: " .. value)
    end
    -- The generated script is passed to powershell through cmd as a double-quoted -Command argument.
    if string.find(value, '"', 1, true) then
        error("PowerShell argument contains double quote which conflicts with -Command wrapper: " .. value)
    end
    -- PowerShell single-quoted strings escape embedded single quotes by doubling them.
    return "'" .. string.gsub(value, "'", "''") .. "'"
end

local function powerShellCommand(script)
    -- Windows PowerShell is available by default on supported Windows targets.
    return "powershell -NoProfile -NonInteractive -ExecutionPolicy RemoteSigned -Command " .. shellQuote(script)
end

local function powerShellPythonCommand(pythonExe, pythonArgs)
    local scriptParts = { "&", powerShellQuote(pythonExe) }
    for _, arg in ipairs(pythonArgs) do
        table.insert(scriptParts, powerShellQuote(arg))
    end
    return powerShellCommand(table.concat(scriptParts, " "))
end

local function startsWith(value, prefix)
    return string.sub(value, 1, string.len(prefix)) == prefix
end

local function trimTrailingSlash(value)
    return string.gsub(value, "/+$", "")
end

local function isNilOrEmpty(value)
    return value == nil or value == ""
end

local function isHttpsUrl(value)
    return type(value) == "string" and startsWith(value, "https://") and not string.find(value, "[\r\n%z]")
end

local function commandSucceeded(status)
    return status == 0 or status == true
end

local function startsWithPath(value, prefix)
    if value == prefix then
        return true
    end
    local nextChar = string.sub(value, string.len(prefix) + 1, string.len(prefix) + 1)
    return startsWith(value, prefix) and (nextChar == "/" or nextChar == "\\")
end

local function runtimeOs()
    local osType = RUNTIME.osType or OS_TYPE
    osType = string.lower(osType or "")
    if osType == "darwin" or osType == "macos" then
        return "darwin"
    elseif osType == "windows" then
        return "windows"
    elseif osType == "linux" then
        return "linux"
    end
    return osType
end

local function runtimeArch()
    local archType = string.lower(RUNTIME.archType or "")
    if archType == "amd64" or archType == "x64" or archType == "x86_64" then
        return "x86_64"
    elseif archType == "arm64" or archType == "aarch64" then
        return "aarch64"
    elseif archType == "armv7" or archType == "armv7l" then
        return "armv7"
    elseif archType == "386" or archType == "i386" or archType == "x86" then
        return "x86"
    end
    return archType
end

local function runtimeLibc(osType)
    local configuredLibc = os.getenv("VFOX_PYTHON_UV_LIBC")
    if configuredLibc and configuredLibc ~= "" then
        return configuredLibc
    end

    if osType ~= "linux" then
        return "none"
    end

    local handle = io.popen("ldd --version 2>&1")
    if handle then
        local output = handle:read("*a") or ""
        handle:close()
        if string.find(string.lower(output), "musl", 1, true) then
            return "musl"
        end
    else
        print("Warning: Could not run ldd while detecting libc")
    end

    local muslLibs = {
        "/lib/ld-musl-x86_64.so.1",
        "/lib/ld-musl-aarch64.so.1",
        "/lib/ld-musl-armhf.so.1",
        "/usr/lib/libc.musl-x86_64.so.1",
        "/usr/lib/libc.musl-aarch64.so.1",
        "/usr/lib/libc.musl-armhf.so.1"
    }
    for _, muslLib in ipairs(muslLibs) do
        local file = io.open(muslLib, "r")
        if file then
            file:close()
            return "musl"
        end
    end

    local gnuCheck = io.popen("getconf GNU_LIBC_VERSION 2>/dev/null")
    if gnuCheck then
        local output = gnuCheck:read("*a") or ""
        gnuCheck:close()
        if output ~= "" then
            return "gnu"
        end
    end

    print("Warning: Could not detect libc, using gnu as default. Set VFOX_PYTHON_UV_LIBC to override.")
    return "gnu"
end

local function getUvBuildPlatform()
    local osType = runtimeOs()
    return osType, runtimeArch(), runtimeLibc(osType)
end

local function buildUvBuildUrl(osType, archType, libc)
    if osType == nil or archType == nil or libc == nil then
        osType, archType, libc = getUvBuildPlatform()
    end
    local query = "?os=" .. osType .. "&arch=" .. archType
    if libc ~= nil and libc ~= "" and libc ~= "none" then
        query = query .. "&libc=" .. libc
    end
    return uv_build_vault_url .. query
end

local function uvBuildVersion(build)
    if build.display_version ~= nil then
        return build.display_version
    end
    if build.version == nil then
        return nil
    end
    if build.variant == "freethreaded" then
        return build.version .. "t"
    end
    return build.version
end

local function isSupportedUvBuild(build)
    local implementation = build.implementation or build.name
    if implementation ~= "cpython" then
        return false
    end
    if build.version == nil then
        return false
    end
    if build.arch and build.arch.variant ~= nil then
        return false
    end
    if build.variant ~= nil and build.variant ~= "default" and build.variant ~= "freethreaded" then
        return false
    end
    if not isHttpsUrl(build.url) then
        return false
    end
    return true
end

local function uvBuildSha256(build)
    if type(build.asset) ~= "table" or type(build.asset.sha256) ~= "string" then
        return nil
    end

    local sha256 = string.lower(build.asset.sha256)
    if string.match(sha256, "^[0-9a-f]+$") and string.len(sha256) == 64 then
        return sha256
    end

    error("Invalid uv-build sha256 for " .. build.url)
end

local function uvBuildAssetName(build)
    if type(build.filename) == "string" then
        return string.lower(build.filename)
    end
    if type(build.url) == "string" then
        return string.lower(build.url)
    end
    return ""
end

local function isSupportedArchiveName(name)
    return string.sub(name, -7) == ".tar.gz" or
        string.sub(name, -4) == ".tgz" or
        string.sub(name, -7) == ".tar.xz" or
        string.sub(name, -8) == ".tar.bz2" or
        string.sub(name, -4) == ".zip" or
        string.sub(name, -3) == ".7z"
end

local function uvBuildAssetPriority(build)
    local name = uvBuildAssetName(build)
    if not isSupportedArchiveName(name) then
        return 90
    end
    if string.find(name, "install_only_stripped", 1, true) then
        return 10
    end
    if string.find(name, "install_only", 1, true) then
        return 20
    end
    if string.find(name, "pgo+lto-full", 1, true) or string.find(name, "pgo%2blto-full", 1, true) then
        return 30
    end
    if not string.find(name, "debug", 1, true) then
        return 40
    end
    return 90
end

local function uvBuildDownloadUrl(build)
    if not isHttpsUrl(build.url) then
        error("Invalid uv-build download URL")
    end

    local mirror = os.getenv(UV_BUILD_MIRROR_ENV)
    if mirror == nil or mirror == "" then
        return build.url
    end
    if not isHttpsUrl(mirror) then
        error(UV_BUILD_MIRROR_ENV .. " must be an https URL")
    end

    local release, filename = string.match(build.url, UV_BUILD_GITHUB_RELEASE_PATTERN)
    if release == nil or filename == nil then
        error("Unable to rewrite uv-build download URL for mirror; expected a GitHub release download URL: " .. build.url)
    end

    return trimTrailingSlash(mirror) .. "/" .. release .. "/" .. filename
end

local function getUvBuilds(osType, archType, libc)
    fixHeaders()
    local resp, err = http.get({
        url = buildUvBuildUrl(osType, archType, libc),
        headers = REQUEST_HEADERS
    })
    if err ~= nil or resp.status_code ~= 200 then
        local statusCode = resp and resp.status_code or "none"
        error("parsing uv-build release info failed. Status: " .. statusCode .. ", Error: " .. (err or "none"))
    end

    local jsonObj = json.decode(resp.body)
    return jsonObj.items or jsonObj.versions or {}
end

local function findUvBuild(version)
    local osType, archType, libc = getUvBuildPlatform()
    local selectedBuild = nil
    local selectedPriority = nil
    for _, build in ipairs(getUvBuilds(osType, archType, libc)) do
        if isSupportedUvBuild(build) and uvBuildVersion(build) == version then
            local priority = uvBuildAssetPriority(build)
            if selectedBuild == nil or priority < selectedPriority then
                selectedBuild = build
                selectedPriority = priority
            end
        end
    end
    if selectedBuild ~= nil then
        return selectedBuild
    end
    error("No uv-build prebuilt Python found for version " .. version .. " on " .. osType .. "/" .. archType .. "/" .. libc)
end

local function pathExists(path)
    local file = io.open(path, "r")
    if file then
        file:close()
        return true
    end
    return false
end

local function ensureWindowsDirectory(path)
    local command = powerShellCommand("New-Item -ItemType Directory -Force -Path " .. powerShellQuote(path) .. " | Out-Null")
    local exitCode = os.execute(command)
    if not commandSucceeded(exitCode) then
        error("Failed to create directory: " .. path .. ". Exit code: " .. tostring(exitCode))
    end
end

local function writeWindowsFile(path, content)
    local file = io.open(path, "w")
    if not file then
        error("Failed to write file: " .. path .. ". Check directory permissions and available disk space.")
    end
    file:write(content)
    file:close()
end

local function createWindowsPipShim(scriptsPath)
    ensureWindowsDirectory(scriptsPath)

    -- Match the common pip script entry points created by ensurepip.
    local shims = { "pip.cmd", "pip3.cmd" }
    for _, shim in ipairs(shims) do
        writeWindowsFile(scriptsPath .. "\\" .. shim, WINDOWS_PIP_SHIM_CONTENT)
    end
end

local function windowsPipCommandExists(scriptsPath)
    return pathExists(scriptsPath .. "\\pip.exe") or pathExists(scriptsPath .. "\\pip.cmd")
end

local function ensureWindowsUvBuildPip(path)
    if runtimeOs() ~= "windows" then
        return
    end

    local pythonExe = path .. "\\python.exe"
    local scriptsPath = path .. "\\Scripts"
    if not pathExists(pythonExe) then
        error("Cannot install pip: python.exe was not found at " .. pythonExe)
    end
    -- If Scripts does not exist yet, pathExists returns false and setup continues.
    if windowsPipCommandExists(scriptsPath) then
        return
    end

    if not pathExists(path .. "\\Lib\\ensurepip\\__init__.py") then
        print("Warning: uv-build Python does not include ensurepip; pip will not be available.")
        return
    end

    print("Installing pip for uv-build Python on Windows...")
    local command = powerShellPythonCommand(pythonExe, { "-E", "-s", "-m", "ensurepip", "-U", "--default-pip" })
    local exitCode = os.execute(command)
    if not commandSucceeded(exitCode) then
        error("ensurepip failed while installing pip. Exit code: " .. tostring(exitCode))
    end

    if windowsPipCommandExists(scriptsPath) then
        return
    end

    local windowsBundledPath = path .. "\\Lib\\ensurepip\\_bundled"
    local reinstallCommand = powerShellPythonCommand(pythonExe, {
        "-E", "-s", "-m", "pip", "install", "--force-reinstall", "--no-index",
        "--find-links", windowsBundledPath, "pip"
    })
    local reinstallExitCode = os.execute(reinstallCommand)
    if not commandSucceeded(reinstallExitCode) then
        error("pip force-reinstall failed while creating pip scripts. Exit code: " .. tostring(reinstallExitCode))
    end

    local verifyCommand = powerShellPythonCommand(pythonExe, { "-E", "-s", "-m", "pip", "--version" })
    local verifyExitCode = os.execute(verifyCommand)
    if not commandSucceeded(verifyExitCode) then
        error("pip module is not available after installation attempts. Exit code: " .. tostring(verifyExitCode))
    end

    if not windowsPipCommandExists(scriptsPath) then
        createWindowsPipShim(scriptsPath)
    end
end

function resolvePythonInstallPath(installPath, version)
    if pathExists(installPath .. "/bin") or pathExists(installPath .. "\\python.exe") then
        return installPath
    end

    -- vfox stores SDK payloads under python-<version>; uv-build archives unpack into that payload directory.
    local uvBuildPath = installPath .. "/python-" .. version
    if pathExists(uvBuildPath .. "/bin") or pathExists(uvBuildPath .. "\\python.exe") then
        return uvBuildPath
    end

    return installPath
end

function uvBuildPreInstall(version)
    local ok, value = pcall(function()
        local build = findUvBuild(version)
        -- Return url/sha256 so vfox core performs download, checksum verification, and archive extraction.
        return {
            version = version,
            url = uvBuildDownloadUrl(build),
            headers = REQUEST_HEADERS,
            sha256 = uvBuildSha256(build),
            note = "uv-build",
        }
    end)
    if not ok then
        local err = value
        error("uv-build PreInstall failed: " .. tostring(err))
    end
    local uvBuildPackage = value
    if uvBuildPackage == nil then
        error("uv-build PreInstall did not provide install metadata")
    end
    if isNilOrEmpty(uvBuildPackage.url) then
        error("uv-build PreInstall failed: url is required")
    end
    if isNilOrEmpty(uvBuildPackage.sha256) then
        error("uv-build PreInstall failed: sha256 is required")
    end
    return uvBuildPackage
end

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

function uvBuildInstall(ctx)
    local sdkInfo = ctx.sdkInfo['python']
    local path = sdkInfo.path
    local version = sdkInfo.version

    if not ctx.rootPath or ctx.rootPath == "" then
        error("vfox root path is required for uv-build installation")
    end
    if not startsWithPath(path, ctx.rootPath) then
        error("Install path is outside the expected vfox root path: " .. path)
    end

    local extractedPath = resolvePythonInstallPath(path, version)
    if not pathExists(extractedPath .. "/bin/python") and not pathExists(extractedPath .. "\\python.exe") then
        error("Extracted uv-build archive does not contain a Python executable at expected location: " .. extractedPath)
    end

    if OS_TYPE ~= "windows" then
        fixShebangLines(extractedPath)
    else
        ensureWindowsUvBuildPip(extractedPath)
    end

    print("Install Python uv-build success!")
end

function getReleaseForWindows(version)
    local archType = RUNTIME.archType
    local exeArchSuffix = ""
    local msiArchSuffix = ""
    if archType ~= "386" then
        exeArchSuffix = "-" .. archType
        msiArchSuffix = "." .. archType
    end

    -- try get exe file
    local url = DOWNLOAD_SOURCE.EXE:format(version, version, exeArchSuffix)
    local resp, err = http.head({
        url = url,
        headers = REQUEST_HEADERS
    })
    if err == nil and resp.status_code == 200 then
        return url
    end

    -- try get msi file
    local url = DOWNLOAD_SOURCE.MSI:format(version, version, msiArchSuffix)
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

function parseVersionFromUvBuild()
    local result = {}
    local seen = {}
    for _, build in ipairs(getUvBuilds()) do
        if isSupportedUvBuild(build) then
            local version = uvBuildVersion(build)
            if not seen[version] then
                table.insert(result, {
                    version = version,
                    note = ""
                })
                seen[version] = true
            end
        end
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
