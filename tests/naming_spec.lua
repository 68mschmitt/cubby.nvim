--- Tests for cubby.naming — Filename building, label handling, and timestamp operations
local naming = require("cubby.naming")
local fs = require("cubby.fs")

describe("naming.build_sorted_filename", function()
    it("builds filename with label", function()
        local result = naming.build_sorted_filename("miata-boost", "2025-10-08_11-07-15", ".md", "--note")
        assert.equals("miata-boost-2025-10-08_11-07-15--note.md", result)
    end)

    it("builds filename without label (empty string)", function()
        local result = naming.build_sorted_filename("", "2025-10-08_11-07-15", ".md", "--note")
        assert.equals("2025-10-08_11-07-15--note.md", result)
    end)

    it("builds filename without label (nil)", function()
        local result = naming.build_sorted_filename(nil, "2025-10-08_11-07-15", ".md", "--note")
        assert.equals("2025-10-08_11-07-15--note.md", result)
    end)

    it("works with custom extension", function()
        local result = naming.build_sorted_filename("test", "2025-01-01_00-00-00", ".txt", "--note")
        assert.equals("test-2025-01-01_00-00-00--note.txt", result)
    end)

    it("works with custom marker", function()
        local result = naming.build_sorted_filename("test", "2025-01-01_00-00-00", ".md", "--memo")
        assert.equals("test-2025-01-01_00-00-00--memo.md", result)
    end)
end)

describe("naming.extract_label_and_remainder", function()
    it("extracts label and timestamp from labeled filename", function()
        local label, ts = naming.extract_label_and_remainder("miata-boost-2025-10-08_11-07-15--note.md")
        assert.equals("miata-boost", label)
        assert.equals("2025-10-08_11-07-15", ts)
    end)

    it("returns nil label for timestamp-only filename", function()
        local label, ts = naming.extract_label_and_remainder("2025-10-08_09-17-33--note.md")
        assert.is_nil(label)
        assert.equals("2025-10-08_09-17-33", ts)
    end)

    it("returns basename as label when no timestamp found", function()
        local label, ts = naming.extract_label_and_remainder("random-note.md")
        assert.equals("random-note", label)
        assert.is_nil(ts)
    end)

    it("handles filename with path prefix", function()
        local label, ts = naming.extract_label_and_remainder("/some/path/project-2025-03-15_10-20-30--note.md")
        assert.equals("project", label)
        assert.equals("2025-03-15_10-20-30", ts)
    end)

    it("handles single-word label before timestamp", function()
        local label, ts = naming.extract_label_and_remainder("draft-2025-06-01_08-00-00--note.md")
        assert.equals("draft", label)
        assert.equals("2025-06-01_08-00-00", ts)
    end)
end)

describe("naming.build_filename_for_sort", function()
    it("replaces original label with new label", function()
        local result = naming.build_filename_for_sort(
            "project",
            "old-label-2025-10-08_11-07-15--note.md",
            "2025-10-08_11-07-15",
            ".md",
            "--note"
        )
        assert.equals("project-2025-10-08_11-07-15--note.md", result)
    end)

    it("uses only new label when original has no label", function()
        local result = naming.build_filename_for_sort(
            "project",
            "2025-10-08_09-17-33--note.md",
            "2025-10-08_09-17-33",
            ".md",
            "--note"
        )
        assert.equals("project-2025-10-08_09-17-33--note.md", result)
    end)

    it("preserves original label when no new label provided (nil)", function()
        local result = naming.build_filename_for_sort(
            nil,
            "old-label-2025-10-08_11-07-15--note.md",
            "2025-10-08_11-07-15",
            ".md",
            "--note"
        )
        assert.equals("old-label-2025-10-08_11-07-15--note.md", result)
    end)

    it("preserves original label when no new label provided (empty)", function()
        local result = naming.build_filename_for_sort(
            "",
            "old-label-2025-10-08_11-07-15--note.md",
            "2025-10-08_11-07-15",
            ".md",
            "--note"
        )
        assert.equals("old-label-2025-10-08_11-07-15--note.md", result)
    end)

    it("uses timestamp-only when neither label is present", function()
        local result =
            naming.build_filename_for_sort(nil, "2025-10-08_09-17-33--note.md", "2025-10-08_09-17-33", ".md", "--note")
        assert.equals("2025-10-08_09-17-33--note.md", result)
    end)

    it("does not chain labels on repeated sorts", function()
        -- Simulate a file that was already sorted with label "first"
        local result = naming.build_filename_for_sort(
            "second",
            "first-2025-10-08_11-07-15--note.md",
            "2025-10-08_11-07-15",
            ".md",
            "--note"
        )
        -- Should replace, not produce "second-first-timestamp"
        assert.equals("second-2025-10-08_11-07-15--note.md", result)
    end)
end)

