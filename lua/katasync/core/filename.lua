local M = {}

local fs = require("katasync.core.fs")
local ts_mod = require("katasync.core.timestamp")

local TS_PAT = ts_mod.TIMESTAMP_PATTERN

function M.build_sorted_filename(label, timestamp, ext, marker)
    if label and label ~= "" then
        return label .. "-" .. timestamp .. marker .. ext
    else
        return timestamp .. marker .. ext
    end
end

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

function M.build_sorted_filename_preserving_original(new_label, original_filename, timestamp, ext, marker)
    local original_label, _ = M.extract_label_and_remainder(original_filename)

    local combined_label
    if new_label and new_label ~= "" then
        if original_label and original_label ~= "" then
            combined_label = new_label .. "-" .. original_label
        else
            combined_label = new_label
        end
    else
        combined_label = original_label
    end

    return M.build_sorted_filename(combined_label, timestamp, ext, marker)
end

function M.ensure_unique(dir, filename)
    local path = dir .. "/" .. filename

    if not fs.file_exists(path) then
        return filename
    end

    local ext = filename:match("(%.[^%.]+)$") or ".md"
    local base = filename:gsub("%.[^%.]+$", "")
    local counter = 2
    local max_attempts = 1000

    while counter <= max_attempts do
        local new_filename = string.format("%s--%d%s", base, counter, ext)
        local new_path = dir .. "/" .. new_filename

        if not fs.file_exists(new_path) then
            return new_filename
        end

        counter = counter + 1
    end

    error("Could not generate unique filename after " .. max_attempts .. " attempts")
end

return M
