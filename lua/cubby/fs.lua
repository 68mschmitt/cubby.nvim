---@class cubby.fs
local M = {}

---Ensure a directory exists, creating it and any parents if needed.
---@param path string Directory path to ensure exists
---@return boolean success
---@return string? error Error message on failure
function M.ensure_dir(path)
    if vim.fn.isdirectory(path) == 0 then
        local ok = vim.fn.mkdir(path, "p")
        if ok == 0 then
            return false, "Failed to create directory: " .. path
        end
    end
    return true, nil
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

---List subdirectories of a path, excluding specified names.
---@param path string Directory to scan
---@param exclude_dirs string[] Directory names to exclude
---@return string[] subdirs Sorted list of subdirectory names
function M.list_subdirs(path, exclude_dirs)
    local subdirs = {}

    if vim.fn.isdirectory(path) == 0 then
        return subdirs
    end

    local handle = vim.uv.fs_scandir(path)
    if not handle then
        return subdirs
    end

    while true do
        local name, type = vim.uv.fs_scandir_next(handle)
        if not name then
            break
        end

        if type == "directory" and not M.is_excluded_dir(name, exclude_dirs) then
            table.insert(subdirs, name)
        end
    end

    table.sort(subdirs)
    return subdirs
end

---Check if a directory name is in the exclusion list.
---@param name string Directory name to check
---@param exclude_list string[] List of excluded names
---@return boolean
function M.is_excluded_dir(name, exclude_list)
    for _, excluded in ipairs(exclude_list) do
        if name == excluded then
            return true
        end
    end
    return false
end

---Check whether source and destination are on different filesystems.
---@param source string Source file path
---@param dest string Destination file path
---@return boolean
function M.is_cross_filesystem(source, dest)
    local source_stat = vim.uv.fs_stat(source)
    local dest_dir = vim.fn.fnamemodify(dest, ":h")
    local dest_stat = vim.uv.fs_stat(dest_dir)

    if not source_stat or not dest_stat then
        return false
    end

    return source_stat.dev ~= dest_stat.dev
end

---Verify that the current user has write permission for a move operation.
---@param source string Source file path
---@param dest string Destination file path
---@return boolean ok
---@return string? error Error message on failure
function M.check_move_permissions(source, dest)
    local source_dir = vim.fn.fnamemodify(source, ":h")

    if vim.fn.filewritable(source) == 0 then
        return false, "No write permission on source file"
    end

    if vim.fn.filewritable(source_dir) == 0 then
        return false, "No write permission on source directory"
    end

    local dest_dir = vim.fn.fnamemodify(dest, ":h")
    if vim.fn.isdirectory(dest_dir) == 1 and vim.fn.filewritable(dest_dir) == 0 then
        return false, "No write permission on destination directory"
    end

    return true, nil
end

---Move a file atomically, falling back to copy+delete for cross-filesystem moves.
---@param source string Source file path
---@param dest string Destination file path
---@return boolean ok
---@return string? error Error message on failure
function M.atomic_move_or_copy_delete(source, dest)
    local ok, err = M.check_move_permissions(source, dest)
    if not ok then
        return false, err
    end

    local success, rename_err = pcall(vim.uv.fs_rename, source, dest)

    if success then
        return true, nil
    end

    if M.is_cross_filesystem(source, dest) then
        local copy_success, copy_err = pcall(vim.uv.fs_copyfile, source, dest)
        if not copy_success then
            return false, "Failed to copy file: " .. tostring(copy_err)
        end

        local unlink_success, unlink_err = pcall(vim.uv.fs_unlink, source)
        if not unlink_success then
            pcall(vim.uv.fs_unlink, dest)
            return false, "Failed to remove source file after copy: " .. tostring(unlink_err)
        end

        return true, nil
    end

    return false, "Failed to move file: " .. tostring(rename_err)
end

---Move a file to a destination, creating the destination directory if needed.
---@param source string Source file path
---@param destination string Destination file path
---@return boolean ok
---@return string? error Error message on failure
function M.move_file(source, destination)
    local dest_dir = vim.fn.fnamemodify(destination, ":h")

    local ok, err = M.ensure_dir(dest_dir)
    if not ok then
        return false, err
    end

    return M.atomic_move_or_copy_delete(source, destination)
end

return M
