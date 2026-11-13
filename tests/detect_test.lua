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

-- Detect on Linux: interpreters on PATH and in the directories uv, pyenv and
-- Conda use. A virtual environment, a Python vfox manages and a request it
-- cannot read must all stay out of the result.
local test = require("vfox.test")

local uv = "/home/test/.local/share/uv/python"
local plugin = test.load({
    os = "linux",
    arch = "amd64",
    env = {
        HOME = "/home/test",
        PATH = "/usr/local/bin:/usr/bin:/home/test/.vfox/sdks/python/v-3.12.9/bin:/home/test/project/.venv/bin",
        VFOX_HOME = "/home/test/.vfox",
        XDG_DATA_HOME = false,
        -- GitHub Actions passes empty strings for unset values; the default
        -- roots under HOME must still be used.
        PYENV_ROOT = "",
        ASDF_DATA_DIR = "",
        MISE_DATA_DIR = "",
    },
})

local python_version = require("python_version")

local function hex(value)
    return (value:gsub(".", function(char)
        return string.format("%02x", string.byte(char))
    end))
end

local function output(version, prefix, base, executable, flags)
    return {
        "VERSION=" .. version,
        "IMPLEMENTATION=CPython",
        "ABIFLAGS=" .. (flags or ""),
        "PREFIX_HEX=" .. hex(prefix),
        "BASE_PREFIX_HEX=" .. hex(base or prefix),
        "EXECUTABLE_HEX=" .. hex(executable),
    }
end

local files = {}
local listings = {}

local function install(executable, version, prefix, base, resolved, flags)
    files[executable] = true
    return output(version, prefix, base, resolved or executable, flags)
end

local outputs = {
    ["/usr/bin/python3"] = install("/usr/bin/python3", "3.12.3", "/usr", "/usr", "/usr/bin/python3.12"),
    ["/usr/bin/python"] = install("/usr/bin/python", "3.12.3", "/usr", "/usr", "/usr/bin/python3.12"),
    ["/usr/local/bin/python3"] = install(
        "/usr/local/bin/python3",
        "3.12.3",
        "/usr/local",
        "/usr/local",
        "/usr/local/bin/python3.12"
    ),
    [uv .. "/cpython-3.13.1-linux-x86_64-gnu/bin/python3"] = install(
        uv .. "/cpython-3.13.1-linux-x86_64-gnu/bin/python3",
        "3.13.1",
        uv .. "/cpython-3.13.1-linux-x86_64-gnu"
    ),
    [uv .. "/cpython-3.14.0a4-linux-x86_64-gnu/bin/python3"] = install(
        uv .. "/cpython-3.14.0a4-linux-x86_64-gnu/bin/python3",
        "3.14.0a4",
        uv .. "/cpython-3.14.0a4-linux-x86_64-gnu",
        nil,
        nil,
        "t"
    ),
    ["/home/test/.pyenv/versions/3.11.9/bin/python3"] = install(
        "/home/test/.pyenv/versions/3.11.9/bin/python3",
        "3.11.9",
        "/home/test/.pyenv/versions/3.11.9"
    ),
    ["/opt/conda/bin/python3"] = install("/opt/conda/bin/python3", "3.10.14", "/opt/conda"),
    ["/home/test/.vfox/sdks/python/v-3.12.9/bin/python3"] = install(
        "/home/test/.vfox/sdks/python/v-3.12.9/bin/python3",
        "3.12.9",
        "/home/test/.vfox/sdks/python/v-3.12.9"
    ),
    ["/home/test/project/.venv/bin/python3"] = install(
        "/home/test/project/.venv/bin/python3",
        "3.12.3",
        "/home/test/project/.venv",
        "/usr",
        "/usr/bin/python3.12"
    ),
}

listings[uv] = {
    "cpython-3.13.1-linux-x86_64-gnu",
    "cpython-3.14.0a4-linux-x86_64-gnu",
    "pypy3.10-7.3.15-linux-x86_64-gnu",
}
local pypy = uv .. "/pypy3.10-7.3.15-linux-x86_64-gnu/bin/python3"
files[pypy] = true
outputs[pypy] = output("3.10.14", uv .. "/pypy3.10-7.3.15-linux-x86_64-gnu", nil, pypy)
outputs[pypy][2] = "IMPLEMENTATION=PyPy"
listings["/home/test/.pyenv/versions"] = { "3.11.9" }

io.open = function(path, mode)
    if mode == "r" and files[path] then
        return {
            close = function()
                return true
            end,
        }
    end
    return nil
end

local function handle(lines)
    local index = 0
    return {
        read = function(_, format)
            assert(format == "*l", format)
            index = index + 1
            return lines[index]
        end,
        close = function()
            return 0
        end,
    }
end

io.popen = function(command, mode)
    local directory = command:match("^ls %-1 '(.*)' 2>/dev/null$")
    if directory then
        return handle(listings[directory] or {})
    end
    if command == "uv python dir 2>/dev/null" then
        return handle({ uv })
    end
    local executable = command:match("^'([^']*)' %-E %-s %-c ")
    if executable then
        return handle(outputs[executable] or {})
    end
    return handle({})
end

local found = plugin:Detect({})
assert(#found == 6, tostring(#found))
local by_version = {}
for _, item in ipairs(found) do
    by_version[item.version] = item
end

assert(by_version["3.12.3-system"].path == "/usr", by_version["3.12.3-system"].path)
assert(by_version["3.12.3-system"].note == "system package manager")
assert(by_version["3.12.3-local"].path == "/usr/local", by_version["3.12.3-local"].path)
assert(by_version["3.13.1-uv"].path == uv .. "/cpython-3.13.1-linux-x86_64-gnu")
assert(by_version["3.14.0a4t-uv"].path == uv .. "/cpython-3.14.0a4-linux-x86_64-gnu")
assert(by_version["3.11.9-pyenv"].path == "/home/test/.pyenv/versions/3.11.9")
assert(by_version["3.10.14-conda"].path == "/opt/conda")

-- The vfox-managed interpreter on PATH and the project virtual environment
-- must not be adopted. The vfox path would have been named 3.12.9-system and
-- the venv 3.12.3-system; the system Python's path proves neither replaced it.
assert(by_version["3.12.9-system"] == nil)
assert(by_version["3.12.3-system"].path == "/usr")

assert(python_version.parse_request("cpython-3.12.8+freethreaded-linux-x86_64-gnu") == "3.12.8t")
assert(python_version.parse_request("3.12.3/envs/example") == nil)
assert(python_version.parse_request("pypy3.10-7.3.15") == nil)
assert(python_version.parse_request("system") == "system")
assert(python_version.find_installed({ ["3.12.8"] = true, ["3.12.8-system"] = true }, "3.12") == "3.12.8")
assert(python_version.find_installed({ ["3.12.8-system"] = true }, "3.12.8") == "3.12.8-system")
assert(
    python_version.find_installed({ ["3.11.9-system"] = true, ["3.12.3-system"] = true }, "system") == "3.12.3-system"
)

print("PASS: Linux Detect sources, names, vfox and venv filtering")
