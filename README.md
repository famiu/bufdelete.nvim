# bufdelete.nvim
## About
Neovim's default `:bdelete` command can be quite annoying, since it also messes up your entire window layout by deleting windows. bufdelete.nvim aims to fix that by providing useful commands that allow you to delete a buffer without messing up your window layout.

## Requirements
* Neovim >= 0.5

**NOTE:** The plugin may work on older versions, but I can't test it out myself. So if you use an older Neovim version and the plugin works for you. Please file an issue informing me about your current Neovim version.

## Installation
* [packer.nvim](https://github.com/wbthomason/packer.nvim/):
```
use 'famiu/bufdelete.nvim'
```

* [paq-nvim](https://github.com/savq/paq-nvim/)
```
paq 'famiu/bufdelete.nvim'
```

* [vim-plug](https://github.com/junegunn/vim-plug/):
```
Plug 'famiu/bufdelete.nvim'
```

## Usage
bufdelete.nvim is quite straightforward to use. It provides two commands, `:Bdelete` and `:Bwipeout`. They work similarly to `:bdelete` and `:bwipeout`, except they keep your window layout intact. It's also possible to use `:Bdelete!` or `:Bwipeout!` to force the deletion. You may also pass a buffer number to either of those two commands to delete that buffer instead of the current one.

There's also two Lua functions provided by bufdelete.nvim, `bufdelete` and `bufwipeout`, which do the same thing as their command counterparts. Both of them take two arguments, `bufnr` and `force`, where `bufnr` is the number of the buffer, and `force` determines whether to force the deletion or not. If `bufnr` is either `0` or `nil`, it deletes the current buffer instead.

Here's an example of how to use the functions:
```lua
-- Force delete current buffer
require('bufdelete').bufdelete(0, true)

-- Wipeout buffer number 100 without force
require('bufdelete').bufwipeout(100)
```

## Behavior
By default, when you delete a buffer, bufdelete.nvim switches to the next buffer (wrapping around if necessary) in every window where the target buffer was open. If no buffer other than the target buffer was open, bufdelete.nvim creates an empty buffer and switches to it instead.

## Note
This plugin is still quite new and might have some bugs. And in case it does, feel free to make an issue here to report them.

## Self-plug
If you liked this plugin, also check out:
- [feline.nvim](https://github.com/famiu/feline.nvim) - A nice customizable statusline for Neovim written in Lua.
