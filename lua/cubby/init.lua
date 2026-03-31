local M = {}

function M.setup(opts)
    require("cubby.config").setup(opts)
    require("cubby.commands").register()
end

function M.new_note()
    local cfg = require("cubby.config").get()
    return require("cubby.note.create").create_blank_note(cfg.inbox_dir)
end

function M.sort_note()
    return require("cubby.note.sort").sort_current_note()
end

function M.create_note_at()
    return require("cubby.note.create_at").create_note_at()
end

function M.list_inbox(args)
    return require("cubby.note.list_inbox").list_inbox(args)
end

return M
