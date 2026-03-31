--- Tests for cubby.note.sort — Note sorting and validation
local sort = require("cubby.note.sort")
local fs = require("cubby.core.fs")
local config = require("cubby.config")

describe("sort.validate_current_buffer", function()
    it("returns false for empty buffer", function()
        -- Switch to a fresh empty buffer
        vim.cmd("enew!")
        local valid, msg = sort.validate_current_buffer()
        assert.is_false(valid)
        assert.equals("Current buffer has no file", msg)
    end)

    it("returns true for a valid file buffer", function()
        local tmpfile = vim.fn.tempname() .. ".md"
        fs.write_file(tmpfile, "test content")
        vim.cmd.edit(tmpfile)

        local valid, filepath = sort.validate_current_buffer()
        assert.is_true(valid)
        -- Use resolve() to handle macOS /var -> /private/var symlinks
        assert.equals(vim.fn.resolve(tmpfile), vim.fn.resolve(filepath))

        vim.cmd("bdelete!")
        vim.fn.delete(tmpfile)
    end)

    it("returns false for non-markdown when allow_non_md is false", function()
        local test_tmp = _G._cubby_test_tmp
        config.setup({
            inbox_dir = test_tmp .. "/inbox",
            base_dir = test_tmp .. "/notes",
            notify = false,
            allow_non_md = false,
            enable_recent_dirs = false,
        })

        local tmpfile = vim.fn.tempname() .. ".txt"
        fs.write_file(tmpfile, "test content")
        vim.cmd.edit(tmpfile)

        local valid, msg = sort.validate_current_buffer()
        assert.is_false(valid)
        assert.equals("Current file is not a markdown file", msg)

        vim.cmd("bdelete!")
        vim.fn.delete(tmpfile)

        -- Restore config
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

    it("returns true for non-markdown when allow_non_md is true", function()
        local tmpfile = vim.fn.tempname() .. ".txt"
        fs.write_file(tmpfile, "test content")
        vim.cmd.edit(tmpfile)

        local valid, filepath = sort.validate_current_buffer()
        assert.is_true(valid)
        -- Use resolve() to handle macOS /var -> /private/var symlinks
        assert.equals(vim.fn.resolve(tmpfile), vim.fn.resolve(filepath))

        vim.cmd("bdelete!")
        vim.fn.delete(tmpfile)
    end)

    it("returns false when file does not exist on disk", function()
        local tmpfile = vim.fn.tempname() .. ".md"
        -- Create buffer pointing to non-existent file
        vim.cmd.edit(tmpfile)

        local valid, msg = sort.validate_current_buffer()
        assert.is_false(valid)
        assert.equals("Current file does not exist on disk", msg)

        vim.cmd("bdelete!")
    end)
end)

describe("sort.execute_sort", function()
    local tmpdir

    before_each(function()
        tmpdir = vim.fn.tempname() .. "_sort_exec_test"
        vim.fn.mkdir(tmpdir, "p")
        vim.fn.mkdir(tmpdir .. "/inbox", "p")
        vim.fn.mkdir(tmpdir .. "/dest", "p")
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
            allow_non_md = true,
            enable_recent_dirs = false,
        })
    end)

    after_each(function()
        -- Clean up any open buffers
        pcall(function()
            vim.cmd("bdelete!")
        end)
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

    it("moves file to destination with label", function()
        local source = tmpdir .. "/inbox/2025-10-08_09-17-33--note.md"
        fs.write_file(source, "test content")
        vim.cmd.edit(source)

        local original_notify = vim.notify
        vim.notify = function() end

        local success, new_path = sort.execute_sort(source, tmpdir .. "/dest", "project")

        vim.notify = original_notify

        assert.is_true(success)
        assert.is_not_nil(new_path)
        assert.is_false(fs.file_exists(source))
        assert.is_true(fs.file_exists(new_path))
        -- Should preserve timestamp and use new label
        assert.truthy(new_path:match("project%-2025%-10%-08_09%-17%-33"))
    end)

    it("moves file to destination without label", function()
        local source = tmpdir .. "/inbox/2025-10-08_09-17-33--note.md"
        fs.write_file(source, "content")
        vim.cmd.edit(source)

        local original_notify = vim.notify
        vim.notify = function() end

        local success, new_path = sort.execute_sort(source, tmpdir .. "/dest", nil)

        vim.notify = original_notify

        assert.is_true(success)
        assert.is_not_nil(new_path)
        -- Should be timestamp-only filename
        assert.truthy(new_path:match("2025%-10%-08_09%-17%-33%-%-note%.md"))
    end)

    it("preserves original timestamp during sort", function()
        local source = tmpdir .. "/inbox/2025-06-15_12-30-00--note.md"
        fs.write_file(source, "preserve me")
        vim.cmd.edit(source)

        local original_notify = vim.notify
        vim.notify = function() end

        local success, new_path = sort.execute_sort(source, tmpdir .. "/dest", "labeled")

        vim.notify = original_notify

        assert.is_true(success)
        -- Original timestamp should be in the new filename
        assert.truthy(new_path:match("2025%-06%-15_12%-30%-00"))
    end)
end)
