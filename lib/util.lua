local http = require("http")
local html = require("html")

-- get mirror
local PYTHON_URL = "https://www.python.org/ftp/python/"
local VFOX_PYTHON_MIRROR = os.getenv("VFOX_PYTHON_MIRROR")
if VFOX_PYTHON_MIRROR then
    PYTHON_URL = VFOX_PYTHON_MIRROR
    os.setenv("PYTHON_BUILD_MIRROR_URL_SKIP_CHECKSUM", 1)
    os.setenv("PYTHON_BUILD_MIRROR_URL", PYTHON_URL)
end

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

function linuxCompile(ctx)
    local sdkInfo = ctx.sdkInfo['python']
    local path = sdkInfo.path
    local version = sdkInfo.version
    local pyenv_url = "https://github.com/pyenv/pyenv.git"
    local dest_pyenv_path = ctx.rootPath .. "/pyenv"
    local status = os.execute("git clone " .. pyenv_url .. " " .. dest_pyenv_path)
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
function parseVersion()
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
