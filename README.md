# bufdelete.nvim

## About

Neovim's default `:bdelete` command can be quite annoying, since it also messes up your entire window layout by deleting windows. bufdelete.nvim aims to fix that by providing useful commands that allow you to delete a buffer without messing up your window layout.

## Requirements

- Latest Neovim stable version.

**NOTE:** The plugin may work on older versions, but it will always be developed with the latest stable version in mind. So if you use a distribution or operating system that has older versions instead of the newest one, either compile the latest version of Neovim from source or use the plugin with the older version at your own risk. Do NOT open any issues if the plugin doesn't work with an older version of Neovim.

## Installation

- [packer.nvim](https://github.com/wbthomason/packer.nvim/):
```
use 'famiu/bufdelete.nvim'
```

- [vim-plug](https://github.com/junegunn/vim-plug/):
```
Plug 'famiu/bufdelete.nvim'
```

## Usage

bufdelete.nvim is quite straightforward to use. It provides two commands, `:Bdelete` and `:Bwipeout`. They work similarly to `:bdelete` and `:bwipeout`, except they keep your window layout intact. It's also possible to use `:Bdelete!` or `:Bwipeout!` to force the deletion. You may also pass a buffer number, range or buffer name / regexp to either of those two commands.

There's also two Lua functions provided by bufdelete.nvim, `bufdelete` and `bufwipeout`, which do the same thing as their command counterparts. Both of them take two arguments, `buffer_or_range` and `force`. `buffer_or_range` is the buffer number (e.g. `12`), buffer name / regexp (e.g. `foo.txt` or `^bar.txt$`) or a range, which is a table containing two buffer numbers (e.g. `{7, 13}`). `force` determines whether to force the deletion or not. If `buffer_or_range` is either `0` or `nil`, it deletes the current buffer instead. Note that you can't use `0` or `nil` if `buffer_or_range` is a range.

If deletion isn't being forced, you're instead prompted for action for every modified buffer.

Here's an example of how to use the functions:

```lua
-- Forcibly delete current buffer
require('bufdelete').bufdelete(0, true)

-- Wipeout buffer number 100 without force
require('bufdelete').bufwipeout(100)

-- Delete every buffer from buffer 7 to buffer 30 without force
require('bufdelete').bufdelete({7, 30})

-- Delete buffer matching foo.txt with force
require('bufdelete').bufdelete("foo.txt", true)
```

## Behavior

By default, when you delete buffers, bufdelete.nvim switches to a different buffer in every window where one of the target buffers was open. If no buffer other than the target buffers was open, bufdelete creates an empty buffer and switches to it instead.

## User autocommands

bufdelete.nvim triggers the following User autocommands (see `:help User` for more information):
- `BDeletePre {range_start,range_end}` - Prior to deleting a buffer.
- `BDeletePost {range_start,range_end}` - After deleting a buffer.

In both of these cases, `range_start` and `range_end` are replaced by the start and end of the buffer range, respectively. For example, if you use `require('bufdelete').bufdelete({1, 42})`, the autocommand patterns will be `BDeletePre {1,42}` and `BDeletePost {1,42}`.
