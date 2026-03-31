--- Tests for cubby.config — Configuration setup and access
local config = require("cubby.config")

describe("config.setup", function()
    after_each(function()
        -- Restore test config after each test
        local test_tmp = _G._cubby_test_tmp
        config.setup({
            inbox_dir = test_tmp .. "/inbox",
            base_dir = test_tmp .. "/notes",
            notify = false,
            auto_save_new_note = true,
            enable_recent_dirs = true,
            max_recent_dirs = 5,
            recent_state_file = test_tmp .. "/cubby-mru.json",
        })
    end)

    it("applies default values when no opts given", function()
        config.setup({})
        local cfg = config.get()
        assert.equals(".md", cfg.file_ext)
        assert.equals("%Y-%m-%d_%H-%M-%S", cfg.timestamp_fmt)
        assert.is_true(cfg.open_after_create)
        assert.equals("--note", cfg.trailing_marker)
        assert.is_true(cfg.enable_recent_dirs)
        assert.equals(5, cfg.max_recent_dirs)
    end)

    it("overrides specific fields", function()
        config.setup({
            file_ext = ".txt",
            trailing_marker = "--memo",
            max_recent_dirs = 10,
        })
        local cfg = config.get()
        assert.equals(".txt", cfg.file_ext)
        assert.equals("--memo", cfg.trailing_marker)
        assert.equals(10, cfg.max_recent_dirs)
    end)

    it("expands tilde in inbox_dir", function()
        config.setup({ inbox_dir = "~/notes/inbox" })
        local cfg = config.get()
        -- Should not start with ~
        assert.is_false(cfg.inbox_dir:sub(1, 1) == "~", "inbox_dir should be expanded")
    end)

    it("expands tilde in base_dir", function()
        config.setup({ base_dir = "~/notes" })
        local cfg = config.get()
        assert.is_false(cfg.base_dir:sub(1, 1) == "~", "base_dir should be expanded")
    end)

    it("preserves exclude_dirs list", function()
        config.setup({ exclude_dirs = { ".git", ".obsidian", "node_modules" } })
        local cfg = config.get()
        assert.equals(3, #cfg.exclude_dirs)
        assert.equals(".git", cfg.exclude_dirs[1])
        assert.equals("node_modules", cfg.exclude_dirs[3])
    end)

    it("deep extends keeping defaults for unset fields", function()
        config.setup({ notify = false })
        local cfg = config.get()
        assert.is_false(cfg.notify)
        -- Other defaults should still be present
        assert.equals(".md", cfg.file_ext)
        assert.equals("--note", cfg.trailing_marker)
    end)

    it("warns on invalid timestamp format", function()
        local warned = false
        local original_notify = vim.notify
        vim.notify = function(msg, level)
            if level == vim.log.levels.WARN and msg:match("timestamp_fmt") then
                warned = true
            end
        end

        config.setup({ timestamp_fmt = "%Y/%m/%d" })

        vim.notify = original_notify
        assert.is_true(warned, "should warn about invalid timestamp format")
    end)

    it("does not warn on valid timestamp format", function()
        local warned = false
        local original_notify = vim.notify
        vim.notify = function(msg, level)
            if level == vim.log.levels.WARN and msg:match("timestamp_fmt") then
                warned = true
            end
        end

        config.setup({ timestamp_fmt = "%Y-%m-%d_%H-%M-%S" })

        vim.notify = original_notify
        assert.is_false(warned, "should not warn about valid timestamp format")
    end)
end)

describe("config.get", function()
    it("returns a table", function()
        local cfg = config.get()
        assert.is_table(cfg)
    end)

    it("returns the configured inbox_dir", function()
        local cfg = config.get()
        assert.is_string(cfg.inbox_dir)
        assert.is_true(#cfg.inbox_dir > 0)
    end)

    it("returns the configured base_dir", function()
        local cfg = config.get()
        assert.is_string(cfg.base_dir)
        assert.is_true(#cfg.base_dir > 0)
    end)

    it("returns a copy that does not affect internal state", function()
        local cfg1 = config.get()
        local original_notify = cfg1.notify
        cfg1.notify = not original_notify -- mutate the copy
        local cfg2 = config.get()
        -- cfg2 should be unchanged
        assert.equals(original_notify, cfg2.notify)
    end)

    it("has defaults even before explicit setup", function()
        -- config was set up in minimal_init.lua, but defaults should
        -- always be present for any field not overridden
        local cfg = config.get()
        assert.is_string(cfg.file_ext)
        assert.is_string(cfg.trailing_marker)
        assert.is_string(cfg.timestamp_fmt)
    end)
end)
