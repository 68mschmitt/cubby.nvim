local M = {}

function M.is_cross_filesystem(source, dest)
    local source_stat = vim.loop.fs_stat(source)
    local dest_dir = vim.fn.fnamemodify(dest, ":h")
    local dest_stat = vim.loop.fs_stat(dest_dir)

    if not source_stat or not dest_stat then
        return false
    end

    return source_stat.dev ~= dest_stat.dev
end

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

function M.atomic_move_or_copy_delete(source, dest)
    local ok, err = M.check_move_permissions(source, dest)
    if not ok then
        return false, err
    end

    local success, rename_err = pcall(vim.loop.fs_rename, source, dest)

    if success then
        return true, nil
    end

    if M.is_cross_filesystem(source, dest) then
        local copy_success, copy_err = pcall(vim.loop.fs_copyfile, source, dest)
        if not copy_success then
            return false, "Failed to copy file: " .. tostring(copy_err)
        end

        local unlink_success, unlink_err = pcall(vim.loop.fs_unlink, source)
        if not unlink_success then
            pcall(vim.loop.fs_unlink, dest)
            return false, "Failed to remove source file after copy: " .. tostring(unlink_err)
        end

        return true, nil
    end

    return false, "Failed to move file: " .. tostring(rename_err)
end

function M.move_file(source, destination)
    local dest_dir = vim.fn.fnamemodify(destination, ":h")

    if vim.fn.isdirectory(dest_dir) == 0 then
        vim.fn.mkdir(dest_dir, "p")
    end

    return M.atomic_move_or_copy_delete(source, destination)
end

return M

