---@class cubby.naming
local M = {}

local fs = require("cubby.fs")

---Convert a strftime format string to a Lua pattern for matching timestamps.
---@param fmt string strftime format string (e.g., "%Y-%m-%d_%H-%M-%S")
---@return string pattern Lua pattern string
local function timestamp_fmt_to_pattern(fmt)
    local token_map = {
        Y = "%d%d%d%d", -- 4-digit year
        m = "%d%d", -- 2-digit month
        d = "%d%d", -- 2-digit day
        H = "%d%d", -- 2-digit hour (24h)
        M = "%d%d", -- 2-digit minute
        S = "%d%d", -- 2-digit second
        I = "%d%d", -- 2-digit hour (12h)
        p = "[AP]M", -- AM/PM
        y = "%d%d", -- 2-digit year
        j = "%d%d%d", -- 3-digit day of year
    }

    -- First, escape special Lua pattern characters in the format string
    -- This protects literal characters like hyphens, underscores, etc.
    local escaped = fmt:gsub("([%.%+%-%*%?%[%]%^%$])", "%%%1")

    -- Then replace strftime tokens with Lua pattern equivalents
    local pattern = escaped:gsub("%%(%a)", function(token)
        return token_map[token] or ("%" .. token)
    end)

    return pattern
end

---Sanitize a user-provided label for use in filenames.
---Lowercases, replaces spaces with hyphens, strips special characters.
---@param input string? Raw label input
---@return string sanitized Sanitized label (may be empty)
function M.sanitize_label(input)
    if not input or input == "" then
        return ""
    end

    local label = input:lower()
    label = label:gsub("%s+", "-")
    label = label:gsub("[^a-z0-9%-]", "")
    label = label:gsub("%-+", "-")
    label = label:gsub("^%-+", "")
    label = label:gsub("%-+$", "")

    return label
end

---Check whether a label is non-empty and valid.
---@param label string? Label to validate
---@return boolean
function M.validate_label(label)
    return label ~= nil and label ~= ""
end

---Generate a timestamp string for the current time.
---@param fmt string strftime format string (required)
---@return string timestamp
function M.now_stamp(fmt)
    assert(fmt, "cubby: timestamp format required (did you call setup()?)")
    return os.date(fmt)
end

---Format a Unix timestamp as a human-readable relative time string.
---@param unix_timestamp integer Unix epoch timestamp
---@return string relative e.g., "just now", "5 minutes ago", "yesterday"
function M.format_relative_time(unix_timestamp)
    local now = os.time()
    local diff = now - unix_timestamp

    if diff < 60 then
        return "just now"
    elseif diff < 3600 then
        local minutes = math.floor(diff / 60)
        return string.format("%d minute%s ago", minutes, minutes > 1 and "s" or "")
    elseif diff < 86400 then
        local hours = math.floor(diff / 3600)
        return string.format("%d hour%s ago", hours, hours > 1 and "s" or "")
    elseif diff < 172800 then
        return "yesterday"
    elseif diff < 604800 then
        local days = math.floor(diff / 86400)
        return string.format("%d day%s ago", days, days > 1 and "s" or "")
    elseif diff < 1209600 then
        return "1 week ago"
    elseif diff < 2592000 then
        local weeks = math.floor(diff / 604800)
        return string.format("%d week%s ago", weeks, weeks > 1 and "s" or "")
    elseif diff < 5184000 then
        return "1 month ago"
    else
        local months = math.floor(diff / 2592000)
        return string.format("%d month%s ago", months, months > 1 and "s" or "")
    end
end

--- Lua pattern matching the default timestamp format YYYY-MM-DD_HH-MM-SS.
--- All filename parsing depends on this pattern. This is derived from timestamp_fmt
--- during setup() to keep them in sync.
---@type string
M.TIMESTAMP_PATTERN = "%d%d%d%d%-%d%d%-%d%d_%d%d%-%d%d%-%d%d"

---Update the timestamp pattern based on the configured format.
---Called during setup to keep pattern in sync with timestamp_fmt.
---@param fmt string strftime format string
function M.update_timestamp_pattern(fmt)
    M.TIMESTAMP_PATTERN = timestamp_fmt_to_pattern(fmt)
end

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

    return M.now_stamp(fmt)
end

---Build a sorted filename from components.
---@param label string? Descriptive label (nil or empty for timestamp-only)
---@param timestamp string Timestamp string
---@param ext string File extension (e.g., ".md")
---@param marker string Trailing marker (e.g., "--note")
---@return string filename
function M.build_sorted_filename(label, timestamp, ext, marker)
    if label and label ~= "" then
        return label .. "-" .. timestamp .. marker .. ext
    else
        return timestamp .. marker .. ext
    end
end

---Extract a label and timestamp from a filename.
---@param filename string Filename or full path
---@return string? label Label portion, or nil if timestamp-only
---@return string? timestamp Timestamp portion, or nil if no timestamp found
function M.extract_label_and_remainder(filename)
    local basename = vim.fn.fnamemodify(filename, ":t:r")

    local label, timestamp = basename:match("^(.-)%-(" .. M.TIMESTAMP_PATTERN .. ")")
    if label and timestamp then
        return label, timestamp
    end

    timestamp = basename:match("^(" .. M.TIMESTAMP_PATTERN .. ")")
    if timestamp then
        return nil, timestamp
    end

    return basename, nil
end

---Build a filename for sort, replacing any existing label.
---When a new label is provided, it replaces the original label entirely
---(no chaining). When no new label is given, the original label is preserved.
---@param new_label string? New label to apply (nil/empty to keep original)
---@param original_filename string Original filename for label extraction
---@param timestamp string Timestamp to use
---@param ext string File extension
---@param marker string Trailing marker
---@return string filename
function M.build_filename_for_sort(new_label, original_filename, timestamp, ext, marker)
    local original_label, _ = M.extract_label_and_remainder(original_filename)

    local label
    if new_label and new_label ~= "" then
        label = new_label
    else
        label = original_label
    end

    return M.build_sorted_filename(label, timestamp, ext, marker)
end

---Generate a unique filename in a directory, appending --2, --3, etc. on collision.
---@param dir string Directory to check for collisions
---@param filename string Desired filename
---@param max_attempts integer? Maximum collision attempts (default 1000)
---@return string? filename Unique filename, or nil if limit exceeded
---@return string? error Error message on failure
function M.ensure_unique(dir, filename, max_attempts)
    max_attempts = max_attempts or 1000
    local path = fs.path_join(dir, filename)

    if not fs.file_exists(path) then
        return filename, nil
    end

    local ext = filename:match("(%.[^%.]+)$") or ".md"
    local base = filename:gsub("%.[^%.]+$", "")
    local counter = 2

    while counter <= max_attempts do
        local new_filename = string.format("%s--%d%s", base, counter, ext)
        local new_path = fs.path_join(dir, new_filename)

        if not fs.file_exists(new_path) then
            return new_filename, nil
        end

        counter = counter + 1
    end

    return nil, "Could not generate unique filename after " .. max_attempts .. " attempts"
end

return M
