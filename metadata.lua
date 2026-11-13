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

--- !!! DO NOT EDIT OR RENAME !!!
PLUGIN = {}

--- !!! MUST BE SET !!!
--- Plugin name
PLUGIN.name = "python"
--- Plugin version
PLUGIN.version = "0.6.2"
--- Plugin homepage
PLUGIN.homepage = "https://github.com/version-fox/vfox-python"
--- Plugin license, please choose a correct license according to your needs.
PLUGIN.license = "Apache 2.0"
--- Plugin description
PLUGIN.description = "Python language support for CPython and GraalPy, https://www.python.org"

--- !!! OPTIONAL !!!
--[[
NOTE:
    Minimum compatible vfox version.
    If the plugin is not compatible with the current vfox version,
    vfox will not load the plugin and prompt the user to upgrade vfox.
 --]]
PLUGIN.minRuntimeVersion = "0.4.0"

--- .python-version is written by pyenv, uv and asdf. The plugin reads it when
--- vfox changes into a project directory.
PLUGIN.legacyFilenames = {
    ".python-version",
}

-- Some things that need user to be attention!
PLUGIN.notes = {
    "Documentation: https://github.com/version-fox/vfox-python/blob/main/README.md",
    "Mirror: set VFOX_PYTHON_MIRROR to a python.org mirror, for example",
    "`export VFOX_PYTHON_MIRROR=https://mirrors.huaweicloud.com/python/`",
    "uv-build: set VFOX_PYTHON_USE_UV_BUILD=1 to use prebuilt Python archives.",
    "Set VFOX_PYTHON_UV_LIBC=gnu|musl to override Linux libc detection.",
    "Set VFOX_PYTHON_UV_BUILD_MIRROR to mirror uv-build archive downloads.",
    "GraalPy: install python@graalpy-24.2.0 or python@graalpy-community-24.2.0.",
    "GraalPy on Windows is amd64 only; uv-build provides CPython only.",
    "Already installed Python: `vfox link --detect python` (vfox 1.1.0 or later).",
    "Windows launcher: set VFOX_PYTHON_REGISTER_PY_LAUNCHER=1 to register installs with PEP 514.",
    " ",
}
