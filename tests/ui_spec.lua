--- Tests for cubby.ui — UI components including directory picker and input prompts
local ui_mod = require("cubby.ui")
local fs = require("cubby.fs")

describe("ui_mod.build_picker_items", function()
    it("includes subdirectories, Drop Here, and Create New", function()
        local items = ui_mod.build_picker_items("/base", "/base", { "alpha", "beta" })
        assert.equals(4, #items)
        assert.equals("alpha", items[1])
        assert.equals("beta", items[2])
        assert.equals("✓ Drop Here", items[3])
        assert.equals("+ Create New", items[4])
    end)

    it("includes Go Back when not at base", function()
        local items = ui_mod.build_picker_items("/base", "/base/sub", { "child" })
        assert.equals(4, #items) -- child, Drop Here, Create New, Go Back
        assert.equals("child", items[1])
        assert.equals("← Go Back", items[4])
    end)

    it("excludes Go Back at base directory", function()
        local items = ui_mod.build_picker_items("/base", "/base", {})
        for _, item in ipairs(items) do
            assert.is_not.equals("← Go Back", item)
        end
    end)

    it("handles empty subdirectory list", function()
        local items = ui_mod.build_picker_items("/base", "/base", {})
        assert.equals(2, #items) -- Drop Here, Create New
        assert.equals("✓ Drop Here", items[1])
        assert.equals("+ Create New", items[2])
    end)

    it("normalizes trailing slashes for Go Back check", function()
        local items = ui_mod.build_picker_items("/base/", "/base", {})
        -- Should NOT include Go Back since paths are equivalent
        for _, item in ipairs(items) do
            assert.is_not.equals("← Go Back", item)
        end
    end)
end)

describe("ui_mod.handle_picker_selection", function()
    it("calls callback with current_path for Drop Here", function()
        local result
        ui_mod.handle_picker_selection("✓ Drop Here", "/base", "/base/current", {}, function(dir)
            result = dir
        end)
        assert.equals("/base/current", result)
    end)

    it("navigates to subdirectory on selection", function()
        -- Stub vim.ui.select to capture the recursive call
        local original_select = vim.ui.select
        local called_prompt = nil
        vim.ui.select = function(items, opts, on_choice)
            called_prompt = opts.prompt
        end

        local tmpdir = vim.fn.tempname() .. "_picker_test"
        vim.fn.mkdir(tmpdir, "p")
        vim.fn.mkdir(tmpdir .. "/child", "p")

        ui_mod.handle_picker_selection("child", tmpdir, tmpdir, {}, function() end)

        assert.is_not_nil(called_prompt)
        -- Prompt should reference the child directory
        assert.truthy(called_prompt:match("child"), "prompt should reference child dir")

        vim.fn.delete(tmpdir, "rf")
        vim.ui.select = original_select
    end)

    it("navigates to parent on Go Back", function()
        local original_select = vim.ui.select
        local called_prompt = nil
        vim.ui.select = function(items, opts, on_choice)
            called_prompt = opts.prompt
        end

        local tmpdir = vim.fn.tempname() .. "_picker_back_test"
        vim.fn.mkdir(tmpdir, "p")
        vim.fn.mkdir(tmpdir .. "/child", "p")

        ui_mod.handle_picker_selection("← Go Back", tmpdir, tmpdir .. "/child", {}, function() end)

        assert.is_not_nil(called_prompt)
        -- Should be back at the base (prompt shows "/")
        assert.truthy(called_prompt:match("%[/%]"), "should navigate back to base")

        vim.fn.delete(tmpdir, "rf")
        vim.ui.select = original_select
    end)
end)

describe("ui_mod.create_new_directory", function()
    local tmpdir

    before_each(function()
        tmpdir = vim.fn.tempname() .. "_newdir_test"
        vim.fn.mkdir(tmpdir, "p")
    end)

    after_each(function()
        vim.fn.delete(tmpdir, "rf")
    end)

    it("creates directory with sanitized name", function()
        local original_input = vim.ui.input
        local original_select = vim.ui.select
        local original_notify = vim.notify
        vim.notify = function() end

        vim.ui.input = function(opts, on_confirm)
            on_confirm("My New Dir")
        end
        -- After creating, show_directory_picker is called; stub it
        vim.ui.select = function(items, opts, on_choice) end

        ui_mod.create_new_directory(tmpdir, tmpdir, {}, function() end)

        -- sanitize_directory_name replaces spaces with hyphens but preserves case
        assert.is_true(fs.dir_exists(tmpdir .. "/My-New-Dir"))

        vim.ui.input = original_input
        vim.ui.select = original_select
        vim.notify = original_notify
    end)

    it("re-prompts on invalid directory name", function()
        local original_input = vim.ui.input
        local original_select = vim.ui.select
        local original_notify = vim.notify
        vim.notify = function() end

        local call_count = 0
        vim.ui.input = function(opts, on_confirm)
            call_count = call_count + 1
            if call_count == 1 then
                on_confirm("!@#$%") -- invalid: all stripped away
            else
                on_confirm("valid-name")
            end
        end
        vim.ui.select = function(items, opts, on_choice) end

        ui_mod.create_new_directory(tmpdir, tmpdir, {}, function() end)

        assert.equals(2, call_count)
        assert.is_true(fs.dir_exists(tmpdir .. "/valid-name"))

        vim.ui.input = original_input
        vim.ui.select = original_select
        vim.notify = original_notify
    end)

    it("returns to picker on empty input", function()
        local original_input = vim.ui.input
        local original_select = vim.ui.select

        vim.ui.input = function(opts, on_confirm)
            on_confirm("")
        end

        local select_called = false
        vim.ui.select = function(items, opts, on_choice)
            select_called = true
        end

        ui_mod.create_new_directory(tmpdir, tmpdir, {}, function() end)

        assert.is_true(select_called)

        vim.ui.input = original_input
        vim.ui.select = original_select
    end)

    it("returns to picker on nil input (cancelled)", function()
        local original_input = vim.ui.input
        local original_select = vim.ui.select

        vim.ui.input = function(opts, on_confirm)
            on_confirm(nil)
        end

        local select_called = false
        vim.ui.select = function(items, opts, on_choice)
            select_called = true
        end

        ui_mod.create_new_directory(tmpdir, tmpdir, {}, function() end)

        assert.is_true(select_called)

        vim.ui.input = original_input
        vim.ui.select = original_select
    end)
end)

describe("ui_mod.prompt_for_label", function()
    it("passes nil when user presses Enter to skip", function()
        local original_input = vim.ui.input
        vim.ui.input = function(opts, on_confirm)
            on_confirm("")
        end

        local result = "not_called"
        ui_mod.prompt_for_label(function(label)
            result = label
        end)

        assert.is_nil(result)
        vim.ui.input = original_input
    end)

    it("passes sanitized label for valid input", function()
        local original_input = vim.ui.input
        vim.ui.input = function(opts, on_confirm)
            on_confirm("My Cool Note")
        end

        local result
        ui_mod.prompt_for_label(function(label)
            result = label
        end)

        assert.equals("my-cool-note", result)
        vim.ui.input = original_input
    end)

    it("does not call back when user cancels (nil input)", function()
        local original_input = vim.ui.input
        vim.ui.input = function(opts, on_confirm)
            on_confirm(nil)
        end

        local called = false
        ui_mod.prompt_for_label(function(label)
            called = true
        end)

        assert.is_false(called)
        vim.ui.input = original_input
    end)

    it("re-prompts when input sanitizes to empty", function()
        local original_input = vim.ui.input
        local original_notify = vim.notify
        vim.notify = function() end

        local call_count = 0
        vim.ui.input = function(opts, on_confirm)
            call_count = call_count + 1
            if call_count == 1 then
                on_confirm("!@#$%") -- sanitizes to empty
            else
                on_confirm("") -- skip on retry
            end
        end

        local result = "not_called"
        ui_mod.prompt_for_label(function(label)
            result = label
        end)

        assert.equals(2, call_count)
        assert.is_nil(result) -- skipped on retry

        vim.ui.input = original_input
        vim.notify = original_notify
    end)

    it("preserves digits in labels", function()
        local original_input = vim.ui.input
        vim.ui.input = function(opts, on_confirm)
            on_confirm("Note 42")
        end

        local result
        ui_mod.prompt_for_label(function(label)
            result = label
        end)

        assert.equals("note-42", result)
        vim.ui.input = original_input
    end)
end)
