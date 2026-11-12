# Changes

[中文](zh-CN/changes.md) | [English](changes.md)

## Unreleased

- `vfox link --detect python` adopts system, uv, pyenv, asdf, mise, Conda,
  Homebrew, Nix, Snap, python.org, Store and py-launcher Pythons (vfox 1.1.0
  or later). Linked versions are named `<version>-<source>`.
- `.python-version` is read through `ParseLegacyFile`, so pyenv and uv projects
  select their Python when vfox enters the directory.
- `PreUse` leaves a linked installation alone instead of checking its packaging
  tools and rewriting its shebangs.
- English and Chinese documentation: versions, uv, linking, platforms, mirrors,
  development and changes.
- CI: checksum-pinned vfox 1.1.0 on Linux and Windows for the offline tests,
  GopherLua layout tests, StyLua, LuaLS, actionlint, Apache license headers,
  and E2E installs on Linux and Windows.
- Apache headers, `.gitattributes` (LF), StyLua, LuaLS and license
  configuration, and new offline tests for Detect, `.python-version`, uv-build,
  the mirror and linked versions.
- E2E coverage for `vfox link --detect python` on Linux and for a project
  `.python-version` on Linux and Windows.
- `VFOX_PYTHON_MIRROR` accepts a URL without a trailing slash and ignores an
  empty value, which is what CI passes for an unset matrix entry.

## 0.6.2

- Windows installer paths with spaces, percent signs, `!` and single quotes are
  passed through base64 PowerShell commands; targets containing `%` use a
  temporary junction during MSI installation.
- The Windows installer checks exit codes and cleans up temporary files and
  junctions.

## 0.6.1

- Authenticate installer requests and select an available uv-build release for
  the installation smoke test.
- Filter Windows Python versions by the installers python.org actually
  publishes for the architecture.

## 0.6.0

- Add the optional uv-build prebuilt archives with libc detection and SHA-256
  verification.
- Add shebang repair for source and uv-build installs.
