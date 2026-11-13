# 从源码安装

[中文](install-from-source.md) | [English](../install-from-source.md)

在下一个版本发布之前先试用 `main`：

```bash
git clone https://github.com/version-fox/vfox-python.git
cd vfox-python
zip -qr /tmp/vfox-python.zip metadata.lua hooks lib bin
vfox add --source /tmp/vfox-python.zip
```

`vfox add --source` 接受本地 ZIP。插件按 `metadata.lua` 里的名字注册
（`python`），版本就是 `PLUGIN.version` 写的值；它不是正式发布版。

要用新的 checkout 替换源码安装：

```bash
vfox remove python
vfox add --source /tmp/vfox-python.zip
```

`vfox remove` 也会删除用这个插件安装的版本，以及 `vfox info python` 下的缓存；
已安装的 Python 会被删掉，需要重装时先导出列表。

也可以手工把插件目录复制进 vfox 的插件目录，但用 ZIP 能让 vfox 读
`metadata.lua` 并按正常方式注册。安装前在 checkout 里运行
`vfox plugin test .`；它不注册任何东西，跑 Detect 测试需要 vfox 1.1.0。详见
[development.md](development.md)。
