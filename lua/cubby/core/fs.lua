local M = {}

function M.ensure_dir(path)
    if vim.fn.isdirectory(path) == 0 then
        vim.fn.mkdir(path, "p")
    end
end

function M.file_exists(path)
    return vim.fn.filereadable(path) == 1
end

function M.dir_exists(path)
    return vim.fn.isdirectory(path) == 1
end

function M.write_file(path, content)
    local file = io.open(path, "w")
    if file then
        file:write(content)
        file:close()
        return true
    end
    return false
end

return M

