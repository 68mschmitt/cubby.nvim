--- Tests for cubby.note.list_inbox — Inbox scanning and display
local list_inbox_mod = require("cubby.note.list_inbox")
local fs = require("cubby.core.fs")
local config = require("cubby.config")

-- list_inbox calls vim.ui.select which we need to stub for tests.
-- For these tests, we focus on the scanning/metadata extraction logic
-- by testing indirectly through the module's behavior.

describe("list_inbox", function()
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
            enable_recent_dirs = false,
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
            enable_recent_dirs = true,
            max_recent_dirs = 5,
            recent_state_file = test_tmp .. "/cubby-mru.json",
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
            list_inbox_mod.list_inbox({})
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
            enable_recent_dirs = false,
        })

        -- Even with a non-existent inbox, should not throw
        assert.has_no.errors(function()
            list_inbox_mod.list_inbox({})
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

        list_inbox_mod.list_inbox({})

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

        list_inbox_mod.list_inbox({})

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

        list_inbox_mod.list_inbox({ sort = "oldest" })

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

        list_inbox_mod.list_inbox({})

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
             enable_recent_dirs = false,
         })

         fs.write_file(tmpdir .. "/2025-10-08_09-17-33--note.md", "markdown")
         fs.write_file(tmpdir .. "/2025-10-09_10-00-00--note.txt", "text")

         local original_select = vim.ui.select
         local picker_items = nil
         vim.ui.select = function(items, opts, on_choice)
             picker_items = items
         end

         list_inbox_mod.list_inbox({})

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

         list_inbox_mod.list_inbox({})

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

         list_inbox_mod.list_inbox({})

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

         list_inbox_mod.list_inbox({})

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

         list_inbox_mod.list_inbox({})

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

         list_inbox_mod.list_inbox({})

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

         list_inbox_mod.list_inbox({})

         assert.is_not_nil(picker_items)
         assert.truthy(picker_items[1]:find("# My Note Title", 1, true), "should preserve markdown syntax in preview")

         vim.ui.select = original_select
     end)
end)