describe("naming.ensure_unique", function()
    local tmpdir

    before_each(function()
        tmpdir = vim.fn.tempname() .. "_unique_test"
        vim.fn.mkdir(tmpdir, "p")
    end)

    after_each(function()
        vim.fn.delete(tmpdir, "rf")
    end)

    it("returns original filename when no collision", function()
        local result = naming.ensure_unique(tmpdir, "test--note.md")
        assert.equals("test--note.md", result)
    end)

    it("returns filename with --2 suffix on first collision", function()
        fs.write_file(tmpdir .. "/test--note.md", "")
        local result = naming.ensure_unique(tmpdir, "test--note.md")
        assert.equals("test--note--2.md", result)
    end)

    it("increments counter for multiple collisions", function()
        fs.write_file(tmpdir .. "/test--note.md", "")
        fs.write_file(tmpdir .. "/test--note--2.md", "")
        local result = naming.ensure_unique(tmpdir, "test--note.md")
        assert.equals("test--note--3.md", result)
    end)

    it("preserves file extension", function()
        fs.write_file(tmpdir .. "/test--note.txt", "")
        local result = naming.ensure_unique(tmpdir, "test--note.txt")
        assert.equals("test--note--2.txt", result)
    end)

    it("returns nil when max attempts exceeded", function()
        -- Create file for the base name and the only collision variant
        fs.write_file(tmpdir .. "/test--note.md", "")
        fs.write_file(tmpdir .. "/test--note--2.md", "")
        local result, err = naming.ensure_unique(tmpdir, "test--note.md", 2)
        assert.is_nil(result)
        assert.is_string(err)
        assert.truthy(err:match("Could not generate unique filename"))
    end)
end)

describe("naming.sanitize_label", function()
    it("returns empty string for nil", function()
        assert.equals("", naming.sanitize_label(nil))
    end)

    it("returns empty string for empty string", function()
        assert.equals("", naming.sanitize_label(""))
    end)

    it("lowercases input", function()
        assert.equals("hello", naming.sanitize_label("HELLO"))
    end)

    it("replaces spaces with hyphens", function()
        assert.equals("hello-world", naming.sanitize_label("hello world"))
    end)

    it("replaces multiple spaces with single hyphen", function()
        assert.equals("hello-world", naming.sanitize_label("hello   world"))
    end)

    it("strips special characters", function()
        assert.equals("helloworld", naming.sanitize_label("hello!@#$world"))
    end)

    it("collapses multiple hyphens", function()
        assert.equals("hello-world", naming.sanitize_label("hello---world"))
    end)

    it("trims leading hyphens", function()
        assert.equals("hello", naming.sanitize_label("---hello"))
    end)

    it("trims trailing hyphens", function()
        assert.equals("hello", naming.sanitize_label("hello---"))
    end)

    it("preserves digits", function()
        assert.equals("note-42", naming.sanitize_label("Note 42"))
    end)

    it("handles mixed case with spaces and special chars", function()
        assert.equals("my-cool-note", naming.sanitize_label("My Cool Note!"))
    end)

    it("returns empty for input that sanitizes to nothing", function()
        assert.equals("", naming.sanitize_label("!@#$%^&*()"))
    end)

    it("handles tabs and mixed whitespace", function()
        assert.equals("hello-world", naming.sanitize_label("hello\t  world"))
    end)
end)

describe("naming.validate_label", function()
    it("returns false for nil", function()
        assert.is_false(naming.validate_label(nil))
    end)

    it("returns false for empty string", function()
        assert.is_false(naming.validate_label(""))
    end)

    it("returns true for non-empty string", function()
        assert.is_true(naming.validate_label("hello"))
    end)

    it("returns true for single character", function()
        assert.is_true(naming.validate_label("a"))
    end)
end)

describe("naming.now_stamp", function()
    it("returns a formatted timestamp string", function()
        local stamp = naming.now_stamp("%Y-%m-%d_%H-%M-%S")
        assert.is_string(stamp)
        assert.truthy(stamp:match("^%d%d%d%d%-%d%d%-%d%d_%d%d%-%d%d%-%d%d$"))
    end)

    it("errors when format is nil", function()
        assert.has.errors(function()
            naming.now_stamp(nil)
        end)
    end)

    it("respects custom format", function()
        local stamp = naming.now_stamp("%Y")
        assert.is_string(stamp)
        assert.truthy(stamp:match("^%d%d%d%d$"))
    end)
end)

