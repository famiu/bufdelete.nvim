local fn = vim.fn
local api = vim.api
local cmd = vim.cmd

local M = {}

-- Common kill function for bdelete and bwipeout
local function buf_kill(kill_command, bufnr, force)
    if bufnr == 0 or bufnr == nil then
        bufnr = api.nvim_get_current_buf()
    end

    if force then
        kill_command = kill_command .. '!'
    else
        kill_command = 'bd'
    end

    -- Get list of windows IDs with the buffer to close
    local windows = vim.tbl_map(
        function(win) return win.winid end,
        vim.tbl_filter(function(win) return win.bufnr == bufnr end, fn.getwininfo())
    )

    if #windows == 0 then
        return
    end

    -- Get list of active buffers
    local buffers = vim.tbl_map(
        function(buf) return buf.bufnr end,
        vim.tbl_filter(function(buf) return buf.listed == 1 end, fn.getbufinfo())
    )

    -- If buffer is modified and force isn't true, print error and abort
    if not force and vim.bo.modified then
        return api.nvim_err_writeln(
            string.format(
                'No write since last change for buffer %d (set force to true to override)',
                bufnr
            )
        )
    end

    local next_buffer

    -- If there is only one buffer (which has to be the current one), create a new buffer
    -- Otherwise, pick the next buffer (wrapping around if necessary)
    if #buffers == 1 then
        next_buffer = api.nvim_create_buf(1, 0)

        if next_buffer == 0 then
            api.nvim_err_writeln("Failed to create new buffer!")
            return
        end
    else
        for i, v in ipairs(buffers) do
            if v == bufnr then
                next_buffer = buffers[i % #buffers + 1]
                break
            end
        end
    end

    -- Switch to the picked buffer for each window in 'windows'
    for _, win in ipairs(windows) do
        api.nvim_win_set_buf(win, next_buffer)
    end

    cmd(string.format('%s %d', kill_command, bufnr))
end

-- Kill the target buffer (or the current one if 0/nil) while retaining window layout
function M.bufdelete(bufnr, force)
    buf_kill('bd', bufnr, force)
end

-- Wipe the target buffer (or the current one if 0/nil) while retaining window layout
function M.bufwipeout(bufnr, force)
    buf_kill('bw', bufnr, force)
end

-- Wrapper around bufdelete for use with vim commands
function M.bufdelete_cmd(bufnr, bang)
    M.bufdelete(tonumber(bufnr == '' and '0' or bufnr), bang == '!')
end

-- Wrapper around bufwipeout for use with vim commands
function M.bufwipeout_cmd(bufnr, bang)
    M.bufwipeout(tonumber(bufnr == '' and '0' or bufnr), bang == '!')
end

return M
