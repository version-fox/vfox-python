--- !!! DO NOT EDIT OR RENAME !!!
PLUGIN = {}

--- !!! MUST BE SET !!!
--- Plugin name
PLUGIN.name = "python"
--- Plugin version
PLUGIN.version = "0.3.1"
--- Plugin homepage
PLUGIN.homepage = "https://github.com/version-fox/vfox-python"
--- Plugin license, please choose a correct license according to your needs.
PLUGIN.license = "Apache 2.0"
--- Plugin description
PLUGIN.description = "Python language support, https://www.python.org"


--- !!! OPTIONAL !!!
--[[
NOTE:
    Minimum compatible vfox version.
    If the plugin is not compatible with the current vfox version,
    vfox will not load the plugin and prompt the user to upgrade vfox.
 --]]
PLUGIN.minRuntimeVersion = "0.4.0"
-- Some things that need user to be attention!
PLUGIN.notes = {
    "Mirror Setting:",
    "You can use VFOX_PYTHON_MIRROR environment variable to set mirror.",
    "eg: `export VFOX_PYTHON_MIRROR=https://mirrors.huaweicloud.com/python/`",
    " ",
}
