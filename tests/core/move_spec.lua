--- Tests for cubby.core.move — File move, copy-delete, and permission checks
local move = require("cubby.core.move")
local fs = require("cubby.core.fs")

describe("move.check_move_permissions", function()
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
        local ok, err = move.check_move_permissions(source, dest)
        assert.is_true(ok)
        assert.is_nil(err)
    end)

    it("returns false when source file does not exist", function()
        local ok, err = move.check_move_permissions(tmpdir .. "/nonexistent.md", tmpdir .. "/dest.md")
        assert.is_false(ok)
        assert.is_string(err)
    end)
end)

describe("move.move_file", function()
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

        local ok, err = move.move_file(source, dest)
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

        local ok, err = move.move_file(source, dest)
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

        local ok, err = move.move_file(source, dest)
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

        move.move_file(source, dest)

        local f = io.open(dest, "r")
        local read_content = f:read("*a")
        f:close()
        assert.equals(content, read_content)
    end)
end)

describe("move.is_cross_filesystem", function()
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
        local result = move.is_cross_filesystem(source, tmpdir .. "/b.md")
        assert.is_false(result)
    end)

    it("returns false when source does not exist", function()
        local result = move.is_cross_filesystem(tmpdir .. "/nonexistent", tmpdir .. "/b.md")
        assert.is_false(result)
    end)
end)
