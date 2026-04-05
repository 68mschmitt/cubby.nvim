--- Tests for cubby.fs — Filesystem utilities, directory listing, and file operations
local fs = require("cubby.fs")

describe("fs.ensure_dir", function()
    local tmpdir

    before_each(function()
        tmpdir = vim.fn.tempname() .. "_fs_test"
    end)

    after_each(function()
        vim.fn.delete(tmpdir, "rf")
    end)

    it("creates directory when it does not exist", function()
        assert.equals(0, vim.fn.isdirectory(tmpdir))
        fs.ensure_dir(tmpdir)
        assert.equals(1, vim.fn.isdirectory(tmpdir))
    end)

    it("is idempotent (no error if directory already exists)", function()
        fs.ensure_dir(tmpdir)
        assert.has_no.errors(function()
            fs.ensure_dir(tmpdir)
        end)
        assert.equals(1, vim.fn.isdirectory(tmpdir))
    end)

    it("creates nested directories", function()
        local nested = tmpdir .. "/a/b/c"
        fs.ensure_dir(nested)
        assert.equals(1, vim.fn.isdirectory(nested))
    end)
end)

describe("fs.file_exists", function()
    local tmpfile

    before_each(function()
        tmpfile = vim.fn.tempname()
    end)

    after_each(function()
        pcall(vim.fn.delete, tmpfile)
    end)

    it("returns true for an existing file", function()
        local f = io.open(tmpfile, "w")
        f:write("test")
        f:close()
        assert.is_true(fs.file_exists(tmpfile))
    end)

    it("returns false for a non-existent file", function()
        assert.is_false(fs.file_exists(tmpfile .. "_nope"))
    end)
end)

describe("fs.dir_exists", function()
    local tmpdir

    before_each(function()
        tmpdir = vim.fn.tempname() .. "_dir_test"
    end)

    after_each(function()
        pcall(vim.fn.delete, tmpdir, "rf")
    end)

    it("returns true for an existing directory", function()
        vim.fn.mkdir(tmpdir, "p")
        assert.is_true(fs.dir_exists(tmpdir))
    end)

    it("returns false for a non-existent directory", function()
        assert.is_false(fs.dir_exists(tmpdir .. "_nope"))
    end)

    it("returns false for a file (not a directory)", function()
        local f = io.open(tmpdir, "w")
        f:write("test")
        f:close()
        assert.is_false(fs.dir_exists(tmpdir))
    end)
end)

describe("fs.write_file", function()
    local tmpfile

    before_each(function()
        tmpfile = vim.fn.tempname()
    end)

    after_each(function()
        pcall(vim.fn.delete, tmpfile)
    end)

    it("writes content to a file and returns true", function()
        local result = fs.write_file(tmpfile, "hello world")
        assert.is_true(result)

        local f = io.open(tmpfile, "r")
        local content = f:read("*a")
        f:close()
        assert.equals("hello world", content)
    end)

    it("writes empty content", function()
        local result = fs.write_file(tmpfile, "")
        assert.is_true(result)

        local f = io.open(tmpfile, "r")
        local content = f:read("*a")
        f:close()
        assert.equals("", content)
    end)

    it("overwrites existing content", function()
        fs.write_file(tmpfile, "first")
        fs.write_file(tmpfile, "second")

        local f = io.open(tmpfile, "r")
        local content = f:read("*a")
        f:close()
        assert.equals("second", content)
    end)

    it("returns false for an invalid path", function()
        local result = fs.write_file("/dev/null/impossible/path/file.txt", "test")
        assert.is_false(result)
    end)
end)

describe("fs.path_join", function()
    it("joins two segments", function()
        assert.equals("/home/user/notes", fs.path_join("/home/user", "notes"))
    end)

    it("handles trailing slash on first segment", function()
        assert.equals("/home/user/notes", fs.path_join("/home/user/", "notes"))
    end)

    it("handles leading slash on second segment", function()
        assert.equals("/home/user/notes", fs.path_join("/home/user", "/notes"))
    end)

    it("handles both trailing and leading slashes", function()
        assert.equals("/home/user/notes", fs.path_join("/home/user/", "/notes"))
    end)

    it("joins multiple segments", function()
        assert.equals("/home/user/notes/inbox", fs.path_join("/home/user", "notes", "inbox"))
    end)

    it("handles empty input", function()
        assert.equals("", fs.path_join())
    end)

    it("handles single segment", function()
        assert.equals("/home/user", fs.path_join("/home/user"))
    end)

    it("strips multiple trailing slashes", function()
        assert.equals("/home/user/notes", fs.path_join("/home/user///", "notes"))
    end)
end)

