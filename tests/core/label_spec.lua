--- Tests for cubby.core.label — Label sanitization and validation
local label = require("cubby.core.label")

describe("label.sanitize_label", function()
    it("returns empty string for nil", function()
        assert.equals("", label.sanitize_label(nil))
    end)

    it("returns empty string for empty string", function()
        assert.equals("", label.sanitize_label(""))
    end)

    it("lowercases input", function()
        assert.equals("hello", label.sanitize_label("HELLO"))
    end)

    it("replaces spaces with hyphens", function()
        assert.equals("hello-world", label.sanitize_label("hello world"))
    end)

    it("replaces multiple spaces with single hyphen", function()
        assert.equals("hello-world", label.sanitize_label("hello   world"))
    end)

    it("strips special characters", function()
        assert.equals("helloworld", label.sanitize_label("hello!@#$world"))
    end)

    it("collapses multiple hyphens", function()
        assert.equals("hello-world", label.sanitize_label("hello---world"))
    end)

    it("trims leading hyphens", function()
        assert.equals("hello", label.sanitize_label("---hello"))
    end)

    it("trims trailing hyphens", function()
        assert.equals("hello", label.sanitize_label("hello---"))
    end)

    it("preserves digits", function()
        assert.equals("note-42", label.sanitize_label("Note 42"))
    end)

    it("handles mixed case with spaces and special chars", function()
        assert.equals("my-cool-note", label.sanitize_label("My Cool Note!"))
    end)

    it("returns empty for input that sanitizes to nothing", function()
        assert.equals("", label.sanitize_label("!@#$%^&*()"))
    end)

    it("handles tabs and mixed whitespace", function()
        assert.equals("hello-world", label.sanitize_label("hello\t  world"))
    end)
end)

describe("label.validate_label", function()
    it("returns false for nil", function()
        assert.is_false(label.validate_label(nil))
    end)

    it("returns false for empty string", function()
        assert.is_false(label.validate_label(""))
    end)

    it("returns true for non-empty string", function()
        assert.is_true(label.validate_label("hello"))
    end)

    it("returns true for single character", function()
        assert.is_true(label.validate_label("a"))
    end)
end)
