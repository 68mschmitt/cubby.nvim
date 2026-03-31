local M = {}

local config = require("katasync.config")
local timestamp = require("katasync.core.timestamp")
local filename = require("katasync.core.filename")
local move = require("katasync.core.move")
local notify = require("katasync.ui.notify")
local directory_picker = require("katasync.ui.directory_picker")
local input = require("katasync.ui.input")
local recent_picker = require("katasync.ui.recent_picker")
local recent = require("katasync.core.recent")

function M.validate_current_buffer()
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

function M.execute_sort(current_path, dest_dir, label)
    local cfg = config.get()

    local extracted_timestamp = timestamp.preserve_or_fallback_timestamp(
        current_path,
        current_path,
        cfg.timestamp_fmt
    )

    local new_filename = filename.build_sorted_filename_preserving_original(
        label,
        current_path,
        extracted_timestamp,
        cfg.file_ext,
        cfg.trailing_marker
    )

    local unique_filename = filename.ensure_unique(dest_dir, new_filename)
    local dest_path = dest_dir .. "/" .. unique_filename

    -- Capture the original buffer number before moving the file
    local original_bufnr = vim.api.nvim_get_current_buf()

    if vim.bo.modified then
        vim.cmd("write")
    end

    local success, err = move.move_file(current_path, dest_path)

    if not success then
        notify.warn("Failed to move file: " .. tostring(err))
        return false
    end

    vim.cmd.edit(dest_path)

    -- Flush any debounce timers that plugins (e.g. markview) may have started
    -- from cursor/text events on the OLD buffer before this function ran.
    -- Firing CursorMoved on the new buffer forces those timers to stop and
    -- re-evaluate against the current (valid) buffer, preventing stale buffer
    -- IDs from surviving in timer closures.
    vim.api.nvim_exec_autocmds("CursorMoved", { buffer = 0 })

    -- Now safe to delete the old buffer — no stale timers reference it
    if vim.api.nvim_buf_is_valid(original_bufnr) then
        pcall(vim.api.nvim_buf_delete, original_bufnr, { force = true })
    end

    return true, dest_path
end

function M.handle_sort_completion(old_path, new_path, dest_dir)
    local cfg = config.get()

    if cfg.notify then
        local base_dir = cfg.base_dir
        local relative = new_path:gsub("^" .. vim.pesc(base_dir) .. "/", "")
        notify.info("Sorted → " .. relative)
    end

    recent.add_recent_entry(dest_dir)
end

function M.do_full_workflow(current_file)
    local cfg = config.get()

    directory_picker.show_directory_picker(
        cfg.base_dir,
        cfg.base_dir,
        cfg.exclude_dirs,
        function(dest_dir)
            input.prompt_for_label(function(label)
                local success, new_path = M.execute_sort(
                    current_file,
                    dest_dir,
                    label
                )

                if success then
                    M.handle_sort_completion(current_file, new_path, dest_dir)
                end
            end)
        end
    )
end

function M.sort_current_note()
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

    recent_picker.show_recent_picker(function(selection)
        if selection.use_recent then
            input.prompt_for_label(function(label)
                local success, new_path = M.execute_sort(
                    current_file,
                    selection.dir,
                    label
                )

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
