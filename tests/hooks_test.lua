package.path = "./lib/?.lua;" .. package.path
PLUGIN = {}
RUNTIME = { osType = "windows", archType = "amd64", version = "1.0.12" }
OS_TYPE = "windows"
os.getenv = function()
    return nil
end
local state = {}
state.links = {
    "https://www.python.org/ftp/python/3.12.8/python-3.12.8-amd64.exe",
    "https://www.python.org/ftp/python/3.12.8/python-3.12.8-amd64.exe",
    "https://www.python.org/ftp/python/3.12.8/python-3.12.8.exe",
    "https://www.python.org/ftp/python/3.11.9/python-3.11.9-arm64.exe",
    "https://www.python.org/ftp/python/3.11.9/python-3.11.9-amd64.exe",
    "https://www.python.org/ftp/python/3.4.4/python-3.4.4.amd64.msi",
    "https://www.python.org/ftp/python/3.4.4/python-3.4.4.msi",
    "https://www.python.org/ftp/python/3.8.18/Python-3.8.18.tar.xz",
    "https://www.python.org/ftp/python/3.13.0/python-3.13.0a1-amd64.exe",
    "https://www.python.org/ftp/python/pymanager/python-manager-25.0.msi",
    "https://www.python.org/ftp/python/3.12.8/python-3.12.8-embed-amd64.zip",
    "https://www.python.org/ftp/python/2.4/python-2.4.msi",
}
package.preload.http = function()
    return {
        get = function(args)
            state.requests = state.requests + 1
            assert(args.url == "https://www.python.org/downloads/windows/", args.url)
            return state.response, state.requestError
        end,
        head = function()
            error("version listing must not request individual installers")
        end,
    }
end
package.preload.html = function()
    return {
        parse = function()
            return {
                find = function()
                    return {
                        each = function(_, fn)
                            for i, href in ipairs(state.links) do
                                fn(i, {
                                    attr = function()
                                        return href
                                    end,
                                })
                            end
                        end,
                    }
                end,
            }
        end,
    }
end
package.preload.json = function()
    return {}
end
dofile("hooks/available.lua")
local function listing(arch, expected)
    RUNTIME.archType = arch
    state.response, state.requestError, state.requests = { status_code = 200, body = "fixture" }, nil, 0
    local result = PLUGIN:Available({})
    assert(#result == #expected, #result)
    for i, version in ipairs(expected) do
        assert(result[i].version == version, result[i].version)
    end
    assert(state.requests == 1, state.requests)
end
listing("amd64", { "3.12.8", "3.11.9", "3.4.4" })
listing("386", { "3.12.8", "3.4.4" })
listing("arm64", { "3.11.9" })
local function fails(expected)
    local ok, err = pcall(function()
        PLUGIN:Available({})
    end)
    assert(not ok and tostring(err):find(expected, 1, true), tostring(err))
end
state.response, state.requestError = nil, "timeout"
fails("timeout")
state.response, state.requestError = { status_code = 503 }, nil
fails("503")
state.response = { status_code = 200, body = "no installers" }
state.links = {}
fails("No Windows Python installers")
print("Python Windows architecture, filtering and failure cases passed")
