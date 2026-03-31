local M = {}

local default_config = {
    inbox_dir = "~/notes/inbox",
    base_dir = "~/notes",
    file_ext = ".md",
    timestamp_fmt = "%Y-%m-%d_%H-%M-%S",
    open_after_create = true,
    auto_save_new_note = false,
    notify = true,
    trailing_marker = "--note",
    exclude_dirs = { ".git", ".obsidian" },
    confirm_on_cross_fs = false,
    allow_non_md = true,
    enable_recent_dirs = true,
    max_recent_dirs = 5,
    recent_state_file = vim.fn.stdpath("state") .. "/cubby-mru.json",
}

local config = {}

function M.setup(opts)
    config = vim.tbl_deep_extend("force", default_config, opts or {})
    config.inbox_dir = vim.fn.expand(config.inbox_dir)
    config.base_dir = vim.fn.expand(config.base_dir)
end

function M.get()
    return config
end

return M