describe("naming.format_relative_time", function()
    local now = os.time()

    it("returns 'just now' for timestamps within 60 seconds", function()
        assert.equals("just now", naming.format_relative_time(now))
        assert.equals("just now", naming.format_relative_time(now - 30))
        assert.equals("just now", naming.format_relative_time(now - 59))
    end)

    it("returns minutes ago for 1-59 minutes", function()
        assert.equals("1 minute ago", naming.format_relative_time(now - 60))
        assert.equals("5 minutes ago", naming.format_relative_time(now - 300))
        assert.equals("59 minutes ago", naming.format_relative_time(now - 3540))
    end)

    it("handles singular minute", function()
        assert.equals("1 minute ago", naming.format_relative_time(now - 60))
        assert.equals("1 minute ago", naming.format_relative_time(now - 119))
    end)

    it("returns hours ago for 1-23 hours", function()
        assert.equals("1 hour ago", naming.format_relative_time(now - 3600))
        assert.equals("5 hours ago", naming.format_relative_time(now - 18000))
        assert.equals("23 hours ago", naming.format_relative_time(now - 82800))
    end)

    it("handles singular hour", function()
        assert.equals("1 hour ago", naming.format_relative_time(now - 3600))
    end)

    it("returns 'yesterday' for 24-47 hours", function()
        assert.equals("yesterday", naming.format_relative_time(now - 86400))
        assert.equals("yesterday", naming.format_relative_time(now - 172799))
    end)

    it("returns days ago for 2-6 days", function()
        assert.equals("2 days ago", naming.format_relative_time(now - 172800))
        assert.equals("6 days ago", naming.format_relative_time(now - 518400))
    end)

    it("returns '1 week ago' for 7-13 days", function()
        assert.equals("1 week ago", naming.format_relative_time(now - 604800))
        assert.equals("1 week ago", naming.format_relative_time(now - 1209599))
    end)

    it("returns weeks ago for 2-4 weeks", function()
        assert.equals("2 weeks ago", naming.format_relative_time(now - 1209600))
        assert.equals("3 weeks ago", naming.format_relative_time(now - 2000000))
    end)

    it("returns '1 month ago' for 30-59 days", function()
        assert.equals("1 month ago", naming.format_relative_time(now - 2592000))
        assert.equals("1 month ago", naming.format_relative_time(now - 5183999))
    end)

    it("returns months ago for 2+ months", function()
        assert.equals("2 months ago", naming.format_relative_time(now - 5184000))
    end)
end)

describe("naming.TIMESTAMP_PATTERN", function()
    it("matches a valid timestamp string", function()
        local ts = "2025-10-08_09-17-33"
        assert.truthy(ts:match(naming.TIMESTAMP_PATTERN))
    end)

    it("does not match incomplete timestamp", function()
        local ts = "2025-10-08"
        -- The pattern should not match a date-only string as a full timestamp
        local matched = ts:match("^" .. naming.TIMESTAMP_PATTERN .. "$")
        assert.is_nil(matched)
    end)
end)

describe("naming.extract_timestamp_from_filename", function()
    it("extracts timestamp from standard note filename", function()
        local ts = naming.extract_timestamp_from_filename("2025-10-08_09-17-33--note.md")
        assert.equals("2025-10-08_09-17-33", ts)
    end)

    it("extracts timestamp from labeled filename", function()
        local ts = naming.extract_timestamp_from_filename("miata-boost-2025-10-08_11-07-15--note.md")
        assert.equals("2025-10-08_11-07-15", ts)
    end)

    it("extracts timestamp from path with directories", function()
        local ts = naming.extract_timestamp_from_filename("/home/user/notes/inbox/2025-01-15_14-30-00--note.md")
        assert.equals("2025-01-15_14-30-00", ts)
    end)

    it("returns nil for filename with no timestamp", function()
        local ts = naming.extract_timestamp_from_filename("random-note.md")
        assert.is_nil(ts)
    end)

    it("returns nil for empty filename", function()
        local ts = naming.extract_timestamp_from_filename("")
        assert.is_nil(ts)
    end)
end)

