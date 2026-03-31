--- Tests for cubby.ui.input — User input prompts
local input = require("cubby.ui.input")

describe("input.prompt_for_label", function()
    it("passes nil when user presses Enter to skip", function()
        local original_input = vim.ui.input
        vim.ui.input = function(opts, on_confirm)
            on_confirm("")
        end

        local result = "not_called"
        input.prompt_for_label(function(label)
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
        input.prompt_for_label(function(label)
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
        input.prompt_for_label(function(label)
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
        input.prompt_for_label(function(label)
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
        input.prompt_for_label(function(label)
            result = label
        end)

        assert.equals("note-42", result)
        vim.ui.input = original_input
    end)
end)

describe("input.prompt_for_directory_name", function()
    it("passes user input to callback", function()
        local original_input = vim.ui.input
        vim.ui.input = function(opts, on_confirm)
            on_confirm("my-directory")
        end

        local result
        input.prompt_for_directory_name(function(name)
            result = name
        end)

        assert.equals("my-directory", result)
        vim.ui.input = original_input
    end)

    it("passes nil on cancel", function()
        local original_input = vim.ui.input
        vim.ui.input = function(opts, on_confirm)
            on_confirm(nil)
        end

        local result = "not_called"
        input.prompt_for_directory_name(function(name)
            result = name
        end)

        assert.is_nil(result)
        vim.ui.input = original_input
    end)
end)
