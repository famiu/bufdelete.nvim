local api = vim.api
local cmd = vim.cmd
local bo = vim.bo

if vim.fn.has('nvim-0.8') == 0 then
    api.nvim_err_writeln('bufdelete.nvim is only available for Neovim versions 0.8 and above')
    return
end

local M = {}

-- Returns buffer name. Returns "[No Name]" if buffer is empty
local function bufname(bufnr)
    local name = api.nvim_buf_get_name(bufnr)

    if name == '' then
        return "[No Name]"
    end

    return name
end

-- Prompt user for choice.
-- This captures the first character inputted after the prompt is shown and returns it.
local function char_prompt(text, choices)
    local choice = vim.fn.confirm(text, table.concat(choices, '\n'), '', 'Q')
    if choice == 0 then
        return 'C' -- Cancel if no choice was made
    else
        return string.match(choices[choice], '&?(%a)')
    end
end

-- Common kill function for Bdelete and Bwipeout.
local function buf_kill(target_buffers, force, wipeout)
    -- Target buffers. Stored in a set-like format to quickly check if buffer needs to be deleted.
    local buf_is_deleted = {}
    for _, v in ipairs(target_buffers) do
        buf_is_deleted[v] = true
    end

    -- If force is disabled, check for modified buffers in range.
    if not force then
        for bufnr, _ in pairs(buf_is_deleted) do
            -- If buffer is modified, prompt user for action.
            if bo[bufnr].modified then
                local choice = char_prompt(
                    string.format(
                        'No write since last change for buffer %d (%s).',
                        bufnr, bufname(bufnr)
                    ),
                    {'&Save', '&Ignore', '&Cancel'}
                )

                if choice == 's' or choice == 'S' then  -- Save changes to the buffer.
                    api.nvim_buf_call(bufnr, function() cmd.write() end)
                elseif choice ~= 'i' and choice ~= 'I' then  -- If not ignored, remove buffer from targets.
                    buf_is_deleted[bufnr] = nil
                end

            elseif bo[bufnr].buftype == 'terminal'
            and vim.fn.jobwait({bo[bufnr].channel}, 0)[1] == -1 then
                local choice = char_prompt(
                    string.format(
                        'Terminal buffer %d (%s) is still running.',
                        bufnr, bufname(bufnr)
                    ),
                    {'&Ignore', '&Cancel'}
                )

                if choice ~= 'i' and choice ~= 'I' then
                    buf_is_deleted[bufnr] = nil
                end
            end
        end
    end

    if next(buf_is_deleted) == nil then
        -- No targets, do nothing
        api.nvim_err_writeln('bufdelete.nvim: No buffers were deleted')
        return
    end

    -- Get list of windows IDs with the buffers to close.
    local windows = vim.tbl_filter(
        function(win)
            return buf_is_deleted[api.nvim_win_get_buf(win)] ~= nil
        end,
        api.nvim_list_wins()
    )

    -- Get list of valid and listed buffers that will not be deleted
    local undeleted_buffers = vim.tbl_filter(
        function(buf)
            return api.nvim_buf_is_valid(buf) and bo[buf].buflisted and not buf_is_deleted[buf]
        end,
        api.nvim_list_bufs()
    )

    -- Switch the windows containing the target buffers to a buffer that's not going to be closed.
    -- Create a new buffer if necessary.
    local switch_bufnr
    -- If there are buffers that are not going to be deleted, just switch all target windows to one
    -- of them.
    if #undeleted_buffers > 0 then
        switch_bufnr = undeleted_buffers[1]
    -- Otherwise create a new buffer and switch all windows to it.
    else
        switch_bufnr = api.nvim_create_buf(true, false)

        if switch_bufnr == 0 then
            api.nvim_err_writeln('bufdelete.nvim: Failed to create buffer')
        end
    end

    -- Switch all target windows to the selected buffer.
    for _, win in ipairs(windows) do
        api.nvim_win_set_buf(win, switch_bufnr)
    end

    -- Close all target buffers one by one.
    for bufnr, _ in pairs(buf_is_deleted) do
        -- Check if buffer is still valid as it may be deleted due to options like bufhidden=wipe.
        if api.nvim_buf_is_valid(bufnr) then
            -- Only use force if buffer is modified, is a terminal or if `force` is true.
            local use_force = force or bo[bufnr].modified or bo[bufnr].buftype == 'terminal'

            -- Trigger BDeletePre autocommand.
            api.nvim_exec_autocmds('User', { pattern = 'BDeletePre ' .. tostring(bufnr) })

            if wipeout then
                cmd.bwipeout({ count = bufnr, bang = use_force })
            else
                cmd.bdelete({ count = bufnr, bang = use_force })
            end

            -- Trigger BDeletePost autocommand.
            api.nvim_exec_autocmds('User', { pattern = 'BDeletePost ' .. tostring(bufnr) })
        end
    end
