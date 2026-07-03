package_name = "caelestia-grub"
bldit_version = "1"
global_dependencies = { "python", "python-pillow", "python-pyqt6", "grub" }
dependencies = {}

targets = {
    default = {
        build = function()
            return 0
        end,
        install = function()
            -- Pass the prefix down to the install script. If no prefix is set, default to /usr/local
            local p = prefix or "/usr/local"
            return os.execute("sudo PREFIX=" .. p .. " ./scripts/install.sh")
        end,
        uninstall = function()
            local p = prefix or "/usr/local"
            return os.execute("sudo PREFIX=" .. p .. " ./scripts/uninstall.sh")
        end
    }
}
