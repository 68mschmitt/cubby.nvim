---@class cubby
local M = {}

---Initialize cubby with user configuration.
---@param opts cubby.Config? Configuration overrides
function M.setup(opts)
    require("cubby.config").setup(opts)
    require("cubby.commands").register()
end

---Create a new blank note in the inbox.
---@return string? path Full path to the created note, or nil on failure
function M.new_note()
    local cfg = require("cubby.config").get()
    return require("cubby.note.create").create_blank_note(cfg.inbox_dir)
end

---Sort the current buffer's note into a chosen directory.
function M.sort_note()
    return require("cubby.note.sort").sort_current_note()
end

---Create a note directly in a chosen location with optional label.
function M.create_note_at()
    return require("cubby.note.create_at").create_note_at()
end

---Display inbox notes in a picker for review.
---@param args { sort: string? }? Optional arguments (sort: "newest"|"oldest")
function M.list_inbox(args)
    return require("cubby.note.list_inbox").list_inbox(args)
end

return M
