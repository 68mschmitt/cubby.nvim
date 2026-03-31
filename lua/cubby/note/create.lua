local M = {}

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
    local unique_filename = filename.ensure_unique(inbox_dir, base_filename)

    local full_path = inbox_dir .. "/" .. unique_filename

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

    if cfg.notify then
        notify.info("Created note: " .. full_path)
    end

    return full_path
end

return M
