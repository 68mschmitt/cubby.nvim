--- Tests for cubby.core.filename — Filename building, parsing, and uniqueness
local filename = require("cubby.core.filename")
local fs = require("cubby.core.fs")

describe("filename.build_sorted_filename", function()
    it("builds filename with label", function()
        local result = filename.build_sorted_filename("miata-boost", "2025-10-08_11-07-15", ".md", "--note")
        assert.equals("miata-boost-2025-10-08_11-07-15--note.md", result)
    end)

    it("builds filename without label (empty string)", function()
        local result = filename.build_sorted_filename("", "2025-10-08_11-07-15", ".md", "--note")
        assert.equals("2025-10-08_11-07-15--note.md", result)
    end)

    it("builds filename without label (nil)", function()
        local result = filename.build_sorted_filename(nil, "2025-10-08_11-07-15", ".md", "--note")
        assert.equals("2025-10-08_11-07-15--note.md", result)
    end)

    it("works with custom extension", function()
        local result = filename.build_sorted_filename("test", "2025-01-01_00-00-00", ".txt", "--note")
        assert.equals("test-2025-01-01_00-00-00--note.txt", result)
    end)

    it("works with custom marker", function()
        local result = filename.build_sorted_filename("test", "2025-01-01_00-00-00", ".md", "--memo")
        assert.equals("test-2025-01-01_00-00-00--memo.md", result)
    end)
end)

describe("filename.extract_label_and_remainder", function()
    it("extracts label and timestamp from labeled filename", function()
        local label, ts = filename.extract_label_and_remainder("miata-boost-2025-10-08_11-07-15--note.md")
        assert.equals("miata-boost", label)
        assert.equals("2025-10-08_11-07-15", ts)
    end)

    it("returns nil label for timestamp-only filename", function()
        local label, ts = filename.extract_label_and_remainder("2025-10-08_09-17-33--note.md")
        assert.is_nil(label)
        assert.equals("2025-10-08_09-17-33", ts)
    end)

    it("returns basename as label when no timestamp found", function()
        local label, ts = filename.extract_label_and_remainder("random-note.md")
        assert.equals("random-note", label)
        assert.is_nil(ts)
    end)

    it("handles filename with path prefix", function()
        local label, ts = filename.extract_label_and_remainder("/some/path/project-2025-03-15_10-20-30--note.md")
        assert.equals("project", label)
        assert.equals("2025-03-15_10-20-30", ts)
    end)

    it("handles single-word label before timestamp", function()
        local label, ts = filename.extract_label_and_remainder("draft-2025-06-01_08-00-00--note.md")
        assert.equals("draft", label)
        assert.equals("2025-06-01_08-00-00", ts)
    end)
end)

describe("filename.build_filename_for_sort", function()
    it("replaces original label with new label", function()
        local result = filename.build_filename_for_sort(
            "project",
            "old-label-2025-10-08_11-07-15--note.md",
            "2025-10-08_11-07-15",
            ".md",
            "--note"
        )
        assert.equals("project-2025-10-08_11-07-15--note.md", result)
    end)

    it("uses only new label when original has no label", function()
        local result = filename.build_filename_for_sort(
            "project",
            "2025-10-08_09-17-33--note.md",
            "2025-10-08_09-17-33",
            ".md",
            "--note"
        )
        assert.equals("project-2025-10-08_09-17-33--note.md", result)
    end)

    it("preserves original label when no new label provided (nil)", function()
        local result = filename.build_filename_for_sort(
            nil,
            "old-label-2025-10-08_11-07-15--note.md",
            "2025-10-08_11-07-15",
            ".md",
            "--note"
        )
        assert.equals("old-label-2025-10-08_11-07-15--note.md", result)
    end)

    it("preserves original label when no new label provided (empty)", function()
        local result = filename.build_filename_for_sort(
            "",
            "old-label-2025-10-08_11-07-15--note.md",
            "2025-10-08_11-07-15",
            ".md",
            "--note"
        )
        assert.equals("old-label-2025-10-08_11-07-15--note.md", result)
    end)

    it("uses timestamp-only when neither label is present", function()
        local result = filename.build_filename_for_sort(
            nil,
            "2025-10-08_09-17-33--note.md",
            "2025-10-08_09-17-33",
            ".md",
            "--note"
        )
        assert.equals("2025-10-08_09-17-33--note.md", result)
    end)

    it("does not chain labels on repeated sorts", function()
        -- Simulate a file that was already sorted with label "first"
        local result = filename.build_filename_for_sort(
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

describe("filename.ensure_unique", function()
    local tmpdir

    before_each(function()
        tmpdir = vim.fn.tempname() .. "_unique_test"
        vim.fn.mkdir(tmpdir, "p")
    end)

    after_each(function()
        vim.fn.delete(tmpdir, "rf")
    end)

    it("returns original filename when no collision", function()
        local result = filename.ensure_unique(tmpdir, "test--note.md")
        assert.equals("test--note.md", result)
    end)

    it("returns filename with --2 suffix on first collision", function()
        fs.write_file(tmpdir .. "/test--note.md", "")
        local result = filename.ensure_unique(tmpdir, "test--note.md")
        assert.equals("test--note--2.md", result)
    end)

    it("increments counter for multiple collisions", function()
        fs.write_file(tmpdir .. "/test--note.md", "")
        fs.write_file(tmpdir .. "/test--note--2.md", "")
        local result = filename.ensure_unique(tmpdir, "test--note.md")
        assert.equals("test--note--3.md", result)
    end)

    it("preserves file extension", function()
        fs.write_file(tmpdir .. "/test--note.txt", "")
        local result = filename.ensure_unique(tmpdir, "test--note.txt")
        assert.equals("test--note--2.txt", result)
    end)

    it("returns nil when max attempts exceeded", function()
        -- Create file for the base name and the only collision variant
        fs.write_file(tmpdir .. "/test--note.md", "")
        fs.write_file(tmpdir .. "/test--note--2.md", "")
        local result, err = filename.ensure_unique(tmpdir, "test--note.md", 2)
        assert.is_nil(result)
        assert.is_string(err)
        assert.truthy(err:match("Could not generate unique filename"))
    end)
end)