describe("naming.parse_to_unix", function()
    it("parses a valid timestamp string to unix time", function()
        local unix = naming.parse_to_unix("2025-01-01_00-00-00")
        assert.is_not_nil(unix)
        assert.is_number(unix)
        -- Should be a reasonable unix timestamp (after 2024)
        assert.is_true(unix > 1700000000, "should be a recent unix timestamp")
    end)

    it("returns nil for nil input", function()
        assert.is_nil(naming.parse_to_unix(nil))
    end)

    it("returns nil for malformed string", function()
        assert.is_nil(naming.parse_to_unix("not-a-timestamp"))
    end)

    it("returns nil for empty string", function()
        assert.is_nil(naming.parse_to_unix(""))
    end)

    it("parses specific known date correctly", function()
        local unix = naming.parse_to_unix("2025-06-15_12-30-45")
        assert.is_not_nil(unix)
        local t = os.date("*t", unix)
        assert.equals(2025, t.year)
        assert.equals(6, t.month)
        assert.equals(15, t.day)
        assert.equals(12, t.hour)
        assert.equals(30, t.min)
        assert.equals(45, t.sec)
    end)
end)

describe("naming.preserve_or_fallback_timestamp", function()
    it("extracts timestamp from filename when present", function()
        local ts = naming.preserve_or_fallback_timestamp(
            "2025-10-08_09-17-33--note.md",
            "/tmp/nonexistent",
            "%Y-%m-%d_%H-%M-%S"
        )
        assert.equals("2025-10-08_09-17-33", ts)
    end)

    it("falls back to current time when no filename timestamp and no file", function()
        local ts = naming.preserve_or_fallback_timestamp(
            "random-note.md",
            "/tmp/definitely-does-not-exist-12345",
            "%Y-%m-%d_%H-%M-%S"
        )
        assert.is_not_nil(ts)
        assert.is_string(ts)
        -- Should match the timestamp pattern
        assert.truthy(ts:match("^%d%d%d%d%-%d%d%-%d%d_%d%d%-%d%d%-%d%d$"))
    end)
end)

describe("naming.update_timestamp_pattern", function()
    it("derives correct pattern for default format", function()
        naming.update_timestamp_pattern("%Y-%m-%d_%H-%M-%S")
        assert.equals("%d%d%d%d%-%d%d%-%d%d_%d%d%-%d%d%-%d%d", naming.TIMESTAMP_PATTERN)
    end)

    it("derived pattern matches a valid timestamp", function()
        naming.update_timestamp_pattern("%Y-%m-%d_%H-%M-%S")
        local ts = "2025-10-08_09-17-33"
        assert.truthy(ts:match("^" .. naming.TIMESTAMP_PATTERN .. "$"))
    end)

    it("derived pattern does not match invalid timestamp", function()
        naming.update_timestamp_pattern("%Y-%m-%d_%H-%M-%S")
        local ts = "2025-10-08"
        assert.is_nil(ts:match("^" .. naming.TIMESTAMP_PATTERN .. "$"))
    end)

    it("handles alternative format without separators", function()
        naming.update_timestamp_pattern("%Y%m%d%H%M%S")
        assert.equals("%d%d%d%d%d%d%d%d%d%d%d%d%d%d", naming.TIMESTAMP_PATTERN)
        local ts = "20251008091733"
        assert.truthy(ts:match("^" .. naming.TIMESTAMP_PATTERN .. "$"))
        -- Restore default
        naming.update_timestamp_pattern("%Y-%m-%d_%H-%M-%S")
    end)

    it("handles format with custom separators", function()
        naming.update_timestamp_pattern("%Y/%m/%d %H:%M:%S")
        assert.equals("%d%d%d%d/%d%d/%d%d %d%d:%d%d:%d%d", naming.TIMESTAMP_PATTERN)
        local ts = "2025/10/08 09:17:33"
        assert.truthy(ts:match("^" .. naming.TIMESTAMP_PATTERN .. "$"))
        -- Restore default
        naming.update_timestamp_pattern("%Y-%m-%d_%H-%M-%S")
    end)

    it("handles 2-digit year format", function()
        naming.update_timestamp_pattern("%y-%m-%d_%H-%M-%S")
        assert.equals("%d%d%-%d%d%-%d%d_%d%d%-%d%d%-%d%d", naming.TIMESTAMP_PATTERN)
        local ts = "25-10-08_09-17-33"
        assert.truthy(ts:match("^" .. naming.TIMESTAMP_PATTERN .. "$"))
        -- Restore default
        naming.update_timestamp_pattern("%Y-%m-%d_%H-%M-%S")
    end)
end)
