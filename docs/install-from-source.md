# Install from source

[中文](zh-CN/install-from-source.md) | [English](install-from-source.md)

Try `main` before the next release:

```bash
git clone https://github.com/version-fox/vfox-python.git
cd vfox-python
zip -qr /tmp/vfox-python.zip metadata.lua hooks lib
vfox add --source /tmp/vfox-python.zip
```

`vfox add --source` accepts a local ZIP. The plugin is registered under the
name in `metadata.lua` (`python`), and its version is whatever `PLUGIN.version`
says; it is not a release.

To replace a source install with a newer checkout:

```bash
vfox remove python
vfox add --source /tmp/vfox-python.zip
```

`vfox remove` also removes the versions installed with that plugin. The cache
under `vfox info python` is removed; installed Pythons are deleted, so export a
list first if you need to reinstall them.

The plugin directory can also be copied into the vfox plugin directory by hand,
but the ZIP route lets vfox read `metadata.lua` and register the plugin in the
usual way. Run `vfox plugin test .` from the checkout before installing; it
does not register anything and needs vfox 1.1.0 for the Detect tests. See
[development.md](development.md).