end

-- Find the first buffer whose name matches the provided pattern. Returns buffer handle.
-- Errors if buffer is not found.
local function find_buffer_with_pattern(pat)
    for _, bufnr in ipairs(api.nvim_list_bufs()) do
        if api.nvim_buf_is_valid(bufnr) and api.nvim_buf_get_name(bufnr):match(pat) then
            return bufnr
        end
    end
end

-- Get buffer handle from buffer name or handle
local function get_buffer_handle(buffer_or_pat)
    if buffer_or_pat == nil then
        return 0
    elseif type(buffer_or_pat) == 'string' then
        local bufnr = tonumber(buffer_or_pat)

        if bufnr ~= nil and math.floor(bufnr) == bufnr then
            return bufnr
        end

        bufnr = find_buffer_with_pattern(buffer_or_pat)
        if bufnr ~= nil then
            return bufnr
        else
            api.nvim_err_writeln('bufdelete.nvim: No matching buffer for ' .. buffer_or_pat)
        end
    end
end

local function get_targets_from_range(left, right)
    local target_buffers = {}

    for i = left, right do
        if api.nvim_buf_is_valid(i) then
            target_buffers[#target_buffers + 1] = i
        end
    end

    return target_buffers
end

-- Get array-like table containing a list of targets from a buffer name, number or range
local function get_targets(buffer_or_range)
    if type(buffer_or_range) == 'table' and #buffer_or_range == 2
        and type(buffer_or_range[1]) == 'number' and buffer_or_range[1] > 0
        and type(buffer_or_range[2]) == 'number' and buffer_or_range[2] > 0
        and api.nvim_buf_is_valid(buffer_or_range[1])
        and api.nvim_buf_is_valid(buffer_or_range[2])
    then
        -- Flip range if needed
        if buffer_or_range[1] > buffer_or_range[2] then
            buffer_or_range[1], buffer_or_range[2] = buffer_or_range[2], buffer_or_range[1]
        end

        return get_targets_from_range(buffer_or_range)
    else
        local bufnr = get_buffer_handle(buffer_or_range)

        if bufnr == nil or not api.nvim_buf_is_valid(bufnr) then
            api.nvim_err_writeln('bufdelete.nvim: Invalid bufnr or range value provided')
            return
        end

        return { bufnr }
    end
end

-- Kill the target buffer(s) (or the current one if 0/nil) while retaining window layout.
-- Can accept range to kill multiple buffers.
function M.bufdelete(buffer_or_range, force)
    buf_kill(get_targets(buffer_or_range), force, false)
end

-- Wipe the target buffer(s) (or the current one if 0/nil) while retaining window layout.
-- Can accept range to wipe multiple buffers.
function M.bufwipeout(buffer_or_range, force)
    buf_kill(get_targets(buffer_or_range), force, true)
end

-- Wrapper around buf_kill for use with vim commands.
function M._buf_kill_cmd(opts, wipeout)
    local target_buffers = {}

    for _, v in ipairs(opts.fargs) do
        local bufnr = get_buffer_handle(v)
        if bufnr ~= nil then
            target_buffers[#target_buffers + 1] = bufnr
        end
    end

    if #opts.fargs == 0 or opts.range > 0 then
        local range_left = opts.range == 2 and opts.line1 or opts.line2
        local range_right = opts.line2

        local new_targets = get_targets_from_range(range_left, range_right)

        for _, v in ipairs(new_targets) do
            target_buffers[#target_buffers + 1] = v
        end
    end

    buf_kill(target_buffers, opts.bang, wipeout)
end

return M
