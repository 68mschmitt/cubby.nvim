---@class cubby.ui.input
local M = {}

---Prompt the user for an optional descriptive label.
---Sanitizes input and re-prompts on invalid labels.
---@param callback fun(label: string?) Called with sanitized label, or nil if skipped
function M.prompt_for_label(callback)
    local label_module = require("cubby.core.label")
    local notify = require("cubby.ui.notify")

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

---Prompt the user for a new directory name.
---@param callback fun(name: string?) Called with the raw input
function M.prompt_for_directory_name(callback)
    vim.ui.input({ prompt = "New directory name: " }, function(name)
        callback(name)
    end)
end

return M
