# Copyright 2026 Han Li and contributors
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""Choose a current security-only Python 3.10 build for the installation smoke test."""
import json
import os
import platform
import urllib.request

os_name = "windows" if platform.system() == "Windows" else "linux"
request = urllib.request.Request(
    "https://vault.vfox.dev/python/uv-build?os=" + os_name + "&arch=x86_64",
    headers={"User-Agent": "vfox"},
)
with urllib.request.urlopen(request, timeout=30) as response:
    items = json.load(response)["items"]
versions = set()
for item in items:
    version = item.get("version", "")
    parts = version.split(".")
    if (item.get("implementation") == "cpython"
            and item.get("variant", "default") == "default"
            and len(parts) == 3 and parts[:2] == ["3", "10"]
            and all(part.isdigit() for part in parts)
            and item.get("filename", "").endswith((".tar.gz", ".zip"))):
        versions.add(version)
if not versions:
    raise RuntimeError("No Python 3.10 uv-build installer is available for " + os_name)
version = max(versions, key=lambda value: tuple(map(int, value.split("."))))
with open(os.environ["GITHUB_ENV"], "a", encoding="utf-8") as output:
    output.write("VFOX_TEST_UV_VERSION=" + version + "\n")
print("Testing uv-build Python " + version + " on " + os_name)