describe("fs.read_first_nonempty_line", function()
    local tmpfile

    before_each(function()
        tmpfile = vim.fn.tempname()
    end)

    after_each(function()
        pcall(vim.fn.delete, tmpfile)
    end)

    it("returns the first line when it is non-empty", function()
        fs.write_file(tmpfile, "hello world\nsecond line")
        local line, err = fs.read_first_nonempty_line(tmpfile)
        assert.equals("hello world", line)
        assert.is_nil(err)
    end)

    it("skips leading blank lines", function()
        fs.write_file(tmpfile, "\n\n\nactual content\nmore")
        local line, err = fs.read_first_nonempty_line(tmpfile)
        assert.equals("actual content", line)
        assert.is_nil(err)
    end)

    it("skips whitespace-only lines", function()
        fs.write_file(tmpfile, "   \n\t\n  actual content")
        local line, err = fs.read_first_nonempty_line(tmpfile)
        assert.equals("actual content", line)
        assert.is_nil(err)
    end)

    it("trims leading and trailing whitespace from the result", function()
        fs.write_file(tmpfile, "   padded line   \nsecond")
        local line, err = fs.read_first_nonempty_line(tmpfile)
        assert.equals("padded line", line)
        assert.is_nil(err)
    end)

    it("returns nil for an empty file", function()
        fs.write_file(tmpfile, "")
        local line, err = fs.read_first_nonempty_line(tmpfile)
        assert.is_nil(line)
        assert.is_nil(err)
    end)

    it("returns nil for a whitespace-only file", function()
        fs.write_file(tmpfile, "\n\n   \n\t\n")
        local line, err = fs.read_first_nonempty_line(tmpfile)
        assert.is_nil(line)
        assert.is_nil(err)
    end)

    it("returns error string for non-existent file", function()
        local line, err = fs.read_first_nonempty_line(tmpfile .. "_nonexistent")
        assert.is_nil(line)
        assert.is_not_nil(err)
    end)

    it("handles markdown header as first line", function()
        fs.write_file(tmpfile, "# My Note Title\nSome content")
        local line, err = fs.read_first_nonempty_line(tmpfile)
        assert.equals("# My Note Title", line)
        assert.is_nil(err)
    end)
end)

describe("fs.is_excluded_dir", function()
    it("returns true for excluded directory", function()
        assert.is_true(fs.is_excluded_dir(".git", { ".git", ".obsidian" }))
    end)

    it("returns true for another excluded directory", function()
        assert.is_true(fs.is_excluded_dir(".obsidian", { ".git", ".obsidian" }))
    end)

    it("returns false for non-excluded directory", function()
        assert.is_false(fs.is_excluded_dir("notes", { ".git", ".obsidian" }))
    end)

    it("returns false with empty exclude list", function()
        assert.is_false(fs.is_excluded_dir("anything", {}))
    end)
end)

