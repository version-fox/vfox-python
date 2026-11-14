-- Copyright 2026 Han Li and contributors
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--   http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.

-- With VFOX_PYTHON_USE_UV_BUILD unset, Linux and macOS install a CPython release
-- from its uv-build archive when the index lists it, and build any other release
-- from source. A partial request resolves in the index first. Available keeps every
-- pyenv name and adds the uv-only CPython releases. VFOX_PYTHON_USE_UV_BUILD=0 keeps
-- the source build, and =1 stays strict.
local test = require("vfox.test")
local json = require("json")

local realOpen, realPopen = io.open, io.popen

local github = "https://github.com/astral-sh/python-build-standalone/releases/download/20260101/"
local UV_INDEX = "https://vault.vfox.dev/python/uv-build?"
local PYENV_INDEX = "https://vault.vfox.dev/python/pyenv"

local function uvBuild(version, variant, checksum)
    local filename = "cpython-"
        .. version
        .. "+20260101-x86_64-unknown-linux-gnu-"
        .. (variant == "freethreaded" and "freethreaded-" or "")
        .. "install_only_stripped.tar.gz"
    return {
        implementation = "cpython",
        version = version,
        variant = variant,
        filename = filename,
        url = github .. filename,
        asset = { sha256 = string.rep(checksum, 64) },
    }
end

local state = {
    requests = {},
    uvStatus = 200,
    pyenvStatus = 200,
    uvItems = {
        uvBuild("3.12.16", "default", "1"),
        uvBuild("3.13.18", "default", "2"),
        uvBuild("3.13.18", "freethreaded", "3"),
        uvBuild("3.16.0", "default", "4"),
        uvBuild("3.16.0a2", "default", "5"),
    },
}

-- 3.13.19 is a pyenv-only patch that the index does not list. A partial request
-- for 3.13 takes the index's 3.13.18; only the exact name selects 3.13.19.
-- 3.16-dev is a pyenv development snapshot: it must not be the newest entry.
local pyenvVersions =
    { "2.7.18", "3.12.16", "3.13.18", "3.13.18t", "3.13.19", "3.16-dev", "pypy3.10-7.3.15", "graalpy-24.2.0" }

local function http(request)
    table.insert(state.requests, request.url)
    if request.url == PYENV_INDEX then
        if state.pyenvStatus ~= 200 then
            return { status_code = state.pyenvStatus }
        end
        return { status_code = 200, body = json.encode({ tagName = "v2.6.0", versions = pyenvVersions }) }
    end
    if string.find(request.url, UV_INDEX, 1, true) == 1 then
        if state.uvStatus ~= 200 then
            return { status_code = state.uvStatus }
        end
        return { status_code = 200, body = json.encode({ items = state.uvItems }) }
    end
    error("unexpected request: " .. request.url)
end

-- test.load may run once per file, so the environment is switched here. The
-- plugin reads os.getenv at call time, so each case sets the variables it needs.
local env = { VFOX_PYTHON_UV_LIBC = "gnu" }

local plugin = test.load({
    os = "linux",
    arch = "amd64",
    env = { VFOX_PYTHON_UV_LIBC = "gnu" },
    http = http,
})

os.getenv = function(name)
    return env[name]
end

local function uvRequests()
    local count = 0
    for _, url in ipairs(state.requests) do
        if string.find(url, UV_INDEX, 1, true) == 1 then
            count = count + 1
        end
    end
    return count
end

local function reset()
    state.requests = {}
end

-- A source install returns no archive. The test harness reports the missing URL
-- as an empty string, and vfox treats an empty URL the same way.
local function isSource(package)
    return package.url == nil or package.url == ""
end

local function namesOf(list)
    local names = {}
    for i, item in ipairs(list) do
        names[i] = item.version
    end
    return names
end

-- Available: the CPython releases of both lists, newest first and once each,
-- then the names only pyenv lists. A final release outranks its pre-release.
local names = namesOf(plugin:Available({}))
local expected = { "3.16.0", "3.16.0a2", "3.13.19", "3.13.18", "3.13.18t", "3.12.16", "2.7.18", "3.16-dev" }
for i, version in ipairs(expected) do
    assert(names[i] == version, "Available[" .. i .. "] is " .. tostring(names[i]) .. ", want " .. version)
