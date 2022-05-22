local api = vim.api
local bo = vim.bo

local M = {}

-- Common kill function for bdelete and bwipeout
local function buf_kill(kill_command, bufnr, force)
    -- If buffer is modified and force isn't true, print error and abort
    if not force and bo[bufnr].modified then
        api.nvim_echo({{
            string.format(
                'No write since last change for buffer %d. Would you like to:\n' ..
                '(s)ave and close\n(i)gnore changes and close\n(c)ancel',
                bufnr
            )
        }}, false, {})

        local choice = string.char(vim.fn.getchar())

        if choice == 's' or choice == 'S' then
            vim.cmd('write')
        elseif choice == 'i' or choice == 'I' then
            force = true;
        else
            return
        end
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

    -- Get list of valid and listed buffers
    local buffers = vim.tbl_filter(
        function(buf) return
            api.nvim_buf_is_valid(buf) and bo[buf].buflisted
        end,
        api.nvim_list_bufs()
    )

    -- If there is only one buffer (which has to be the current one), Neovim will automatically
    -- create a new buffer on :bd.
    -- For more than one buffer, pick the next buffer (wrapping around if necessary)
    if #buffers > 1 then
        for i, v in ipairs(buffers) do
            if v == bufnr then
                local next_buffer = buffers[i % #buffers + 1]
                for _, win in ipairs(windows) do
                    api.nvim_win_set_buf(win, next_buffer)
                end

                break
            end
        end
    end

    -- Check if buffer still exists, to ensure the target buffer wasn't killed
    -- due to options like bufhidden=wipe.
    if api.nvim_buf_is_valid(bufnr) then
        -- Execute the BDeletePre and BDeletePost autocommands before and after deleting the buffer
        api.nvim_exec_autocmds("User", { pattern = "BDeletePre" })
        vim.cmd(string.format('%s %d', kill_command, bufnr))
        api.nvim_exec_autocmds("User", { pattern = "BDeletePost" })
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
