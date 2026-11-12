# Mirror

[中文](zh-CN/mirror.md) | [English](mirror.md)

## python.org

`VFOX_PYTHON_MIRROR` points the python.org downloads at a mirror. It must be a
URL with the same tree as `https://www.python.org/ftp/python/`; a trailing
slash is added when it is missing:

```bash
export VFOX_PYTHON_MIRROR=https://mirrors.huaweicloud.com/python/
```

What it changes:

- On Windows, installers are downloaded from
  `<mirror>/<version>/python-<version>-<arch>.exe` (or the MSI).
- On Linux and macOS, the plugin gives python-build the mirror through
  `PYTHON_BUILD_MIRROR_URL`, so the source archive comes from the mirror.
- The `PreInstall` check for a source release asks the mirror, not python.org.

The version list still comes from the pyenv index or the python.org Windows
release page; a mirror changes downloads, not which versions exist.

When the variable is set, the plugin also sets
`PYTHON_BUILD_MIRROR_URL_SKIP_CHECKSUM=1`, because a mirror's archive may not
have python-build's recorded checksum. Only use a mirror you trust.

### What the mirror needs

```
<mirror>/
  3.12.2/
    Python-3.12.2.tar.xz
    Python-3.12.2.tar.bz2        # when the release only has bz2
    python-3.12.2-amd64.exe      # Windows
    python-3.12.2-amd64.msi      # older Windows releases
```

Not every version has every file. `VFOX_PYTHON_MIRROR` applies to both the
source and the Windows installer paths, so a mirror used on both platforms must
carry both.

## uv-build

`VFOX_PYTHON_UV_BUILD_MIRROR` mirrors the prebuilt uv-build archives. It must be
HTTPS and must lay archives out as GitHub release downloads:

```
<mirror>/<release>/<filename>
```

The default GitHub URL
`https://github.com/astral-sh/python-build-standalone/releases/download/<release>/<filename>`
becomes `<mirror>/<release>/<filename>`. For example:

```bash
export VFOX_PYTHON_UV_BUILD_MIRROR=https://registry.npmmirror.com/-/binary/python-build-standalone/
```

The plugin verifies each archive with the SHA-256 from the uv-build index before
unpacking. A mirror that serves different bytes fails the install with
`Checksum error`, which is the intended behaviour: change the index or the
mirror, do not bypass the check.

## Proxies

vfox's HTTP client and python-build's `curl`/`wget` use the usual proxy
variables:

```bash
export HTTPS_PROXY=http://proxy.example:8080
export HTTP_PROXY=http://proxy.example:8080
```

A proxy is simpler than a mirror when only the connection is slow. A mirror
also helps when the download itself is blocked.

## Which variable to use

| Goal | Variable |
| --- | --- |
| python.org installers and source archives | `VFOX_PYTHON_MIRROR` |
| uv-build prebuilt archives | `VFOX_PYTHON_UV_BUILD_MIRROR` |
| uv's own `uv python install` downloads | `UV_PYTHON_INSTALL_MIRROR` |
| Linux libc override for uv-build | `VFOX_PYTHON_UV_LIBC` |

The first two are the plugin's; the uv one belongs to uv and works only when you
run uv yourself. See [uv.md](uv.md).
