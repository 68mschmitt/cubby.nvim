--- Tests for cubby.note — Note creation, sorting, and inbox management
local note = require("cubby.note")
local fs = require("cubby.fs")
local config = require("cubby.config")

describe("note.create_blank_note", function()
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
        })
    end)

    it("returns a file path", function()
        local path = note.create_blank_note(tmpdir)
        assert.is_not_nil(path)
        assert.is_string(path)
    end)

    it("creates a file on disk", function()
        local path = note.create_blank_note(tmpdir)
        assert.is_true(fs.file_exists(path))
    end)

    it("creates file with correct naming pattern", function()
        local path = note.create_blank_note(tmpdir)
        local fname = vim.fn.fnamemodify(path, ":t")
        -- Should match: YYYY-MM-DD_HH-MM-SS--note.md
        assert.truthy(
            fname:match("^%d%d%d%d%-%d%d%-%d%d_%d%d%-%d%d%-%d%d%-%-note%.md$"),
            "filename should match timestamp--note.md pattern, got: " .. fname
        )
    end)

    it("creates file inside the specified directory", function()
        local path = note.create_blank_note(tmpdir)
        assert.truthy(path:match("^" .. vim.pesc(tmpdir)))
    end)

    it("creates inbox directory if it does not exist", function()
        local new_inbox = tmpdir .. "/new_inbox"
        local path = note.create_blank_note(new_inbox)
        assert.is_not_nil(path)
        assert.is_true(fs.dir_exists(new_inbox))
    end)

    it("handles filename collisions", function()
        -- Create two notes in rapid succession
        local path1 = note.create_blank_note(tmpdir)
        local path2 = note.create_blank_note(tmpdir)
        assert.is_not_nil(path1)
        assert.is_not_nil(path2)
        assert.is_not.equals(path1, path2)
        assert.is_true(fs.file_exists(path1))
        assert.is_true(fs.file_exists(path2))
    end)
end)

describe("note.create_blank_note with auto_save_new_note = false", function()
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
        })
    end)

    it("returns a path but does not write to disk", function()
        local path = note.create_blank_note(tmpdir)
        assert.is_not_nil(path)
        assert.is_false(fs.file_exists(path))
    end)
end)

describe("note.create_with_params", function()
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
        })
    end)

    it("creates a file with label in the specified directory", function()
        local path = note.create_with_params(tmpdir .. "/projects", "miata-boost")
        assert.is_not_nil(path)
        assert.is_true(fs.file_exists(path))

        local fname = vim.fn.fnamemodify(path, ":t")
        assert.truthy(fname:match("^miata%-boost%-"), "filename should start with label")
        assert.truthy(fname:match("%-%-note%.md$"), "filename should end with --note.md")
    end)

    it("creates a file without label (nil)", function()
        local path = note.create_with_params(tmpdir .. "/projects", nil)
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
        local path = note.create_with_params(tmpdir .. "/projects", "")
        assert.is_not_nil(path)

        local fname = vim.fn.fnamemodify(path, ":t")
        assert.truthy(
            fname:match("^%d%d%d%d%-%d%d%-%d%d_%d%d%-%d%d%-%d%d%-%-note%.md"),
            "should be timestamp-only filename"
        )
    end)

    it("creates file in the correct directory", function()
        local dest = tmpdir .. "/projects"
        local path = note.create_with_params(dest, "test")
        assert.truthy(path:match("^" .. vim.pesc(dest)), "file should be in target directory")
    end)

    it("handles collision when creating rapidly", function()
        local dest = tmpdir .. "/projects"
        local path1 = note.create_with_params(dest, "rapid")
        local path2 = note.create_with_params(dest, "rapid")
        assert.is_not_nil(path1)
        assert.is_not_nil(path2)
        assert.is_not.equals(path1, path2)
    end)
end)

describe("note.validate_current_buffer", function()
    it("returns false for empty buffer", function()
        -- Switch to a fresh empty buffer
        vim.cmd("enew!")
        local valid, msg = note.validate_current_buffer()
        assert.is_false(valid)
        assert.equals("Current buffer has no file", msg)
    end)

    it("returns true for a valid file buffer", function()
        local tmpfile = vim.fn.tempname() .. ".md"
        fs.write_file(tmpfile, "test content")
        vim.cmd.edit(tmpfile)

        local valid, filepath = note.validate_current_buffer()
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
        })

        local tmpfile = vim.fn.tempname() .. ".txt"
        fs.write_file(tmpfile, "test content")
        vim.cmd.edit(tmpfile)

        local valid, msg = note.validate_current_buffer()
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
        })
    end)

    it("returns true for non-markdown when allow_non_md is true", function()
        local tmpfile = vim.fn.tempname() .. ".txt"
        fs.write_file(tmpfile, "test content")
        vim.cmd.edit(tmpfile)

        local valid, filepath = note.validate_current_buffer()
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

        local valid, msg = note.validate_current_buffer()
        assert.is_false(valid)
        assert.equals("Current file does not exist on disk", msg)

        vim.cmd("bdelete!")
    end)
