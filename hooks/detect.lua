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

local detect = require("detect_python")

--- Finds CPython installations that are already on the machine and that vfox
--- did not install, for `vfox link --detect python`. Each result is named the
--- way `vfox install` names a Python, with the source appended, such as
--- 3.12.8-system or 3.13.1-uv.
function PLUGIN:Detect(ctx)
    return detect.find_all()
end
