---@class cubby.directory
local M = {}

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

return M
