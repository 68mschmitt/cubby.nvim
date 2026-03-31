---@class cubby.note.sort
local M = {}

---Validate that the current buffer is a sortable note.
---@return boolean valid
---@return string file_or_error File path on success, error message on failure
function M.validate_current_buffer()
    local config = require("cubby.config")
    local current_file = vim.api.nvim_buf_get_name(0)

    if current_file == "" then
        return false, "Current buffer has no file"
    end

    local cfg = config.get()
    if not cfg.allow_non_md and not current_file:match("%.md$") then
        return false, "Current file is not a markdown file"
    end

    if vim.fn.filereadable(current_file) == 0 then
        return false, "Current file does not exist on disk"
    end

    return true, current_file
end

---Execute the file move and buffer switch for a sort operation.
---@param current_path string Current file path
---@param dest_dir string Destination directory
---@param label string? Optional new label (replaces existing label)
---@return boolean success
---@return string? new_path Destination path on success, or nil
function M.execute_sort(current_path, dest_dir, label)
    local config = require("cubby.config")
    local timestamp = require("cubby.core.timestamp")
    local filename = require("cubby.core.filename")
    local fs = require("cubby.core.fs")
    local move = require("cubby.core.move")
    local notify = require("cubby.ui.notify")

    local cfg = config.get()

    local extracted_timestamp = timestamp.preserve_or_fallback_timestamp(current_path, current_path, cfg.timestamp_fmt)

    local new_filename =
        filename.build_filename_for_sort(label, current_path, extracted_timestamp, cfg.file_ext, cfg.trailing_marker)

    local unique_filename, unique_err = filename.ensure_unique(dest_dir, new_filename)

    if not unique_filename then
        notify.warn("Failed to sort note: " .. tostring(unique_err))
        return false, nil
    end

    local dest_path = fs.path_join(dest_dir, unique_filename)

    local original_bufnr = vim.api.nvim_get_current_buf()

    if vim.bo.modified then
        vim.cmd("write")
    end

    local success, err = move.move_file(current_path, dest_path)

    if not success then
        notify.warn("Failed to move file: " .. tostring(err))
        return false, nil
    end

    vim.cmd.edit(dest_path)

    -- WORKAROUND: Some plugins (e.g., markview.nvim) start debounce timers on
    -- cursor/text autocmd events from the OLD buffer before the sort runs.
    -- Firing CursorMoved on the new buffer flushes those stale timers so the
    -- new buffer renders correctly. Remove this if the upstream plugin fixes
    -- its debounce handling, or if it causes problems with other plugins.
    -- See: https://github.com/OXY2DEV/markview.nvim
    vim.api.nvim_exec_autocmds("CursorMoved", { buffer = 0 })

    if vim.api.nvim_buf_is_valid(original_bufnr) then
        pcall(vim.api.nvim_buf_delete, original_bufnr, { force = true })
    end

    return true, dest_path
end

---Handle post-sort notifications and MRU tracking.
---@param old_path string Original file path (unused, kept for context)
---@param new_path string New file path after sort
---@param dest_dir string Destination directory
function M.handle_sort_completion(old_path, new_path, dest_dir)
    local config = require("cubby.config")
    local notify = require("cubby.ui.notify")
    local recent = require("cubby.core.recent")

    local cfg = config.get()

    local relative = new_path:gsub("^" .. vim.pesc(cfg.base_dir) .. "/", "")
    notify.info("Sorted → " .. relative)

    recent.add_recent_entry(dest_dir)
end

---Run the full sort workflow with directory picker and label prompt.
---@param current_file string Path to the file being sorted
function M.do_full_workflow(current_file)
    local config = require("cubby.config")
    local directory_picker = require("cubby.ui.directory_picker")
    local input = require("cubby.ui.input")

    local cfg = config.get()

    directory_picker.show_directory_picker(cfg.base_dir, cfg.base_dir, cfg.exclude_dirs, function(dest_dir)
        input.prompt_for_label(function(label)
            local success, new_path = M.execute_sort(current_file, dest_dir, label)

            if success then
                M.handle_sort_completion(current_file, new_path, dest_dir)
            end
        end)
    end)
end

---Entry point for sorting the current note.
---Validates the buffer, then shows recent picker or directory picker.
function M.sort_current_note()
    local notify = require("cubby.ui.notify")
    local config = require("cubby.config")

    local valid, current_file = M.validate_current_buffer()

    if not valid then
        notify.warn(current_file)
        return
    end

    local cfg = config.get()

    if not cfg.enable_recent_dirs then
        M.do_full_workflow(current_file)
        return
    end

    local recent_picker = require("cubby.ui.recent_picker")

    recent_picker.show_recent_picker(function(selection)
        if selection.use_recent then
            local input = require("cubby.ui.input")
            input.prompt_for_label(function(label)
                local success, new_path = M.execute_sort(current_file, selection.dir, label)

                if success then
                    M.handle_sort_completion(current_file, new_path, selection.dir)
                end
            end)
        else
            M.do_full_workflow(current_file)
        end
    end)
end

return M
