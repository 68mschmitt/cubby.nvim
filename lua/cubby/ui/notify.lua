---@class cubby.notify
local M = {}

---Show an informational notification. Respects the `notify` config option.
---@param msg string
function M.info(msg)
    local cfg = require("cubby.config").get()
    if not cfg.notify then
        return
    end
    vim.notify(msg, vim.log.levels.INFO)
end

---Show a warning notification. Always displayed regardless of config.
---@param msg string
function M.warn(msg)
    vim.notify(msg, vim.log.levels.WARN)
end

---Show an error notification. Always displayed regardless of config.
---@param msg string
function M.error(msg)
    vim.notify(msg, vim.log.levels.ERROR)
end

return M
