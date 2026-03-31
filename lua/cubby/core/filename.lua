---@class cubby.filename
local M = {}

local fs = require("cubby.core.fs")
local ts_mod = require("cubby.core.timestamp")

local TS_PAT = ts_mod.TIMESTAMP_PATTERN

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

    local label, timestamp = basename:match("^(.-)%-(" .. TS_PAT .. ")")
    if label and timestamp then
        return label, timestamp
    end

    timestamp = basename:match("^(" .. TS_PAT .. ")")
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
