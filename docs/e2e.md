# End-to-end tests

[中文](zh-CN/e2e.md) | [English](e2e.md)

`tests/e2e` is a Go module. Its Linux and Windows packages drive vfox, the
plugin and real installs with the Go testing framework, both on the runner and
in Docker containers. `.github/workflows/e2e.yml` only installs Go and runs
`go test`; the install commands and every assertion are in Go.

## Layout

| Path | Purpose |
| --- | --- |
| `common/` | builds the plugin zip, installs vfox 1.1.0, runs host commands, reads the uv-build index, asserts |
| `linux/e2e_test.go` | `TestNativeE2E`: source build, mirror, uv-build, GraalPy, `vfox link --detect`, `.python-version` |
| `linux/container_test.go` | `TestContainerE2E`: a bare Ubuntu 24.04 container for uv-build, and one for each GraalPy release |
| `linux/Dockerfile` | Ubuntu 24.04 with `ca-certificates`, `curl`, `tar`, `xz-utils` and `zip`; no compiler and no `-dev` packages |
| `windows/e2e_test.go` | `TestNativeE2E`: python.org EXE installer, mirror, uv-build, GraalPy with launcher registration, `.python-version` |
| `windows/container_test.go` | `TestContainerE2E`: a Server Core container with PowerShell 7, the Visual C++ runtime and vfox, GraalPy |
| `windows/Dockerfile`, `windows/bootstrap-tools.ps1` | provision the Server Core image: PowerShell 7, the Visual C++ runtime and vfox |

The Dockerfiles only provision the environment. The Go tests copy the plugin
into the container and drive every step from there.

## What the subtests check

Linux, on the runner:

- `source build`: CPython 3.12.2 built from source.
- `mirror`: CPython 3.12.1 from the huaweicloud mirror.
- `uv-build`: the newest CPython 3.11 uv-build archive, with pip.
- `graalpy`: GraalPy 24.2.0, asserted by implementation name.
- `link`: `vfox link --detect python` adopts an installed Python, and `vfox list` shows it as linked.
- `python-version`: a project `.python-version` naming the uv-build CPython wins over the global GraalPy. The check prints the implementation name, so GraalPy cannot pass it.

Linux, in containers:

- `uv-build without build packages`: the uv-build CPython imports `ssl`, `sqlite3`, `bz2`, `lzma`, `ctypes`, `readline`, `curses`, `zlib` and `hashlib`, and pip runs. This is the check behind the answer in [platforms.md](platforms.md#linux-build-dependencies): uv-build needs no apt packages.
- `graalpy-24.2.0` and `graalpy-community-24.2.0`: GraalPy installs and runs with pip, and a `.python-version` selects the uv-build CPython over the global GraalPy.

Windows, on the runner:

- `installer`: CPython 3.12.2, and the download URL is the EXE, `python-3.12.2-amd64.exe`.
- `mirror`, `uv-build`, `graalpy`, `python-version`: as on Linux. The GraalPy subtest finds its entry in `py -0p`, because launcher registration is on by default.

Windows, in a container: GraalPy 25.5.5 (Community, Python 3.13).

## Run

```bash
cd tests/e2e
go test -v ./linux
go test -v ./windows   # on a Windows host with Docker in Windows container mode
```

Set `VFOX_SKIP_CONTAINER_E2E=1` to run only the native suite, for example on a
machine without Docker:

```bash
VFOX_SKIP_CONTAINER_E2E=1 go test -v ./linux
```

`-run` selects subtests. `python-version` needs the `uv-build` subtest to run
first, so include both:

```bash
go test -v -run 'TestNativeE2E/^(uv-build|graalpy|python-version)$' ./linux
```

Requirements:

- The `source build` and `mirror` subtests need the Linux build packages from
  [platforms.md](platforms.md#linux-build-dependencies). The GitHub
  `ubuntu-latest` runner has them: the CI source builds install nothing extra. A
  development machine may not, and those two subtests fail without them. The
  uv-build, GraalPy and container subtests need none of them.
- The Windows container test needs Docker in Windows container mode. The
  `windows-latest` runner provides it.
- `GITHUB_TOKEN` or `GH_TOKEN` is optional. When set, GraalPy installs use it for
  GitHub API requests and avoid the anonymous rate limit. Without it, the plugin
  falls back to the asset URL it builds itself.
