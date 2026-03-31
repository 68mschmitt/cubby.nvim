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

return M
