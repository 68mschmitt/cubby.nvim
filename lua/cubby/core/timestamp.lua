local M = {}

--- Lua pattern matching the default timestamp format YYYY-MM-DD_HH-MM-SS.
--- All filename parsing depends on this pattern. If timestamp_fmt changes,
--- this pattern must be updated to match.
M.TIMESTAMP_PATTERN = "%d%d%d%d%-%d%d%-%d%d_%d%d%-%d%d%-%d%d"

function M.extract_timestamp_from_filename(filename)
    local basename = vim.fn.fnamemodify(filename, ":t")
    return basename:match("(" .. M.TIMESTAMP_PATTERN .. ")")
end

function M.parse_to_unix(timestamp_str)
    if not timestamp_str then
        return nil
    end

    local year, month, day, hour, min, sec = timestamp_str:match("(%d%d%d%d)%-(%d%d)%-(%d%d)_(%d%d)%-(%d%d)%-(%d%d)")

    if not year then
        return nil
    end

    return os.time({
        year = tonumber(year),
        month = tonumber(month),
        day = tonumber(day),
        hour = tonumber(hour),
        min = tonumber(min),
        sec = tonumber(sec),
    })
end

function M.get_file_mtime_as_timestamp(filepath, fmt)
    local stat = vim.loop.fs_stat(filepath)
    if not stat then
        return nil
    end

    return os.date(fmt, stat.mtime.sec)
end

function M.preserve_or_fallback_timestamp(filename, filepath, fmt)
    local ts = M.extract_timestamp_from_filename(filename)
    if ts then
        return ts
    end

    ts = M.get_file_mtime_as_timestamp(filepath, fmt)
    if ts then
        return ts
    end

    local time = require("cubby.core.time")
    return time.now_stamp(fmt)
end

return M
