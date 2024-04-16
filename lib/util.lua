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
    --- TODO support zip or web-based installers
    WEB_BASED = PYTHON_URL .. "%s/python-%s%s-webinstall.exe",
    ZIP = PYTHON_URL .. "%s/python-%s-embed-%s.zip",
    MSI = "",
    --- Currently only exe installers are supported
    EXE = PYTHON_URL .. "%s/python-%s%s.exe",
    SOURCE = PYTHON_URL .. "%s/Python-%s.tar.xz"
}

function checkIsReleaseVersion(version)
    local resp, err = http.head({
        url = DOWNLOAD_SOURCE.SOURCE:format(version, version),
        headers = REQUEST_HEADERS
    })
    if err ~= nil or resp.status_code ~= 200 then
        return false
    end
    return true
end
function windowsCompile(ctx)
    local sdkInfo = ctx.sdkInfo['python']
    local path = sdkInfo.path
    local version = sdkInfo.version
    local url, filename = checkAvailableReleaseForWindows(version)
    
    --- Attention system difference
    local qInstallFile = path .. "\\" .. filename
    local qInstallPath = path

    print("Downloading installer")
    print("from:\t" .. url)
    print("to:\t" .. qInstallFile)
    local resp, err = http.get({
        url = url,
        headers = REQUEST_HEADERS
    })

    if err ~= nil or resp.status_code ~= 200 then
        error("Downloading installer failed")
    else
        local file = io.open(qInstallFile, "w")
        file:write(resp.body)
        local size = file:seek("end")
        file:close()
        print("size:\t" .. size .. " bytes")
    end

    --local exitCode = os.execute('msiexec /quiet /a "' .. qInstallFile .. '" TargetDir="' .. qInstallPath .. '"')
    print("Installing python, please wait patiently for a while, about two minutes.")
    local exitCode = os.execute(qInstallFile .. ' /quiet InstallAllUsers=0 PrependPath=0 TargetDir=' .. qInstallPath)
    if exitCode ~= 0 then
        error("error installing python")
    end
    print("Cleaning up ...")
    os.remove(qInstallFile)
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
function checkAvailableReleaseForWindows(version)
    local archType = RUNTIME.archType
    if archType == "386" then
        archType = ""
    else
        archType = "-" .. archType
    end
    --- Currently only exe installers are supported
    --- TODO support zip or web-based installers
    local url = DOWNLOAD_SOURCE.EXE:format(version, version, archType)
    local resp, err = http.head({
        url = url,
        headers = REQUEST_HEADERS
    })
    if err ~= nil or resp.status_code ~= 200 then
        error("No available installer found for current version")
    end
    return url, "python-" .. version .. archType .. ".exe"
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
                if compare_versions(vn, "3.5.0") >= 0 then
                    table.insert(result, {
                        version = string.sub(href, 1, -2),
                        note = "",
                    })
                end
            else
                table.insert(result, {
                    version = vn,
                    note = "",
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
