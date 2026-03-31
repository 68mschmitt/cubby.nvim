local M = {}

function M.prompt_for_label(callback)
    local label_module = require("katasync.core.label")
    local notify = require("katasync.ui.notify")

    vim.ui.input({ prompt = "Enter a descriptive name (optional, press Enter to skip): " }, function(input)
        if not input then
            return
        end

        if input == "" then
            callback(nil)
            return
        end

        local sanitized = label_module.sanitize_label(input)

        if not label_module.validate_label(sanitized) then
            notify.warn("Label invalid after sanitization. Try again or press Enter to skip.")
            M.prompt_for_label(callback)
            return
        end

        callback(sanitized)
    end)
end

function M.prompt_for_directory_name(callback)
    vim.ui.input({ prompt = "New directory name: " }, function(name)
        callback(name)
    end)
end

function M.confirm_cross_filesystem_move(callback)
    vim.ui.select({ "Yes", "No" }, {
        prompt = "This is a cross-filesystem move. Continue?",
    }, function(choice)
        if choice == "Yes" then
            callback(true)
        else
            callback(false)
        end
    end)
end

return M
