#!/usr/bin/env bash
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

set -euo pipefail

GRAALPY_VERSION="${GRAALPY_VERSION:-graalpy-24.2.0}"

cd /e2e
zip -q -r /tmp/python-plugin.zip metadata.lua hooks lib
vfox add --source /tmp/python-plugin.zip

eval "$(vfox activate bash)"
for attempt in 1 2 3; do
    if vfox install "python@${GRAALPY_VERSION}"; then
        break
    fi
    if [ "$attempt" -eq 3 ]; then
        echo "vfox install failed after 3 attempts" >&2
        exit 1
    fi
    echo "vfox install attempt ${attempt} failed; retrying..." >&2
    sleep 10
done
vfox use --global "python@${GRAALPY_VERSION}"
eval "$(vfox env --shell bash)"
vfox current
python -V
python -c 'import sys; assert sys.implementation.name == "graalpy", sys.implementation.name; print(sys.version)'
python -m pip --version
pip --version

project="/tmp/python-version-project"
rm -rf "$project"
mkdir -p "$project"
printf '%s\n' "$GRAALPY_VERSION" > "$project/.python-version"
cd "$project"
eval "$(vfox env --shell bash)"
python -V
python -c 'import sys; assert sys.implementation.name == "graalpy", sys.implementation.name'

echo "PASS: Linux container GraalPy ${GRAALPY_VERSION}"
