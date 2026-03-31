---@class cubby.timestamp
local M = {}

--- Lua pattern matching the default timestamp format YYYY-MM-DD_HH-MM-SS.
--- All filename parsing depends on this pattern. If timestamp_fmt changes,
--- this pattern must be updated to match.
---@type string
M.TIMESTAMP_PATTERN = "%d%d%d%d%-%d%d%-%d%d_%d%d%-%d%d%-%d%d"

---Extract a timestamp from a filename string.
---@param filename string Filename or full path
---@return string? timestamp The extracted timestamp, or nil if not found
function M.extract_timestamp_from_filename(filename)
    local basename = vim.fn.fnamemodify(filename, ":t")
    return basename:match("(" .. M.TIMESTAMP_PATTERN .. ")")
end

---Parse a timestamp string into a Unix epoch number.
---@param timestamp_str string? Timestamp in YYYY-MM-DD_HH-MM-SS format
---@return integer? unix Unix timestamp, or nil on failure
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

---Get a file's modification time formatted as a timestamp string.
---@param filepath string Path to the file
---@param fmt string strftime format string
---@return string? timestamp Formatted timestamp, or nil if file not found
function M.get_file_mtime_as_timestamp(filepath, fmt)
    local stat = vim.uv.fs_stat(filepath)
    if not stat then
        return nil
    end

    return os.date(fmt, stat.mtime.sec)
end

---Get timestamp from filename, falling back to file mtime, then current time.
---@param filename string Filename to extract timestamp from
---@param filepath string Full path for mtime fallback
---@param fmt string strftime format string
---@return string timestamp Always returns a valid timestamp string
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
