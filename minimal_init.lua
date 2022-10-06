-- Minimal init file to run bufdelete with the most basic functionality
-- Run from top-level directory using:
-- nvim --noplugin -u minimal_init.lua

local tmpdir

if vim.fn.has('win32') == 1 then
    tmpdir = os.getenv('TEMP')
else
    tmpdir = '/tmp'
end

local function load_plugins()
    local packer = require('packer')
    local use = packer.use

    packer.reset()
    packer.init {
        package_root = tmpdir .. '/nvim/site/pack',
        git = {
            clone_timeout = -1,
        },
    }

    use('wbthomason/packer.nvim')
    use('famiu/bufdelete.nvim')

    packer.sync()
end

local function load_config()
    vim.cmd.runtime('plugin/bufdelete.lua')
    -- Put your bufdelete.nvim configuration here.
    -- You can also put the steps to reproduce the bug, if applicable.
end

local install_path = tmpdir .. '/nvim/site/pack/packer/start/packer.nvim'

vim.o.packpath = tmpdir .. '/nvim/site'
vim.g.loaded_remote_plugins = 1

if vim.fn.isdirectory(install_path) == 0 then
    vim.fn.system { 'git', 'clone', 'https://github.com/wbthomason/packer.nvim', install_path }
end

load_plugins()

vim.api.nvim_create_autocmd("User", {
    pattern = "PackerComplete",
    callback = load_config,
    once = true
})
