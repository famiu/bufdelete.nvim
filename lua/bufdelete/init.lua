local api = vim.api
local cmd = vim.cmd
local bo = vim.bo

if vim.fn.has('nvim-0.8') == 0 then
    api.nvim_err_writeln('bufdelete.nvim is only available for Neovim versions 0.8 and above')
    return
end

local M = {}

-- Check if buffer needs deletion. Ensures that only loaded buffers are deleted while all valid
-- buffers can be wiped out.
local function buf_needs_deletion(bufnr, wipeout)
    if wipeout then
        return api.nvim_buf_is_valid(bufnr)
    else
        return api.nvim_buf_is_loaded(bufnr)
    end
end

-- Common kill function for Bdelete and Bwipeout.
local function buf_kill(range, force, wipeout)
    if range == nil then
        return
    end

    if range[1] == 0 then
        range[1] = api.nvim_get_current_buf()
        range[2] = range[1]
    end

    -- Target buffers. Stored in a set-like format to quickly check if buffer needs to be deleted.
    local target_buffers = {}
    for bufnr=range[1], range[2] do
        if buf_needs_deletion(bufnr, wipeout) then
            target_buffers[bufnr] = true
        end
    end

    -- If force is disabled, check for modified buffers in range.
    if not force then
        for bufnr, buf in pairs(target_buffers) do
            -- If buffer is modified, prompt user for action.
            if bo[bufnr].modified then
                api.nvim_echo({{
                    string.format(
                        'No write since last change for buffer %d (%s). Would you like to:\n' ..
                        '(s)ave and close\n(i)gnore changes and close\n(c)ancel',
                        bufnr, api.nvim_buf_get_name(bufnr)
                    )
                }}, false, {})

                local choice = string.char(vim.fn.getchar())

                if choice == 's' or choice == 'S' then  -- Save changes to the buffer.
                    api.nvim_buf_call(bufnr, function() cmd.write() end)
                elseif choice ~= 'i' and choice ~= 'I' then  -- If not ignored, do not close
                    target_buffers[bufnr] = nil
                end

                -- Clear message area.
                cmd.echo('""')
                cmd.redraw()
            end

        end
    end

    if next(target_buffers) == nil then
        -- No targets, do nothing
        api.nvim_err_writeln("bufdelete.nvim: No buffers were deleted")
        return
    end

    -- Get list of windows IDs with the buffers to close.
    local windows = vim.tbl_filter(
        function(win)
            return target_buffers[api.nvim_win_get_buf(win)] ~= nil
        end,
        api.nvim_list_wins()
    )

    -- Get list of valid and listed buffers outside the range.
    local buffers_outside_range = vim.tbl_filter(
        function(buf)
            return api.nvim_buf_is_valid(buf) and bo[buf].buflisted
                and (buf < range[1] or buf > range[2])
        end,
        api.nvim_list_bufs()
    )

    -- Switch the windows containing the target buffers to a buffer that's not going to be closed.
    -- Create a new buffer if necessary.
    local switch_bufnr
    -- If there are buffers outside range, just switch all target windows to one of them.
    if #buffers_outside_range > 0 then
        local buffer_before_range  -- Buffer right before the range.
        -- First, try to find a buffer after the range. If there are no buffers after the range,
        -- use the buffer right before the range instead.
        for _, v in ipairs(buffers_outside_range) do
            if v < range[1] then
                buffer_before_range = v
            end
            if v > range[2] then
                switch_bufnr = v
                break
            end
        end
        -- Couldn't find buffer after range, use buffer before range instead.
        if switch_bufnr == nil then
            switch_bufnr = buffer_before_range
        end
    -- Otherwise create a new buffer and switch all windows to it.
    else
        switch_bufnr = api.nvim_create_buf(true, false)

        if switch_bufnr == 0 then
            api.nvim_err_writeln("bufdelete.nvim: Failed to create buffer")
        end
    end

    -- Switch all target windows to the selected buffer.
    for _, win in ipairs(windows) do
        api.nvim_win_set_buf(win, switch_bufnr)
    end

    -- Trigger BDeletePre autocommand.
    api.nvim_exec_autocmds("User", {
        pattern = string.format("BDeletePre {%d,%d}", range[1], range[2])
    })
    -- Close all target buffers one by one.
    for bufnr, _ in pairs(target_buffers) do
        -- Check if buffer is still valid as it may be deleted due to options like bufhidden=wipe.
        if buf_needs_deletion(bufnr, wipeout) then
            -- Only use force if buffer is modified or if `force` is true.
            local use_force = force or bo[bufnr].modified
            if wipeout then
                cmd.bwipeout({ count = bufnr, bang = use_force })
            else
                cmd.bdelete({ count = bufnr, bang = use_force })
            end
        end
    end
    -- Trigger BDeletePost autocommand.
    api.nvim_exec_autocmds("User", {
        pattern = string.format("BDeletePost {%d,%d}", range[1], range[2])
    })
