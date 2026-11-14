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

-- An index request that fails transiently is sent again: up to three attempts in all,
-- with a pause of one second and then two before the retries. A failure that persists
-- is still an error, and a client error such as 404 is not retried. os.execute is
-- disabled in plugin tests, so the pause is replaced and the test records it instead.
local test = require("vfox.test")
local json = require("json")

local UV_INDEX = "https://vault.vfox.dev/python/uv-build?"
local PYENV_INDEX = "https://vault.vfox.dev/python/pyenv"
local SHA = string.rep("a", 64)

-- The uv-build index for linux/x86_64/gnu, with one CPython release.
local UV_BODY = json.encode({
    items = {
        {
            implementation = "cpython",
            version = "3.12.16",
            variant = "default",
            filename = "cpython-3.12.16+20260101-x86_64-unknown-linux-gnu-install_only_stripped.tar.gz",
            url = "https://github.com/astral-sh/python-build-standalone/releases/download/20260101/"
                .. "cpython-3.12.16+20260101-x86_64-unknown-linux-gnu-install_only_stripped.tar.gz",
            asset = { sha256 = SHA },
        },
    },
})

local PYENV_BODY = json.encode({ tagName = "v2.6.0", versions = { "3.12.16" } })

-- Each request takes the next step, and the last step repeats. A step is
-- { error = "..." } for a transport error, or { status = N, body = "..." }.
local state = { steps = {}, urls = {} }
local pauses = {}
local env = {}

local plugin = test.load({
    os = "linux",
    arch = "amd64",
    env = {},
    http = function(request)
        table.insert(state.urls, request.url)
        local step = state.steps[math.min(#state.urls, #state.steps)]
        if step.error ~= nil then
            return nil, step.error
        end
        return { status_code = step.status, body = step.body }
    end,
})

-- The real pause, kept before the test replaces it below.
local realPause = pauseBeforeIndexRetry

-- The plugin reads its variables at call time, so each case sets the ones it needs.
os.getenv = function(name)
    return env[name]
end

pauseBeforeIndexRetry = function(attempt)
    table.insert(pauses, attempt)
end

--- Runs fn against the given steps. It returns whether fn succeeded, its result or
--- error, the number of requests sent, and the pauses taken, as "1,2".
local function run(steps, fn)
    state.urls = {}
    state.steps = steps
    pauses = {}
    local ok, result = pcall(fn)
    -- table.concat hands back a lone number unchanged in GopherLua, so it is made a string.
    return ok, result, #state.urls, tostring(table.concat(pauses, ","))
end

local function available()
    return plugin:Available({})
end

local function fails(ok, err, expected)
    assert(not ok and tostring(err):find(expected, 1, true), tostring(err))
end

local OK = { status = 200, body = UV_BODY }
local TRANSPORT = { error = "connection reset by peer" }
local UV_ENV = { VFOX_PYTHON_USE_UV_BUILD = "1", VFOX_PYTHON_UV_LIBC = "gnu" }
local PYENV_ENV = { VFOX_PYTHON_USE_UV_BUILD = "0", VFOX_PYTHON_UV_LIBC = "gnu" }

-- A 503, then a success: one pause, two requests.
env = UV_ENV
local ok, result, sent, paused = run({ { status = 503 }, OK }, available)
assert(ok, tostring(result))
assert(result[1].version == "3.12.16", tostring(result[1] and result[1].version))
assert(sent == 2 and paused == "1", "sent " .. sent .. ", paused " .. paused)

-- A transport error, then a success.
ok, result, sent, paused = run({ TRANSPORT, OK }, available)
assert(ok and result[1].version == "3.12.16", tostring(result))
assert(sent == 2 and paused == "1", "sent " .. sent .. ", paused " .. paused)

-- A 429, then a 500, then a success: two pauses, of one and then two seconds.
ok, result, sent, paused = run({ { status = 429 }, { status = 500 }, OK }, available)
assert(ok and result[1].version == "3.12.16", tostring(result))
assert(sent == 3 and paused == "1,2", "sent " .. sent .. ", paused " .. paused)

-- A failure that persists: three attempts, then an error that says so.
ok, result, sent, paused = run({ { status = 503 } }, available)
fails(ok, result, "Status: 503")
fails(ok, result, "after 3 attempts")
assert(sent == 3 and paused == "1,2", "sent " .. sent .. ", paused " .. paused)

-- A transport error that persists is retried the same way.
ok, result, sent, paused = run({ TRANSPORT }, available)
fails(ok, result, "connection reset by peer")
assert(sent == 3 and paused == "1,2", "sent " .. sent .. ", paused " .. paused)

-- A 404 is an answer, not a server failure: no retry, no pause, and no attempt count.
ok, result, sent, paused = run({ { status = 404 } }, available)
fails(ok, result, "Status: 404")
assert(not tostring(result):find(" attempts", 1, true), tostring(result))
assert(sent == 1 and paused == "", "sent " .. sent .. ", paused " .. paused)

-- An install retries the same way: PreInstall reads the index for an exact version.
ok, result, sent, paused = run({ { status = 503 }, OK }, function()
    return plugin:PreInstall({ version = "3.12.16" })
end)
assert(ok and result.note == "uv-build" and result.sha256 == SHA, tostring(result))
assert(sent == 2 and paused == "1", "sent " .. sent .. ", paused " .. paused)

-- The pyenv list is retried as well, in the source-build mode.
env = PYENV_ENV
ok, result, sent, paused = run({ { status = 500 }, { status = 200, body = PYENV_BODY } }, available)
assert(ok and result[1].version == "3.12.16", tostring(result))
assert(sent == 2 and paused == "1", "sent " .. sent .. ", paused " .. paused)
assert(state.urls[1] == PYENV_INDEX, state.urls[1])

-- The real wait is a shell command: `sleep` on Linux and macOS, PowerShell on Windows.
-- The shell is stubbed here to capture the command instead of running it.
local commands = {}
os.execute = function(command)
    table.insert(commands, command)
    return 0
end
realPause(1)
RUNTIME.osType = "windows"
realPause(2)
RUNTIME.osType = "linux"
assert(commands[1] == "sleep 1", commands[1])
assert(string.find(commands[2], "powershell", 1, true), commands[2])
assert(string.find(commands[2], "Start-Sleep -Seconds 2", 1, true), commands[2])

print("PASS: index requests are retried on transient failures and not on client errors")