end)

describe("note.execute_sort", function()
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
        })
    end)

    it("moves file to destination with label", function()
        local source = tmpdir .. "/inbox/2025-10-08_09-17-33--note.md"
        fs.write_file(source, "test content")
        vim.cmd.edit(source)

        local original_notify = vim.notify
        vim.notify = function() end

        local success, new_path = note.execute_sort(source, tmpdir .. "/dest", "project")

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

        local success, new_path = note.execute_sort(source, tmpdir .. "/dest", nil)

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

        local success, new_path = note.execute_sort(source, tmpdir .. "/dest", "labeled")

        vim.notify = original_notify

        assert.is_true(success)
        -- Original timestamp should be in the new filename
        assert.truthy(new_path:match("2025%-06%-15_12%-30%-00"))
    end)
end)

describe("note.list_inbox", function()
    local tmpdir
    local original_notify

    before_each(function()
        tmpdir = vim.fn.tempname() .. "_list_inbox_test"
        vim.fn.mkdir(tmpdir, "p")
        config.setup({
            inbox_dir = tmpdir,
            base_dir = tmpdir,
            file_ext = ".md",
            timestamp_fmt = "%Y-%m-%d_%H-%M-%S",
            open_after_create = false,
            auto_save_new_note = true,
            notify = false,
            trailing_marker = "--note",
            exclude_dirs = {},
            allow_non_md = false,
        })
        -- Suppress vim.notify output in headless tests
        original_notify = vim.notify
        vim.notify = function() end
    end)

    after_each(function()
        vim.notify = original_notify
        vim.fn.delete(tmpdir, "rf")
        local test_tmp = _G._cubby_test_tmp
        config.setup({
            inbox_dir = test_tmp .. "/inbox",
            base_dir = test_tmp .. "/notes",
            notify = false,
            auto_save_new_note = true,
        })
    end)

    it("does not error with empty inbox", function()
        -- Stub vim.ui.select to prevent interactive prompt
        local original_select = vim.ui.select
        local called = false
        vim.ui.select = function(items, opts, on_choice)
            called = true
        end

        assert.has_no.errors(function()
            note.list_inbox({})
        end)
        -- Empty inbox should NOT call select (shows notification instead)
        assert.is_false(called, "should not call vim.ui.select for empty inbox")

        vim.ui.select = original_select
    end)

    it("does not error with non-existent inbox", function()
        config.setup({
            inbox_dir = tmpdir .. "/nonexistent",
            base_dir = tmpdir,
            notify = false,
        })

        -- Even with a non-existent inbox, should not throw
        assert.has_no.errors(function()
            note.list_inbox({})
        end)
    end)

    it("presents notes to picker when inbox has files", function()
        -- Create some test notes
        fs.write_file(tmpdir .. "/2025-10-08_09-17-33--note.md", "note 1")
        fs.write_file(tmpdir .. "/2025-10-09_10-00-00--note.md", "note 2")
        fs.write_file(tmpdir .. "/2025-10-10_11-30-00--note.md", "note 3")

        local original_select = vim.ui.select
        local picker_items = nil
        vim.ui.select = function(items, opts, on_choice)
            picker_items = items
        end

        note.list_inbox({})

        assert.is_not_nil(picker_items, "should have called vim.ui.select")
        assert.equals(3, #picker_items)

        vim.ui.select = original_select
    end)

    it("sorts notes newest-first by default", function()
        fs.write_file(tmpdir .. "/2025-10-08_09-17-33--note.md", "old")
        fs.write_file(tmpdir .. "/2025-10-10_11-30-00--note.md", "new")

        local original_select = vim.ui.select
        local picker_items = nil
        vim.ui.select = function(items, opts, on_choice)
            picker_items = items
        end

        note.list_inbox({})

        assert.is_not_nil(picker_items)
        -- First item should be the newer note (2025-10-10)
        assert.truthy(picker_items[1]:match("2025%-10%-10"), "first item should be newest")

        vim.ui.select = original_select
    end)

    it("sorts notes oldest-first when specified", function()
        fs.write_file(tmpdir .. "/2025-10-08_09-17-33--note.md", "old")
        fs.write_file(tmpdir .. "/2025-10-10_11-30-00--note.md", "new")

        local original_select = vim.ui.select
        local picker_items = nil
        vim.ui.select = function(items, opts, on_choice)
            picker_items = items
        end

        note.list_inbox({ sort = "oldest" })

        assert.is_not_nil(picker_items)
        -- First item should be the older note (2025-10-08)
        assert.truthy(picker_items[1]:match("2025%-10%-08"), "first item should be oldest")

        vim.ui.select = original_select
    end)

    it("only includes .md files when allow_non_md is false", function()
        fs.write_file(tmpdir .. "/2025-10-08_09-17-33--note.md", "markdown")
        fs.write_file(tmpdir .. "/2025-10-09_10-00-00--note.txt", "text")
        fs.write_file(tmpdir .. "/random.log", "log")

        local original_select = vim.ui.select
        local picker_items = nil
        vim.ui.select = function(items, opts, on_choice)
            picker_items = items
        end

        note.list_inbox({})

        assert.is_not_nil(picker_items)
        assert.equals(1, #picker_items)

        vim.ui.select = original_select
    end)

    it("includes all files when allow_non_md is true", function()
        config.setup({
            inbox_dir = tmpdir,
            base_dir = tmpdir,
            file_ext = ".md",
            notify = false,
            allow_non_md = true,
        })

        fs.write_file(tmpdir .. "/2025-10-08_09-17-33--note.md", "markdown")
        fs.write_file(tmpdir .. "/2025-10-09_10-00-00--note.txt", "text")

        local original_select = vim.ui.select
        local picker_items = nil
        vim.ui.select = function(items, opts, on_choice)
            picker_items = items
        end

        note.list_inbox({})

        assert.is_not_nil(picker_items)
        assert.equals(2, #picker_items)

        vim.ui.select = original_select
    end)

    it("includes first non-empty line as preview in display", function()
        fs.write_file(tmpdir .. "/2025-01-01_00-00-00--note.md", "My important thought\nMore content")

        local original_select = vim.ui.select
        local picker_items = nil
        vim.ui.select = function(items, opts, on_choice)
            picker_items = items
        end

        note.list_inbox({})

        assert.is_not_nil(picker_items)
        assert.equals(1, #picker_items)
        assert.truthy(picker_items[1]:find("My important thought", 1, true), "should contain preview text")
        assert.truthy(picker_items[1]:find("—", 1, true), "should contain em-dash separator")

        vim.ui.select = original_select
    end)

    it("skips blank lines to find first non-empty line for preview", function()
        fs.write_file(tmpdir .. "/2025-01-01_00-00-00--note.md", "\n\n\nActual content here")

        local original_select = vim.ui.select
        local picker_items = nil
        vim.ui.select = function(items, opts, on_choice)
            picker_items = items
        end

        note.list_inbox({})

        assert.is_not_nil(picker_items)
        assert.truthy(picker_items[1]:find("Actual content here", 1, true), "should find content past blank lines")

        vim.ui.select = original_select
    end)

    it("omits preview separator for empty files", function()
        fs.write_file(tmpdir .. "/2025-01-01_00-00-00--note.md", "")

        local original_select = vim.ui.select
        local picker_items = nil
        vim.ui.select = function(items, opts, on_choice)
            picker_items = items
        end

        note.list_inbox({})

        assert.is_not_nil(picker_items)
        assert.equals(1, #picker_items)
        assert.falsy(picker_items[1]:find("—", 1, true), "should not have em-dash for empty file")

        vim.ui.select = original_select
    end)

    it("omits preview separator for whitespace-only files", function()
        fs.write_file(tmpdir .. "/2025-01-01_00-00-00--note.md", "\n\n   \n\t\n")

        local original_select = vim.ui.select
        local picker_items = nil
        vim.ui.select = function(items, opts, on_choice)
            picker_items = items
        end

        note.list_inbox({})

        assert.is_not_nil(picker_items)
        assert.equals(1, #picker_items)
        assert.falsy(picker_items[1]:find("—", 1, true), "should not have em-dash for whitespace-only file")

        vim.ui.select = original_select
    end)

    it("truncates long preview lines", function()
        local long_line = string.rep("a", 80)
        fs.write_file(tmpdir .. "/2025-01-01_00-00-00--note.md", long_line)

        local original_select = vim.ui.select
        local picker_items = nil
        vim.ui.select = function(items, opts, on_choice)
            picker_items = items
        end

        note.list_inbox({})

        assert.is_not_nil(picker_items)
        assert.truthy(picker_items[1]:find("…", 1, true), "should have ellipsis for truncated preview")
        -- The full 80-char line should NOT appear
        assert.falsy(picker_items[1]:find(long_line, 1, true), "should not contain full untruncated line")

        vim.ui.select = original_select
    end)

    it("preserves markdown header in preview", function()
        fs.write_file(tmpdir .. "/2025-01-01_00-00-00--note.md", "# My Note Title\nSome content")

        local original_select = vim.ui.select
        local picker_items = nil
        vim.ui.select = function(items, opts, on_choice)
            picker_items = items
        end

        note.list_inbox({})

        assert.is_not_nil(picker_items)
        assert.truthy(picker_items[1]:find("# My Note Title", 1, true), "should preserve markdown syntax in preview")

        vim.ui.select = original_select
    end)
end)
