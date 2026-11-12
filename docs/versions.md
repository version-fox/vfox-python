# Versions

[中文](zh-CN/versions.md) | [English](versions.md)

## Names

A version is the CPython release, such as `3.12.2`, `3.13.1` or `3.14.0a4`.
Free-threaded builds end in `t`:

```bash
vfox install python@3.13.1t
vfox install python@3.14.0a4t
```

`vfox install` with a bare major installs the newest release of that line;
`vfox use` with one selects the newest installed release, as it does for other
SDKs:

```bash
vfox install python@3.12       # newest 3.12.x available
vfox install python@3.12.2     # the release itself
vfox use python@3.12           # newest installed 3.12.x
```

`latest` is resolved by `PreInstall` to the first version `Available` returns.
The list is newest first, so this is the newest release the platform lists,
which can be a pre-release when one exists.

## Where the list comes from

| Platform | Source | What is listed |
| --- | --- | --- |
| Linux, macOS | the plugin's pyenv index | every CPython release pyenv knows, including pre-releases and 2.x |
| Windows | the python.org Windows download page | stable releases with an installer for the running architecture |
| any, `VFOX_PYTHON_USE_UV_BUILD=1` | the uv-build index | CPython archives for the platform, architecture and libc |

On Windows the plugin reads the download page once and keeps only the exact
installer name for the architecture: `python-<version>-amd64.exe`,
`python-<version>.exe` on 386, or `python-<version>-arm64.exe`, and the matching
MSI names. Source-only security releases, embeddable zips, the Python Manager
and duplicate architecture entries are left out. Releases before 2.5 are not
listed. A pre-release installer whose filename carries a suffix (for example
`python-3.13.0a1-amd64.exe`) does not match the exact stable name and is not
listed; on Windows, use uv-build when a pre-release is needed.

On Linux and macOS the version list is not fetched from python.org. The plugin
asks `https://vault.vfox.dev/python/pyenv` for the pyenv tag and its version
list, then `python-build` from that tag builds the release. This is the same
list `pyenv install --list` shows. Installing an old release can fail on a
modern distribution when its source no longer compiles; the build output names
the missing header or compiler.

The `Available` result is cached by vfox for 12 hours by default; see vfox's
cache settings if you need to refresh it sooner.

## Installed names

A version installed by this plugin keeps its bare name: `3.12.2`, `3.14.0a4t`.
The name is what `vfox list python`, `vfox use` and `vfox uninstall` show and
take.

Versions adopted with `vfox link --detect python` add the source, so they do not
collide with the release installed by vfox:

| Source | Example name |
| --- | --- |
| system package manager | `3.12.3-system` |
| `/usr/local` | `3.12.3-local` |
| uv | `3.13.1-uv` |
| pyenv | `3.11.9-pyenv` |
| asdf | `3.12.8-asdf` |
| mise | `3.13.1-mise` |
| Conda | `3.10.14-conda` |
| python.org installer | `3.12.10-pythonorg` |
| Microsoft Store | `3.13.1-store` |
| Homebrew | `3.12.8-brew` |
| Nix | `3.12.8-nix` |
| `/opt` | `3.12.8-opt` |
| Snap | `3.12.8-snap` |
| Scoop | `3.12.8-scoop` |

The suffixes are described in [link.md](link.md). `vfox use python@3.12` still
matches `3.12.3-system` by its version prefix; name the suffix when both a bare
and a linked 3.12 are installed and you want a particular one.

## `.python-version`

`metadata.lua` registers `.python-version` as a legacy version file. When vfox
changes into a directory that has one, the hook selects an installed version:

```text
3.12.8
3.12
cpython-3.12.8
cpython-3.12.8+freethreaded-linux-x86_64-gnu
system
```

- `3.12` selects the newest installed 3.12.x.
- `cpython-3.12.8` selects `3.12.8`, or its linked `3.12.8-system` when only
  that is installed.
- The `+freethreaded` form selects the `t` version.
- `system` selects the newest linked `-system` version.
- PyPy and other implementations are not handled; neither is a path or a
  `3.12.3/envs/...` entry.
- A version that is not installed selects nothing, so vfox leaves the current
  version in place instead of installing one behind your back.

The file is read for the `specified` strategy. With
`legacyVersionFile.strategy: latest_installed` in vfox's configuration, a
missing or unreadable entry falls back to the newest installed Python.

## Windows installers

Windows uses the python.org installer rather than compiling:

- `.exe` installers are extracted with the bundled WiX `dark.exe`, and the MSIs
  inside are installed into the version directory. pip is bootstrapped with
  `ensurepip`.
- `.msi` installers (older releases) are installed directly with `msiexec`.
- Alias executables such as `python3.exe` and `python3.12.exe` are created next
  to `python.exe`, because the python.org installer normally creates them in a
  shared directory outside the target.
- Paths with spaces, percent signs, `!` and quotes are handled through
  PowerShell commands with base64 arguments; see
  [development.md](development.md).

## uv-build names

In uv-build mode, `display_version` wins when the index provides it; otherwise a
`freethreaded` build gets the `t` suffix, so `3.13.1` with `variant =
"freethreaded"` is `3.13.1t`. Only CPython builds with an HTTPS archive URL are
listed. See [uv.md](uv.md).
