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

Set `VFOX_PYTHON_USE_UV_BUILD=1` to install prebuilt Python archives from the
vfox vault uv-build endpoint instead of building from pyenv/python-build.

On Linux, libc is detected automatically. Set `VFOX_PYTHON_UV_LIBC=gnu` or
`VFOX_PYTHON_UV_LIBC=musl` to override detection.

Set `VFOX_PYTHON_UV_BUILD_MIRROR` to download uv-build archives from a mirror.
For example:

```bash
export VFOX_PYTHON_UV_BUILD_MIRROR=https://registry.npmmirror.com/-/binary/python-build-standalone/
```
