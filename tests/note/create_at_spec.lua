--- Tests for cubby.note.create_at — Direct note creation with parameters
local create_at = require("cubby.note.create_at")
local fs = require("cubby.core.fs")
local config = require("cubby.config")

describe("create_at.create_with_params", function()
    local tmpdir

    before_each(function()
        tmpdir = vim.fn.tempname() .. "_create_at_test"
        vim.fn.mkdir(tmpdir, "p")
        vim.fn.mkdir(tmpdir .. "/projects", "p")
        config.setup({
            inbox_dir = tmpdir .. "/inbox",
            base_dir = tmpdir,
            file_ext = ".md",
            timestamp_fmt = "%Y-%m-%d_%H-%M-%S",
            open_after_create = false,
            auto_save_new_note = true,
            notify = false,
            trailing_marker = "--note",
            exclude_dirs = {},
            enable_recent_dirs = false,
            recent_state_file = tmpdir .. "/mru.json",
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

    it("creates a file with label in the specified directory", function()
        local path = create_at.create_with_params(tmpdir .. "/projects", "miata-boost")
        assert.is_not_nil(path)
        assert.is_true(fs.file_exists(path))

        local fname = vim.fn.fnamemodify(path, ":t")
        assert.truthy(fname:match("^miata%-boost%-"), "filename should start with label")
        assert.truthy(fname:match("%-%-note%.md$"), "filename should end with --note.md")
    end)

    it("creates a file without label (nil)", function()
        local path = create_at.create_with_params(tmpdir .. "/projects", nil)
        assert.is_not_nil(path)
        assert.is_true(fs.file_exists(path))

        local fname = vim.fn.fnamemodify(path, ":t")
        -- Should be timestamp-only: YYYY-MM-DD_HH-MM-SS--note.md
        assert.truthy(
            fname:match("^%d%d%d%d%-%d%d%-%d%d_%d%d%-%d%d%-%d%d%-%-note%.md"),
            "should be timestamp-only filename, got: " .. fname
        )
    end)

    it("creates a file without label (empty string)", function()
        local path = create_at.create_with_params(tmpdir .. "/projects", "")
        assert.is_not_nil(path)

        local fname = vim.fn.fnamemodify(path, ":t")
        assert.truthy(
            fname:match("^%d%d%d%d%-%d%d%-%d%d_%d%d%-%d%d%-%d%d%-%-note%.md"),
            "should be timestamp-only filename"
        )
    end)

    it("creates file in the correct directory", function()
        local dest = tmpdir .. "/projects"
        local path = create_at.create_with_params(dest, "test")
        assert.truthy(path:match("^" .. vim.pesc(dest)), "file should be in target directory")
    end)

    it("handles collision when creating rapidly", function()
        local dest = tmpdir .. "/projects"
        local path1 = create_at.create_with_params(dest, "rapid")
        local path2 = create_at.create_with_params(dest, "rapid")
        assert.is_not_nil(path1)
        assert.is_not_nil(path2)
        assert.is_not.equals(path1, path2)
    end)
end)
