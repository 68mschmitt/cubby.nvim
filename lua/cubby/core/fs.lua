---@class cubby.fs
local M = {}

---Ensure a directory exists, creating it and any parents if needed.
---@param path string Directory path to ensure exists
function M.ensure_dir(path)
    if vim.fn.isdirectory(path) == 0 then
        vim.fn.mkdir(path, "p")
    end
end

---Check if a file exists and is readable.
---@param path string File path to check
---@return boolean
function M.file_exists(path)
    return vim.fn.filereadable(path) == 1
end

---Check if a directory exists.
---@param path string Directory path to check
---@return boolean
function M.dir_exists(path)
    return vim.fn.isdirectory(path) == 1
end

---Write content to a file, creating or overwriting it.
---@param path string File path to write to
---@param content string Content to write
---@return boolean success
function M.write_file(path, content)
    local file = io.open(path, "w")
    if file then
        file:write(content)
        file:close()
        return true
    end
    return false
end

---Join path segments, normalizing slashes between them.
---@param ... string Path segments to join
---@return string
function M.path_join(...)
    local parts = { ... }
    if #parts == 0 then
        return ""
    end
    local result = parts[1]:gsub("/+$", "")
    for i = 2, #parts do
        local segment = parts[i]:gsub("^/+", ""):gsub("/+$", "")
        result = result .. "/" .. segment
    end
    return result
end

---Read the first non-empty line from a file.
---A line is non-empty if it contains at least one non-whitespace character.
---Stops reading at the first match — does not read the entire file.
---@param filepath string Path to the file
---@return string|nil line Trimmed first non-empty line, or nil
---@return string|nil err Error message if file cannot be opened
function M.read_first_nonempty_line(filepath)
    local f, err = io.open(filepath, "r")
    if not f then
        return nil, err
    end
    for line in f:lines() do
        local trimmed = line:match("^%s*(.-)%s*$")
        if trimmed ~= "" then
            f:close()
            return trimmed, nil
        end
    end
    f:close()
    return nil, nil
end

return M
