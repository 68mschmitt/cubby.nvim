-- Minimal init for running tests.
-- Usage:
--   make test
--   nvim --headless --noplugin -u tests/minimal_init.lua \
--     -c "luafile tests/runner.lua"

-- Set up runtime path
local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":h:h")
vim.opt.rtp:prepend(root)

-- Minimal settings
vim.o.swapfile = false
vim.o.backup = false
vim.o.writebackup = false

-- Temp directory for test artifacts (each run gets a fresh one)
local test_tmp = vim.fn.tempname() .. "_cubby_test"
vim.fn.mkdir(test_tmp, "p")
vim.fn.mkdir(test_tmp .. "/inbox", "p")
vim.fn.mkdir(test_tmp .. "/notes", "p")
_G._cubby_test_tmp = test_tmp

-- Load the plugin with test-safe config pointing at temp dirs
require("cubby").setup({
    inbox_dir = test_tmp .. "/inbox",
    base_dir = test_tmp .. "/notes",
    notify = false,
    auto_save_new_note = true,
    enable_recent_dirs = true,
    max_recent_dirs = 5,
    recent_state_file = test_tmp .. "/cubby-mru.json",
})
