local M = {}

function M.check()
    vim.health.start("cubby.nvim")

    -- Check Neovim version
    if vim.fn.has("nvim-0.10") == 1 then
        vim.health.ok("Neovim >= 0.10")
    else
        vim.health.warn("Neovim >= 0.10 recommended (vim.uv support)")
    end

    -- Check configuration
    local ok, config = pcall(function()
        return require("cubby.config").get()
    end)

    if not ok then
        vim.health.error("Failed to load configuration: " .. tostring(config))
        return
    end

    vim.health.ok("Configuration loaded")

    -- Check inbox directory
    if vim.fn.isdirectory(config.inbox_dir) == 1 then
        vim.health.ok("Inbox directory exists: " .. config.inbox_dir)
    else
        vim.health.warn("Inbox directory does not exist: " .. config.inbox_dir, {
            "It will be created automatically when you run :NewNote",
            "Or create it manually: mkdir -p " .. config.inbox_dir,
        })
    end

    -- Check base directory
    if vim.fn.isdirectory(config.base_dir) == 1 then
        vim.health.ok("Base directory exists: " .. config.base_dir)
    else
        vim.health.error("Base directory does not exist: " .. config.base_dir, {
            "Create it: mkdir -p " .. config.base_dir,
        })
    end

    -- Check base directory is writable
    if vim.fn.isdirectory(config.base_dir) == 1 then
        if vim.fn.filewritable(config.base_dir) == 2 then
            vim.health.ok("Base directory is writable")
        else
            vim.health.error("Base directory is not writable: " .. config.base_dir)
        end
    end

    -- Check MRU state
    if config.enable_recent_dirs then
        local state_dir = vim.fn.fnamemodify(config.recent_state_file, ":h")
        if vim.fn.isdirectory(state_dir) == 1 then
            vim.health.ok("MRU state directory exists: " .. state_dir)
        else
            vim.health.info("MRU state directory will be created on first use: " .. state_dir)
        end
    else
        vim.health.info("Recent directories feature is disabled")
    end

    -- Validate timestamp format
    local ts_mod = require("cubby.core.timestamp")
    local sample = os.date(config.timestamp_fmt)
    if sample:match("^" .. ts_mod.TIMESTAMP_PATTERN .. "$") then
        vim.health.ok("Timestamp format is valid: " .. config.timestamp_fmt .. " → " .. sample)
    else
        vim.health.error(
            "Timestamp format produces unparseable output: " .. config.timestamp_fmt .. " → " .. sample,
            { "Filename parsing, relative times, and sort will not work correctly" }
        )
    end
end

return M
