local api = vim.api
local cmd = vim.cmd
local bo = vim.bo

local M = {}

-- Common kill function for bdelete and bwipeout
local function buf_kill(kill_command, bufnr, force)
    -- If buffer is modified and force isn't true, print error and abort
    if not force and bo.modified then
        return api.nvim_err_writeln(
            string.format(
                'No write since last change for buffer %d (set force to true to override)',
                bufnr
            )
        )
    end

    if bufnr == 0 or bufnr == nil then
        bufnr = api.nvim_get_current_buf()
    end

    if force then
        kill_command = kill_command .. '!'
    end

    -- Get list of windows IDs with the buffer to close
    local windows = vim.tbl_filter(
        function(win) return api.nvim_win_get_buf(win) == bufnr end,
        api.nvim_list_wins()
    )

    if #windows == 0 then
        return
    end

    -- Get list of active buffers
    local buffers = vim.tbl_filter(
        function(buf) return
            bo[buf].buflisted and api.nvim_buf_is_valid(buf)
        end,
        api.nvim_list_bufs()
    )

    -- If there is only one buffer (which has to be the current one), vim will
    -- create a new buffer on :bd.  If there are only two buffers (one of which
    -- has to be the current one), vim will switch to the other buffer on :bd
    -- Otherwise, pick the next buffer (wrapping around if necessary)
    if #buffers > 2 then
        for i, v in ipairs(buffers) do
            if v == bufnr then
                local next_buffer = buffers[i % #buffers + 1]
                for _, win in ipairs(windows) do
                    api.nvim_win_set_buf(win, next_buffer)
                end
            end
        end
    end

    -- Check if buffer still exists, to ensure the target buffer wasn't killed
    -- due to options like bufhidden=wipe.
    if(api.nvim_buf_is_valid(bufnr)) then
        cmd(string.format('%s %d', kill_command, bufnr))
    end
end

-- Kill the target buffer (or the current one if 0/nil) while retaining window layout
function M.bufdelete(bufnr, force)
    buf_kill('bd', bufnr, force)
end

-- Wipe the target buffer (or the current one if 0/nil) while retaining window layout
function M.bufwipeout(bufnr, force)
    buf_kill('bw', bufnr, force)
end

-- Wrapper around buf_kill for use with vim commands
local function buf_kill_cmd(kill_command, bufnr, bang)
    buf_kill(kill_command, tonumber(bufnr == '' and '0' or bufnr), bang == '!')
end

-- Wrappers around bufdelete and bufwipeout for use with vim commands
function M.bufdelete_cmd(bufnr, bang)
    buf_kill_cmd('bd', bufnr, bang)
end

function M.bufwipeout_cmd(bufnr, bang)
    buf_kill_cmd('bw', bufnr, bang)
end

return M
