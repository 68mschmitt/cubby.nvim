local M = {}

function M.list_subdirs(path, exclude_dirs)
    local subdirs = {}

    if vim.fn.isdirectory(path) == 0 then
        return subdirs
    end

    local handle = vim.loop.fs_scandir(path)
    if not handle then
        return subdirs
    end

    while true do
        local name, type = vim.loop.fs_scandir_next(handle)
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

function M.is_excluded_dir(name, exclude_list)
    for _, excluded in ipairs(exclude_list) do
        if name == excluded then
            return true
        end
    end
    return false
end

function M.ensure_path_exists(path)
    if vim.fn.isdirectory(path) == 0 then
        vim.fn.mkdir(path, "p")
    end
end

return M

