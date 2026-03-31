---@class cubby.config_module
local M = {}

---@class cubby.Config
---@field inbox_dir string Directory for new inbox notes
---@field base_dir string Base directory for note organization
---@field file_ext string File extension for notes
---@field timestamp_fmt string strftime format for timestamps
---@field open_after_create boolean Open file buffer after creation
---@field auto_save_new_note boolean Write file to disk immediately on creation
---@field notify boolean Show informational notifications
---@field trailing_marker string Filename suffix marker
---@field exclude_dirs string[] Directory names to exclude from picker
---@field allow_non_md boolean Allow sorting non-markdown files
---@field enable_recent_dirs boolean Enable recent destinations feature
---@field max_recent_dirs integer Number of recent destinations to remember
---@field recent_state_file string Path to the MRU state file

---@type cubby.Config
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
    allow_non_md = true,
    enable_recent_dirs = true,
    max_recent_dirs = 5,
    recent_state_file = vim.fn.stdpath("state") .. "/cubby-mru.json",
}

---@type cubby.Config
local config = vim.deepcopy(default_config)

---Validate that the configured timestamp format produces parseable timestamps.
---@param cfg cubby.Config
local function validate_timestamp_format(cfg)
    local ts_mod = require("cubby.core.timestamp")
    local sample = os.date(cfg.timestamp_fmt)
    if not sample:match("^" .. ts_mod.TIMESTAMP_PATTERN .. "$") then
        vim.notify(
            string.format(
                "[cubby] timestamp_fmt %q produces %q which does not match the expected YYYY-MM-DD_HH-MM-SS pattern.\n"
                    .. "Filename parsing, relative times, and timestamp preservation will not work correctly.",
                cfg.timestamp_fmt,
                sample
            ),
            vim.log.levels.WARN
        )
    end
end

---Initialize cubby with user options, merged over defaults.
---@param opts cubby.Config? User configuration overrides
function M.setup(opts)
    config = vim.tbl_deep_extend("force", vim.deepcopy(default_config), opts or {})
    config.inbox_dir = vim.fn.expand(config.inbox_dir)
    config.base_dir = vim.fn.expand(config.base_dir)
    validate_timestamp_format(config)
end

---Get the current configuration. Returns a copy to prevent external mutation.
---@return cubby.Config
function M.get()
    return vim.deepcopy(config)
end

return M
