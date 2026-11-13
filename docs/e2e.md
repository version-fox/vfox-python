# End-to-end tests

[中文](zh-CN/e2e.md) | [English](e2e.md)

There are two E2E layers:

1. **Container suite** in `tests/e2e/` runs real installs inside a Linux
   container and a Windows container. It is the isolated path that checks the
   GraalPy download, `ensurepip`, `PATH` and `.python-version` behavior.
2. **Runner suite** in `.github/workflows/e2e.yml` runs the broader matrix
   natively on GitHub-hosted Linux and Windows runners: CPython source builds,
   the python.org and Huawei mirrors, uv-build, `vfox link --detect` and PEP 514
   registration.

Both are triggered by pull requests. The offline Lua hook tests live in
`test.yml` and are described in [development.md](development.md).

## Linux container

The image starts from Ubuntu 24.04, installs vfox 1.1.0 from the checksum-pinned
release archive, copies the plugin source, and runs GraalPy end to end:

```bash
docker build --file tests/e2e/linux/Dockerfile --tag vfox-python-e2e-linux .
docker run --rm -e GRAALPY_VERSION=graalpy-24.2.0 vfox-python-e2e-linux
```

The workflow runs the matrix `graalpy-24.2.0` and
`graalpy-community-24.2.0`. Each run checks:

- `vfox add` accepts the plugin built from the checkout,
- `vfox install` downloads Oracle's archive and verifies its SHA-256,
- `python -V` and `sys.implementation.name` report GraalPy,
- `python -m pip` and `pip` both work,
- a project `.python-version` selects the installed GraalPy.

## Windows container

The image starts from Windows Server Core, installs PowerShell 7, vfox 1.1.0
and the plugin, then installs GraalPy amd64:

```powershell
docker build --file tests/e2e/windows/Dockerfile --tag vfox-python-e2e-windows .
docker run --rm -e GRAALPY_VERSION=graalpy3.13-community-25.5.5 vfox-python-e2e-windows
```

Windows containers need a Windows host in Windows-container mode. The base
image is `mcr.microsoft.com/windows/servercore:ltsc2025-KB5122871-amd64`, the
same image the Java plugin uses in CI, so the host and container OS versions
match on `windows-latest`.

The Windows run checks the same install, `python`, `pip` and `.python-version`
behavior. PEP 514 registration is checked by the runner suite, because the
Server Core image has no Python launcher.

## Environment knobs

| Variable | Default | Meaning |
| --- | --- | --- |
| `GRAALPY_VERSION` | Linux `graalpy-24.2.0`; Windows `graalpy3.13-community-25.5.5` | GraalPy version to install |
| `GITHUB_TOKEN`, `GH_TOKEN` | unset | raise the GitHub API limit when listing GraalPy releases |

The installs retry three times because GitHub release downloads occasionally
end with a transient EOF.