end
assert(#names == 10, table.concat(names, " "))
assert(
    (names[9] == "pypy3.10-7.3.15" and names[10] == "graalpy-24.2.0")
        or (names[9] == "graalpy-24.2.0" and names[10] == "pypy3.10-7.3.15"),
    table.concat(names, " ")
)

-- An exact CPython release in the index installs its archive.
reset()
local package = plugin:PreInstall({ version = "3.12.16" })
assert(package.note == "uv-build", tostring(package.note))
assert(
    package.url == github .. "cpython-3.12.16+20260101-x86_64-unknown-linux-gnu-install_only_stripped.tar.gz",
    package.url
)
assert(package.sha256 == string.rep("1", 64), tostring(package.sha256))
assert(uvRequests() == 1, "one index request for an exact CPython version")

package = plugin:PreInstall({ version = "3.13.18t" })
assert(package.sha256 == string.rep("3", 64), "free-threaded request must take its own build")

-- A partial request resolves in the index first: the newest release the index lists
-- on that line. The pyenv-only 3.13.19 is not picked for "3.13". The request reads
-- the index twice: once to resolve the name, and once for the archive.
reset()
package = plugin:PreInstall({ version = "3.13" })
assert(package.version == "3.13.18" and package.sha256 == string.rep("2", 64), tostring(package.version))
assert(package.note == "uv-build", tostring(package.note))
assert(uvRequests() == 2, "a partial request reads the index to resolve, then for the archive")

-- A free-threaded partial request resolves to the free-threaded build.
package = plugin:PreInstall({ version = "3.13t" })
assert(package.version == "3.13.18t" and package.sha256 == string.rep("3", 64), tostring(package.version))

-- The exact pyenv-only patch has no archive, so it is built from source.
package = plugin:PreInstall({ version = "3.13.19" })
assert(package.version == "3.13.19" and isSource(package), tostring(package.version))

-- A line the index does not list resolves in the pyenv list, and is built from source.
package = plugin:PreInstall({ version = "2" })
assert(package.version == "2.7.18" and isSource(package), tostring(package.version))

-- latest is the newest release of the list. It is never an older release that the
-- index lists instead, and it takes the archive when the index lists that release.
package = plugin:PreInstall({ version = "latest" })
assert(package.version == "3.16.0" and package.note == "uv-build", tostring(package.version))

-- When pyenv lists a newer release than the index, latest is that release, and it is
-- built from source. The extra entry is removed again straight after the check.
table.insert(pyenvVersions, "3.16.1")
package = plugin:PreInstall({ version = "latest" })
table.remove(pyenvVersions)
assert(package.version == "3.16.1" and isSource(package), tostring(package.version))

-- A free-threaded build newer than every standard release is never latest: latest is
-- the newest standard release, here the index's 3.16.0 with its archive.
table.insert(pyenvVersions, "3.16.1t")
package = plugin:PreInstall({ version = "latest" })
table.remove(pyenvVersions)
assert(package.version == "3.16.0" and package.note == "uv-build", tostring(package.version))

-- A release only pyenv lists is built from source: no archive is returned.
reset()
package = plugin:PreInstall({ version = "2.7.18" })
assert(
    package.version == "2.7.18" and isSource(package),
    "version=" .. tostring(package.version) .. " url=" .. tostring(package.url)
)
assert(uvRequests() == 1, "the index is checked before the source build")

-- A non-CPython name never reads the uv-build index.
reset()
package = plugin:PreInstall({ version = "pypy3.10-7.3.15" })
assert(package.version == "pypy3.10-7.3.15" and isSource(package), tostring(package.url))
assert(uvRequests() == 0, "a non-CPython name must not read the uv-build index")

-- An index that cannot be read is an error that names the opt-out; it is not a
-- silent source build. The list still shows the pyenv names.
state.uvStatus = 503
local ok, err = pcall(function()
    plugin:PreInstall({ version = "3.12.16" })
end)
assert(not ok and tostring(err):find("Could not read the uv-build index", 1, true), tostring(err))
assert(tostring(err):find("VFOX_PYTHON_USE_UV_BUILD=0", 1, true), tostring(err))

-- A partial request fails the same way: it must not fall back to a source build.
ok, err = pcall(function()
    plugin:PreInstall({ version = "3.13" })
end)
assert(not ok and tostring(err):find("Could not read the uv-build index", 1, true), tostring(err))
assert(#plugin:Available({}) == 8, "the pyenv names are listed when the index fails")
state.uvStatus = 200

-- A pyenv failure still lists the uv-build CPython releases.
state.pyenvStatus = 500
names = namesOf(plugin:Available({}))
assert(#names == 5 and names[1] == "3.16.0", table.concat(names, " "))
state.pyenvStatus = 200

-- macOS asks for its own platform and never sends a libc. The plugin reads the
-- platform at call time, so it is switched for this case only.
local runtimeOs, runtimeArch, hostOs = RUNTIME.osType, RUNTIME.archType, OS_TYPE
RUNTIME.osType, RUNTIME.archType, OS_TYPE = "darwin", "arm64", "darwin"
env = {}
reset()
package = plugin:PreInstall({ version = "3.12.16" })
env = { VFOX_PYTHON_UV_LIBC = "gnu" }
RUNTIME.osType, RUNTIME.archType, OS_TYPE = runtimeOs, runtimeArch, hostOs
assert(package.note == "uv-build", tostring(package.note))
local macRequest = state.requests[#state.requests]
assert(string.find(macRequest, "os=darwin&arch=aarch64", 1, true), macRequest)
assert(not string.find(macRequest, "libc=", 1, true), macRequest)

-- With no detectable libc, the source build is used rather than a guessed archive.
env = {}
io.open = function(path, mode)
    if string.find(path, "musl", 1, true) then
        return nil
    end
    return realOpen(path, mode)
end
io.popen = function()
    return nil
end
reset()
package = plugin:PreInstall({ version = "3.12.16" })
io.open, io.popen = realOpen, realPopen
assert(isSource(package), "without a detectable libc the source build is used")
assert(uvRequests() == 0, "no index request without a libc")
env = { VFOX_PYTHON_UV_LIBC = "gnu" }

-- A python.org mirror keeps CPython on the source path. The uv-build mirror,
-- when it is set too, moves the uv-build downloads to that mirror.
env = { VFOX_PYTHON_MIRROR = "https://mirror.example/python/", VFOX_PYTHON_UV_LIBC = "gnu" }
reset()
names = namesOf(plugin:Available({}))
assert(#names == 8, table.concat(names, " "))
package = plugin:PreInstall({ version = "3.12.16" })
assert(isSource(package), "a python.org mirror keeps the source build")
assert(uvRequests() == 0, "no uv-build index request with a python.org mirror")
env = {
    VFOX_PYTHON_MIRROR = "https://mirror.example/python/",
    VFOX_PYTHON_UV_BUILD_MIRROR = "https://uv.example/",
    VFOX_PYTHON_UV_LIBC = "gnu",
}
package = plugin:PreInstall({ version = "3.12.16" })
assert(
    package.url
        == "https://uv.example/20260101/cpython-3.12.16+20260101-x86_64-unknown-linux-gnu-install_only_stripped.tar.gz",
    package.url
)
env = { VFOX_PYTHON_UV_LIBC = "gnu" }

-- VFOX_PYTHON_USE_UV_BUILD=0: the source build and the pyenv list only.
env = { VFOX_PYTHON_USE_UV_BUILD = "0", VFOX_PYTHON_UV_LIBC = "gnu" }
reset()
names = namesOf(plugin:Available({}))
assert(#names == 8, table.concat(names, " "))
for _, version in ipairs(names) do
    assert(version ~= "3.16.0" and version ~= "3.16.0a2", "uv-only release listed in source mode")
end
-- The pyenv list is newest first too. A 3.13.5 that pyenv lists falls below 3.13.18t,
-- since 3.13.18t sorts by its release; the snapshot 3.16-dev comes after the releases.
table.insert(pyenvVersions, "3.13.5")
names = namesOf(plugin:Available({}))
table.remove(pyenvVersions)
assert(
    table.concat(names, " ", 1, 7) == "3.13.19 3.13.18 3.13.18t 3.13.5 3.12.16 2.7.18 3.16-dev",
    table.concat(names, " ")
)
package = plugin:PreInstall({ version = "3.12.16" })
assert(isSource(package), "=0 must build from source")
assert(uvRequests() == 0, "=0 must not read the uv-build index")

-- VFOX_PYTHON_USE_UV_BUILD=1: only the index, with the strict errors.
env = { VFOX_PYTHON_USE_UV_BUILD = "1", VFOX_PYTHON_UV_LIBC = "gnu" }
names = namesOf(plugin:Available({}))
assert(#names == 5, table.concat(names, " "))
package = plugin:PreInstall({ version = "3.12.16" })
assert(package.note == "uv-build", tostring(package.note))
ok, err = pcall(function()
    plugin:PreInstall({ version = "2.7.18" })
end)
assert(not ok and tostring(err):find("No uv-build prebuilt Python found for version 2.7.18", 1, true), tostring(err))
ok, err = pcall(function()
    plugin:PreInstall({ version = "graalpy-24.2.0" })
end)
assert(not ok and tostring(err):find("uv-build provides CPython only", 1, true), tostring(err))
assert(tostring(err):find("(or set it to 0)", 1, true), tostring(err))

-- PostInstall takes the archive path when PreInstall set the uv-build note, which
-- vfox passes on in sdkInfo. It does not ask the index again. uvBuildInstall and
-- linuxCompile are replaced so only the choice is checked. The real linuxCompile
-- is kept for the check that refuses to build over an unpacked archive.
local realLinuxCompile = linuxCompile
local calls = {}
uvBuildInstall = function()
    calls[#calls + 1] = "uv"
end
linuxCompile = function()
    calls[#calls + 1] = "source"
end

-- A path holds a Python only when a test puts one there, as vfox does for an archive.
local present = {}
io.open = function(path, mode)
    if present[path] then
        return {
            close = function() end,
        }
    end
    return realOpen(path, mode)
end

local root = "/home/test/.vfox"
local function installPath(version)
    return root .. "/cache/python/v-" .. version .. "/python-" .. version
end

local function postInstall(version, note)
    calls = {}
    plugin:PostInstall({
        rootPath = root,
        sdkInfo = {
            python = { path = installPath(version), version = version, note = note },
        },
    })
    return table.concat(calls, ",")
end

env = { VFOX_PYTHON_UV_LIBC = "gnu" }
reset()
assert(postInstall("3.12.16", "uv-build") == "uv", "the uv-build note takes the archive path")
assert(postInstall("2.7.18", "") == "source", "an install without the note is built from source")
assert(postInstall("2.7.18", nil) == "source", "an install with no note at all is built from source")
assert(postInstall("pypy3.10-7.3.15", nil) == "source", "a non-CPython name is built from source")
assert(uvRequests() == 0, "PostInstall does not ask the index")

env = { VFOX_PYTHON_USE_UV_BUILD = "1", VFOX_PYTHON_UV_LIBC = "gnu" }
assert(postInstall("2.7.18", nil) == "uv", "=1 always takes the archive path")

env = { VFOX_PYTHON_USE_UV_BUILD = "0", VFOX_PYTHON_UV_LIBC = "gnu" }
assert(postInstall("3.12.16", nil) == "source", "=0 builds from source")

env = { VFOX_PYTHON_MIRROR = "https://mirror.example/python/", VFOX_PYTHON_UV_LIBC = "gnu" }
assert(postInstall("3.12.16", nil) == "source", "a python.org mirror keeps the source build")
env = { VFOX_PYTHON_UV_LIBC = "gnu" }

-- A Python already in the install path was unpacked from an archive. The source
-- build refuses to start rather than build over it, and the message says how to
-- recover.
present = { [installPath("3.12.16") .. "/bin/python"] = true }
local guardOk, guardErr = pcall(realLinuxCompile, {
    rootPath = root,
    sdkInfo = { python = { path = installPath("3.12.16"), version = "3.12.16" } },
})
assert(not guardOk and tostring(guardErr):find("is already in", 1, true), tostring(guardErr))
assert(tostring(guardErr):find("vfox uninstall python@3.12.16", 1, true), tostring(guardErr))
present = {}

io.open, io.popen = realOpen, realPopen

print("PASS: uv-build by default for CPython on Linux and macOS, with source fallbacks and opt-outs")
