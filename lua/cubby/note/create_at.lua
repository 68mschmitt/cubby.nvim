---@class cubby.note.create_at
local M = {}

---Create a note with the given parameters in the specified directory.
---@param dest_dir string Destination directory
---@param label string? Optional descriptive label
---@return string? path Full path to the created note, or nil on failure
function M.create_with_params(dest_dir, label)
    local time = require("cubby.core.time")
    local filename = require("cubby.core.filename")
    local fs = require("cubby.core.fs")
    local notify = require("cubby.ui.notify")
    local config = require("cubby.config")
    local recent = require("cubby.core.recent")

    local cfg = config.get()
    local timestamp = time.now_stamp(cfg.timestamp_fmt)
    local new_filename = filename.build_sorted_filename(label, timestamp, cfg.file_ext, cfg.trailing_marker)
    local unique_filename, unique_err = filename.ensure_unique(dest_dir, new_filename)

    if not unique_filename then
        notify.warn("Failed to create note: " .. tostring(unique_err))
        return nil
    end

    local full_path = fs.path_join(dest_dir, unique_filename)

    if cfg.auto_save_new_note then
        fs.ensure_dir(dest_dir)
        local success = fs.write_file(full_path, "")

        if not success then
            notify.warn("Failed to create note: " .. full_path)
            return nil
        end
    end

    if cfg.open_after_create then
        vim.cmd.edit(full_path)
        if not cfg.auto_save_new_note then
            vim.bo.filetype = "markdown"
        end
    end

    local relative = full_path:gsub("^" .. vim.pesc(cfg.base_dir) .. "/", "")
    notify.info("Created → " .. relative)

    recent.add_recent_entry(dest_dir)

    return full_path
end

---Run the full create-at workflow with directory picker and label prompt.
function M.do_full_workflow()
    local config = require("cubby.config")
    local directory_picker = require("cubby.ui.directory_picker")
    local input = require("cubby.ui.input")

    local cfg = config.get()

    directory_picker.show_directory_picker(cfg.base_dir, cfg.base_dir, cfg.exclude_dirs, function(dest_dir)
        input.prompt_for_label(function(label)
            M.create_with_params(dest_dir, label)
        end)
    end)
end

---Entry point for creating a note at a chosen location.
---Shows recent picker if enabled, otherwise goes straight to directory picker.
function M.create_note_at()
    local config = require("cubby.config")
    local cfg = config.get()

    if not cfg.enable_recent_dirs then
        M.do_full_workflow()
        return
    end

    local recent_picker = require("cubby.ui.recent_picker")

    recent_picker.show_recent_picker(function(selection)
        if selection.use_recent then
            local input = require("cubby.ui.input")
            input.prompt_for_label(function(label)
                M.create_with_params(selection.dir, label)
            end)
        else
            M.do_full_workflow()
        end
    end)
end

return M
