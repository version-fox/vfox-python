# uv and uv-build

[中文](zh-CN/uv.md) | [English](uv.md)

There are two independent things called uv here:

1. **uv-build** is the prebuilt CPython archive this plugin can install instead
   of compiling from source or running a Windows installer. It needs no
   compiler or build dependencies.
2. **uv the tool** installs and manages Pythons of its own under
   `uv python dir`. `vfox link --detect python` adopts those, and the two tools
   can share one interpreter.

## uv-build

On Linux and macOS, a CPython install uses uv-build by default. The plugin
installs the archive when the uv-build index lists the version, and builds from
source with pyenv otherwise. A partial name resolves in the index first, so
`python@3.12` installs the newest 3.12 that the index lists, and `python@3.13t` the
newest free-threaded 3.13 that it lists. Only a line the index does not list
resolves in the list that `vfox search python` shows, and is built from source:

```bash
vfox install python@3.12
```

This path needs none of the `apt` packages a source build needs, and no `sudo`.
A source build still needs them; see
[platforms.md](platforms.md#linux-build-dependencies).

The index lists only some releases, normally the newest patch of each line. When
pyenv lists a newer patch than the index, a partial name such as `python@3.12` still
installs the newest patch the index lists. The newer patch builds from source only
when its exact version is named.

`latest` is not resolved in the index. It stays the newest standard release in the
list, so when pyenv lists a newer release than the index, `latest` builds that
release from source.

`VFOX_PYTHON_USE_UV_BUILD` selects the mode:

- Unset: uv-build for a CPython release the index lists, and a source build for
  any other CPython release. GraalPy, PyPy and Conda keep their own paths. When
  `VFOX_PYTHON_MIRROR` is set and `VFOX_PYTHON_UV_BUILD_MIRROR` is not, CPython is
  a source build from the python.org mirror, because uv-build downloads would come
  from GitHub.
- `0`, `false`, `no` or `off`: a source build on Linux and macOS.
- `1`, `true`, `yes` or `on`: uv-build only. A version the index does not list is
  an error.

If the index cannot be read, the install fails and names
`VFOX_PYTHON_USE_UV_BUILD=0`, so it never starts a source build without saying
so. If the index has no archive for this version on this platform, such as an
architecture it does not cover, the install builds from source and prints a line
saying so. On Linux, if the libc cannot be detected, the install builds from
source; set `VFOX_PYTHON_UV_LIBC` to use uv-build.

The plugin asks `https://vault.vfox.dev/python/uv-build` for the builds of the
running platform, architecture and libc, then hands vfox the archive URL and its
SHA-256. vfox downloads and verifies the archive, unpacks it, and calls
`PostInstall`:

- On Unix the shebang lines of the scripts in `bin` are repaired if they point
  at the temporary build directory.
- On Windows, if the archive has `ensurepip` but no pip command, pip is
  installed and `pip.cmd`/`pip3.cmd` shims are created.

Only CPython archives are listed. GraalPy and other implementations are not
part of uv-build. With `VFOX_PYTHON_USE_UV_BUILD=1`, `vfox install
python@graalpy-24.2.0` fails with a message asking you to unset the variable or
set it to `0`. Without the variable, GraalPy installs from Oracle's archive, as
described in [GraalPy](graalpy.md). The plugin prefers,
in order:

1. `install_only_stripped`
2. `install_only`
3. `pgo+lto-full`
4. any other non-debug archive
5. anything else with a supported extension

A `freethreaded` build becomes a `t` version. A `display_version` from the index
wins over the raw version. Archives must be HTTPS; a build without a usable
SHA-256 fails the install rather than being downloaded unverified.

### Platform and libc

The request carries `os`, `arch` and, on Linux, `libc`:

| Variable | Effect |
| --- | --- |
| `VFOX_PYTHON_USE_UV_BUILD` | Unset: uv-build for CPython when the index lists the version, otherwise a source build. `0`, `false`, `no` or `off`: source build. `1`, `true`, `yes` or `on`: uv-build only |
| `VFOX_PYTHON_UV_LIBC` | `gnu` or `musl`; overrides Linux detection |
| `VFOX_PYTHON_UV_BUILD_MIRROR` | downloads the archives through a mirror |

Linux libc detection runs `ldd --version`, looks for the musl loader, then asks
`getconf GNU_LIBC_VERSION`; if all of that fails it prints a warning and uses
`gnu`. Set the variable when detection is wrong.

The mirror must be an HTTPS URL and must mirror GitHub release downloads at
`<mirror>/<release>/<filename>`. The default GitHub URL becomes
`https://mirror.example/<release>/<filename>`:

```bash
export VFOX_PYTHON_UV_BUILD_MIRROR=https://registry.npmmirror.com/-/binary/python-build-standalone/
```

This is not the same mirror as `VFOX_PYTHON_MIRROR`; that one mirrors
python.org's FTP tree and is described in [mirror.md](mirror.md).

## uv-managed Pythons

`uv python install` downloads CPython into uv's own directory:

```bash
uv python install 3.12
uv python dir
```

The default is `%APPDATA%\uv\python` on Windows and
`$XDG_DATA_HOME/uv/python` or `~/.local/share/uv/python` elsewhere.
`UV_PYTHON_INSTALL_DIR` moves it. `vfox link --detect python` asks
`uv python dir` (and honours the variable) and lists each installation under a
`-uv` name:

```bash
vfox link --detect python
# 3.13.1-uv  ~/.local/share/uv/python/cpython-3.13.1-linux-x86_64-gnu
```

The installation stays uv's. vfox links it, selects it like any other version,
and removes only the link on uninstall. See [link.md](link.md).

## Using uv with the interpreter vfox selected

uv prefers its own managed Pythons by default. That is why `uv venv` can
download a second copy of the same CPython release that vfox already selected.
Tell uv to prefer the interpreter on `PATH` instead:

```bash
export UV_PYTHON_PREFERENCE=system
uv venv --python 3.12
```

`system` means "prefer a non-uv interpreter, fall back to a managed one when
none matches". `only-system` refuses to download and fails when no matching
interpreter exists. `managed` (uv's default) prefers uv's own copies, and
`only-managed` never uses a system interpreter.

To pin one exact interpreter regardless of preference:

```bash
uv venv --python "$(command -v python3)"
# or
UV_PYTHON=/path/to/python uv venv
```

`UV_PYTHON` also accepts a version request; `UV_PYTHON_PREFERENCE` decides
which installation satisfies it.

The `.python-version` file works in both directions: uv writes and reads it, and
this plugin reads it when vfox changes into the project directory. A project
created with uv therefore opens on the same version in vfox, as long as that
version is installed and its name matches the request. A path or a PyPy request
in `.python-version` selects nothing in vfox.

## Best practices

- Decide who owns each interpreter. Either vfox installs it, or uv does and vfox
  links it; avoid keeping a vfox copy and a uv copy of the same release.
- Do not install project packages into uv's base Python with `uv pip install
  --system`, and do not install into a linked system Python. Create a venv:

  ```bash
  uv venv
  uv pip install requests
  ```

- On Debian and Ubuntu, the system Python is externally managed (PEP 668).
  `uv venv` is the shortest way to a writable environment; `python3 -m venv`
  needs `python3-venv` installed first.
- When uv should use the vfox-selected Python, set `UV_PYTHON_PREFERENCE=system`
  in the shell or project environment. Do not set `only-system` on machines
  that also rely on uv downloading versions vfox does not have.
- Use `UV_PYTHON_INSTALL_MIRROR` to mirror uv's own Python downloads, and
  `VFOX_PYTHON_UV_BUILD_MIRROR` for this plugin's uv-build archives. They are
  different download paths.
- Commit `.python-version` with a release such as `3.12` or `cpython-3.12.8`,
  not a machine-specific path, so both tools can resolve it.
