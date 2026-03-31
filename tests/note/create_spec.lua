--- Tests for cubby.note.create — Blank note creation in inbox
local create = require("cubby.note.create")
local fs = require("cubby.core.fs")
local config = require("cubby.config")

describe("create.create_blank_note", function()
    local tmpdir

    before_each(function()
        tmpdir = vim.fn.tempname() .. "_create_test"
        vim.fn.mkdir(tmpdir, "p")
        config.setup({
            inbox_dir = tmpdir,
            base_dir = tmpdir,
            file_ext = ".md",
            timestamp_fmt = "%Y-%m-%d_%H-%M-%S",
            open_after_create = false, -- Don't open buffers in tests
            auto_save_new_note = true,
            notify = false,
            trailing_marker = "--note",
            exclude_dirs = {},
            enable_recent_dirs = false,
        })
    end)

    after_each(function()
        vim.fn.delete(tmpdir, "rf")
        -- Restore test config
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

    it("returns a file path", function()
        local path = create.create_blank_note(tmpdir)
        assert.is_not_nil(path)
        assert.is_string(path)
    end)

    it("creates a file on disk", function()
        local path = create.create_blank_note(tmpdir)
        assert.is_true(fs.file_exists(path))
    end)

    it("creates file with correct naming pattern", function()
        local path = create.create_blank_note(tmpdir)
        local fname = vim.fn.fnamemodify(path, ":t")
        -- Should match: YYYY-MM-DD_HH-MM-SS--note.md
        assert.truthy(
            fname:match("^%d%d%d%d%-%d%d%-%d%d_%d%d%-%d%d%-%d%d%-%-note%.md$"),
            "filename should match timestamp--note.md pattern, got: " .. fname
        )
    end)

    it("creates file inside the specified directory", function()
        local path = create.create_blank_note(tmpdir)
        assert.truthy(path:match("^" .. vim.pesc(tmpdir)))
    end)

    it("creates inbox directory if it does not exist", function()
        local new_inbox = tmpdir .. "/new_inbox"
        local path = create.create_blank_note(new_inbox)
        assert.is_not_nil(path)
        assert.is_true(fs.dir_exists(new_inbox))
    end)

    it("handles filename collisions", function()
        -- Create two notes in rapid succession
        local path1 = create.create_blank_note(tmpdir)
        local path2 = create.create_blank_note(tmpdir)
        assert.is_not_nil(path1)
        assert.is_not_nil(path2)
        assert.is_not.equals(path1, path2)
        assert.is_true(fs.file_exists(path1))
        assert.is_true(fs.file_exists(path2))
    end)
end)

describe("create.create_blank_note with auto_save_new_note = false", function()
    local tmpdir

    before_each(function()
        tmpdir = vim.fn.tempname() .. "_nosave_test"
        vim.fn.mkdir(tmpdir, "p")
        config.setup({
            inbox_dir = tmpdir,
            base_dir = tmpdir,
            file_ext = ".md",
            timestamp_fmt = "%Y-%m-%d_%H-%M-%S",
            open_after_create = false,
            auto_save_new_note = false,
            notify = false,
            trailing_marker = "--note",
            exclude_dirs = {},
            enable_recent_dirs = false,
        })
    end)

    after_each(function()
        vim.fn.delete(tmpdir, "rf")
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

    it("returns a path but does not write to disk", function()
        local path = create.create_blank_note(tmpdir)
        assert.is_not_nil(path)
        assert.is_false(fs.file_exists(path))
    end)
end)