end

-- Find the first buffer whose name matches the provided pattern. Returns buffer handle.
-- Errors if buffer is not found.
local function find_buffer_with_pattern(pat, wipeout)
    for _, bufnr in ipairs(api.nvim_list_bufs()) do
        if buf_needs_deletion(bufnr, wipeout) and api.nvim_buf_get_name(bufnr):match(pat) then
            return bufnr
        end
    end

    api.nvim_err_writeln("bufdelete.nvim: No matching buffer for " .. pat)
end

local function get_range(buffer_or_range, wipeout)
    if buffer_or_range == nil then
        return { 0, 0 }
    elseif type(buffer_or_range) == 'number' and buffer_or_range >= 0
        and api.nvim_buf_is_valid(buffer_or_range)
    then
        return { buffer_or_range, buffer_or_range }
    elseif type(buffer_or_range) == 'string' then
        local bufnr = find_buffer_with_pattern(buffer_or_range, wipeout)
        return bufnr ~= nil and { bufnr, bufnr } or nil
    elseif type(buffer_or_range) == 'table' and #buffer_or_range == 2
        and type(buffer_or_range[1]) == 'number' and buffer_or_range[1] > 0
        and type(buffer_or_range[2]) == 'number' and buffer_or_range[2] > 0
        and api.nvim_buf_is_valid(buffer_or_range[1])
        and api.nvim_buf_is_valid(buffer_or_range[2])
    then
        if buffer_or_range[1] > buffer_or_range[2] then
            buffer_or_range[1], buffer_or_range[2] = buffer_or_range[2], buffer_or_range[1]
        end
        return buffer_or_range
    else
        api.nvim_err_writeln('bufdelete.nvim: Invalid bufnr or range value provided')
        return
    end
end

-- Kill the target buffer(s) (or the current one if 0/nil) while retaining window layout.
-- Can accept range to kill multiple buffers.
function M.bufdelete(buffer_or_range, force)
    buf_kill(get_range(buffer_or_range, false), force, false)
end

-- Wipe the target buffer(s) (or the current one if 0/nil) while retaining window layout.
-- Can accept range to wipe multiple buffers.
function M.bufwipeout(buffer_or_range, force)
    buf_kill(get_range(buffer_or_range, true), force, true)
end

-- Wrapper around buf_kill for use with vim commands.
local function buf_kill_cmd(opts, wipeout)
    local range
    if opts.range == 0 then
        if #opts.fargs == 1 then  -- Buffer name is provided
            local bufnr = find_buffer_with_pattern(opts.fargs[1], wipeout)
            if bufnr == nil then
                return
            end
            range = { bufnr, bufnr }
        else
            range = { opts.line2, opts.line2 }
        end
    else
        if #opts.fargs == 1 then
            api.nvim_err_writeln("bufdelete.nvim: Cannot use buffer name and buffer number at the "
                                 .. "same time")
        else
            range = { opts.range == 2 and opts.line1 or opts.line2, opts.line2 }
        end
    end
    buf_kill(range, opts.bang, wipeout)
end

-- Define Bdelete and Bwipeout.
api.nvim_create_user_command('Bdelete', function(opts) buf_kill_cmd(opts, false) end,
                                 { bang = true, count = true, addr = 'buffers', nargs = '?' })
api.nvim_create_user_command('Bwipeout', function(opts) buf_kill_cmd(opts, true) end,
                                 { bang = true, count = true, addr = 'buffers', nargs = '?' })

return M