describe("fs.list_subdirs", function()
    local tmpdir

    before_each(function()
        tmpdir = vim.fn.tempname() .. "_dir_list_test"
        vim.fn.mkdir(tmpdir, "p")
        vim.fn.mkdir(tmpdir .. "/alpha", "p")
        vim.fn.mkdir(tmpdir .. "/beta", "p")
        vim.fn.mkdir(tmpdir .. "/gamma", "p")
        vim.fn.mkdir(tmpdir .. "/.git", "p")
        -- Create a file (should not be listed)
        local f = io.open(tmpdir .. "/file.txt", "w")
        f:write("test")
        f:close()
    end)

    after_each(function()
        vim.fn.delete(tmpdir, "rf")
    end)

    it("lists all subdirectories", function()
        local subdirs = fs.list_subdirs(tmpdir, {})
        assert.equals(4, #subdirs) -- alpha, beta, gamma, .git
    end)

    it("excludes specified directories", function()
        local subdirs = fs.list_subdirs(tmpdir, { ".git" })
        assert.equals(3, #subdirs)
        for _, d in ipairs(subdirs) do
            assert.is_not.equals(".git", d)
        end
    end)

    it("returns sorted results", function()
        local subdirs = fs.list_subdirs(tmpdir, { ".git" })
        assert.equals("alpha", subdirs[1])
        assert.equals("beta", subdirs[2])
        assert.equals("gamma", subdirs[3])
    end)

    it("does not include files", function()
        local subdirs = fs.list_subdirs(tmpdir, {})
        for _, d in ipairs(subdirs) do
            assert.is_not.equals("file.txt", d)
        end
    end)

    it("returns empty table for non-existent path", function()
        local subdirs = fs.list_subdirs(tmpdir .. "/nonexistent", {})
        assert.is_table(subdirs)
        assert.equals(0, #subdirs)
    end)
end)

describe("fs.check_move_permissions", function()
    local tmpdir, source

    before_each(function()
        tmpdir = vim.fn.tempname() .. "_move_perm_test"
        vim.fn.mkdir(tmpdir, "p")
        source = tmpdir .. "/source.md"
        fs.write_file(source, "test content")
    end)

    after_each(function()
        vim.fn.delete(tmpdir, "rf")
    end)

    it("returns true for valid source and destination", function()
        local dest = tmpdir .. "/dest.md"
        local ok, err = fs.check_move_permissions(source, dest)
        assert.is_true(ok)
        assert.is_nil(err)
    end)

    it("returns false when source file does not exist", function()
        local ok, err = fs.check_move_permissions(tmpdir .. "/nonexistent.md", tmpdir .. "/dest.md")
        assert.is_false(ok)
        assert.is_string(err)
    end)
end)

describe("fs.move_file", function()
    local tmpdir

    before_each(function()
        tmpdir = vim.fn.tempname() .. "_move_test"
        vim.fn.mkdir(tmpdir, "p")
    end)

    after_each(function()
        vim.fn.delete(tmpdir, "rf")
    end)

    it("moves a file to a new location", function()
        local source = tmpdir .. "/source.md"
        local dest = tmpdir .. "/dest.md"
        fs.write_file(source, "hello world")

        local ok, err = fs.move_file(source, dest)
        assert.is_true(ok)
        assert.is_nil(err)

        -- Source should be gone
        assert.is_false(fs.file_exists(source))

        -- Dest should exist with correct content
        assert.is_true(fs.file_exists(dest))
        local f = io.open(dest, "r")
        local content = f:read("*a")
        f:close()
        assert.equals("hello world", content)
    end)

    it("creates destination directory if it does not exist", function()
        local source = tmpdir .. "/source.md"
        local dest = tmpdir .. "/subdir/dest.md"
        fs.write_file(source, "content")

        local ok, err = fs.move_file(source, dest)
        assert.is_true(ok)
        assert.is_nil(err)
        assert.is_true(fs.file_exists(dest))
    end)

    it("moves a file into a different subdirectory", function()
        local src_dir = tmpdir .. "/inbox"
        local dest_dir = tmpdir .. "/sorted"
        vim.fn.mkdir(src_dir, "p")
        vim.fn.mkdir(dest_dir, "p")

        local source = src_dir .. "/note.md"
        local dest = dest_dir .. "/note.md"
        fs.write_file(source, "note content")

        local ok, err = fs.move_file(source, dest)
        assert.is_true(ok)
        assert.is_nil(err)
        assert.is_false(fs.file_exists(source))
        assert.is_true(fs.file_exists(dest))
    end)

    it("preserves file content after move", function()
        local content = "Line 1\nLine 2\nLine 3\n"
        local source = tmpdir .. "/multi.md"
        local dest = tmpdir .. "/moved.md"
        fs.write_file(source, content)

        fs.move_file(source, dest)

        local f = io.open(dest, "r")
        local read_content = f:read("*a")
        f:close()
        assert.equals(content, read_content)
    end)
end)

describe("fs.is_cross_filesystem", function()
    local tmpdir

    before_each(function()
        tmpdir = vim.fn.tempname() .. "_xfs_test"
        vim.fn.mkdir(tmpdir, "p")
    end)

    after_each(function()
        vim.fn.delete(tmpdir, "rf")
    end)

    it("returns false for same filesystem", function()
        local source = tmpdir .. "/a.md"
        fs.write_file(source, "test")
        local result = fs.is_cross_filesystem(source, tmpdir .. "/b.md")
        assert.is_false(result)
    end)

    it("returns false when source does not exist", function()
        local result = fs.is_cross_filesystem(tmpdir .. "/nonexistent", tmpdir .. "/b.md")
        assert.is_false(result)
    end)
end)
