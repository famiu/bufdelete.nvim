if exists('g:loaded_bufdelete') | finish | endif

if !has('nvim-0.5')
    echohl Error
    echomsg "bufdelete.nvim is only available for Neovim versions 0.5 and above"
    echohl clear
    finish
endif

let s:save_cpo = &cpo
set cpo&vim

"" Define commands for bufdelete
command! -bang -nargs=? Bdelete lua require('bufdelete').bufdelete_cmd(<q-args>, <q-bang>)
command! -bang -nargs=? Bwipeout lua require('bufdelete').bufwipeout_cmd(<q-args>, <q-bang>)

let g:loaded_bufdelete = 1

let &cpo = s:save_cpo
unlet s:save_cpo

