---@class cubby.note.create
local M = {}

---Create a blank note in the specified inbox directory.
---@param inbox_dir string Directory to create the note in
---@return string? path Full path to the created note, or nil on failure
function M.create_blank_note(inbox_dir)
    local fs = require("cubby.core.fs")
    local time = require("cubby.core.time")
    local filename = require("cubby.core.filename")
    local notify = require("cubby.ui.notify")
    local config = require("cubby.config")

    local cfg = config.get()

    fs.ensure_dir(inbox_dir)

    local timestamp = time.now_stamp(cfg.timestamp_fmt)
    local base_filename = timestamp .. cfg.trailing_marker .. cfg.file_ext
    local unique_filename, unique_err = filename.ensure_unique(inbox_dir, base_filename)

    if not unique_filename then
        notify.warn("Failed to create note: " .. tostring(unique_err))
        return nil
    end

    local full_path = fs.path_join(inbox_dir, unique_filename)

    if cfg.auto_save_new_note then
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

    notify.info("Created note: " .. full_path)

    return full_path
end

return M
