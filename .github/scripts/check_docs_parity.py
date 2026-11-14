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

"""Checks that the Chinese documents keep the structure of the English ones.

The sentences are translated, so they are not compared. The checks are the ones a
reader trips over when the two languages drift apart:

- every English page has a Chinese page, and every Chinese page has an English one;
- both pages name the same VFOX_* environment variables;
- both pages have the same number of fenced code blocks;
- every relative link resolves from the folder of the page that holds it.

Run it from the repository root:

    python3 -I .github/scripts/check_docs_parity.py .
"""

import pathlib
import re
import sys

FENCE = re.compile(r"^[ \t]*```[^\n]*\n(.*?)^[ \t]*```[ \t]*$", re.S | re.M)
ENV_NAME = re.compile(r"\bVFOX_[A-Z0-9_]+\b")
LINK = re.compile(r"\]\(([^)\s]+)")
SCHEME = re.compile(r"^[A-Za-z][A-Za-z0-9+.-]*:")


def read(path):
    return path.read_text(encoding="utf-8")


def page_pairs(root):
    pairs = [(root / "README.md", root / "README_CN.md")]
    for english in sorted((root / "docs").glob("*.md")):
        pairs.append((english, root / "docs" / "zh-CN" / english.name))
    return pairs


def relative_links(text):
    # Code blocks can hold anything that looks like a link, so they are skipped.
    for target in LINK.findall(FENCE.sub("", text)):
        if SCHEME.match(target) or target.startswith("#"):
            continue
        yield target.split("#", 1)[0]


def check_pair(root, english, chinese, problems):
    name = english.relative_to(root)
    if not chinese.is_file():
        problems.append(f"{name}: no Chinese page at {chinese.relative_to(root)}")
        return 0

    en_text = read(english)
    zh_text = read(chinese)
    en_env = set(ENV_NAME.findall(en_text))
    zh_env = set(ENV_NAME.findall(zh_text))
    for variable in sorted(en_env - zh_env):
        problems.append(f"{name}: {variable} appears in the English page only")
    for variable in sorted(zh_env - en_env):
        problems.append(f"{name}: {variable} appears in the Chinese page only")

    en_blocks = len(FENCE.findall(en_text))
    zh_blocks = len(FENCE.findall(zh_text))
    if en_blocks != zh_blocks:
        problems.append(f"{name}: {en_blocks} code blocks in English, {zh_blocks} in Chinese")

    for page in (english, chinese):
        for target in relative_links(read(page)):
            if not (page.parent / target).exists():
                problems.append(f"{page.relative_to(root)}: the link to {target} does not exist")
    return 1


def main(argv):
    root = pathlib.Path(argv[1] if len(argv) > 1 else ".").resolve()
    problems = []
    checked = 0
    for english, chinese in page_pairs(root):
        checked += check_pair(root, english, chinese, problems)
    for chinese in sorted((root / "docs" / "zh-CN").glob("*.md")):
        if not (root / "docs" / chinese.name).is_file():
            problems.append(f"{chinese.relative_to(root)}: no English page for it")

    for problem in problems:
        print(problem)
    if problems:
        return 1
    print(f"Docs parity: {checked} pages checked, the English and Chinese pages agree.")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
