# vfox-python

Python plugin for [vfox](https://vfox.dev/).

## Install

After installing [vfox](https://github.com/version-fox/vfox), install the plugin by running:

```bash
vfox add python
```

if you want install the free-threaded mode of python, you can select the version ends with `t`, like `v3.14.0a4t`.

## Mirror

You can configure the mirror by `VFOX_PYTHON_MIRROR` environment variable. The default value
is `https://www.python.org/ftp/python/`.

```bash
export VFOX_PYTHON_MIRROR=https://mirrors.huaweicloud.com/python/
```

## uv-build

On Windows, the default version list contains stable installers published on
python.org for the current architecture. Source-only releases (for example
3.8.18) are omitted. `VFOX_PYTHON_MIRROR` still controls installer downloads;
version discovery uses the official Windows download index. The optional uv-build
mode below uses its own platform-specific build list.

Set `VFOX_PYTHON_USE_UV_BUILD=1` to install prebuilt Python archives from the
vfox vault uv-build endpoint instead of building from pyenv/python-build.

On Linux, libc is detected automatically. Set `VFOX_PYTHON_UV_LIBC=gnu` or
`VFOX_PYTHON_UV_LIBC=musl` to override detection.

Set `VFOX_PYTHON_UV_BUILD_MIRROR` to download uv-build archives from a mirror.
For example:

```bash
export VFOX_PYTHON_UV_BUILD_MIRROR=https://registry.npmmirror.com/-/binary/python-build-standalone/
```

## Releasing this plugin

Maintainers can publish from **Actions → Plugin → Run workflow** on the default
branch by entering a stable plugin version without the `v` prefix. The shared
workflow updates `metadata.lua`, creates the version commit and tag, and publishes
the ZIP and manifest in this repository. No local tag or extra release token is
needed. Pull requests run checks only; PR titles no longer trigger publication.

Existing version-tag pushes are supported when `PLUGIN.version` already matches
the tag. If publication fails, re-run the original failed job to resume it.

The workflow follows the shared `@v1` release-tool version. Updating the tool does
not release this plugin. See the [shared workflow documentation](https://github.com/version-fox/plugin-manifest-action)
for the package contract and first-rollout requirements.
