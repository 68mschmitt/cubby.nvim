--- Tests for cubby.core.directory — Directory listing and exclusion
local directory = require("cubby.core.directory")

describe("directory.is_excluded_dir", function()
    it("returns true for excluded directory", function()
        assert.is_true(directory.is_excluded_dir(".git", { ".git", ".obsidian" }))
    end)

    it("returns true for another excluded directory", function()
        assert.is_true(directory.is_excluded_dir(".obsidian", { ".git", ".obsidian" }))
    end)

    it("returns false for non-excluded directory", function()
        assert.is_false(directory.is_excluded_dir("notes", { ".git", ".obsidian" }))
    end)

    it("returns false with empty exclude list", function()
        assert.is_false(directory.is_excluded_dir("anything", {}))
    end)
end)

describe("directory.list_subdirs", function()
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
        local subdirs = directory.list_subdirs(tmpdir, {})
        assert.equals(4, #subdirs) -- alpha, beta, gamma, .git
    end)

    it("excludes specified directories", function()
        local subdirs = directory.list_subdirs(tmpdir, { ".git" })
        assert.equals(3, #subdirs)
        for _, d in ipairs(subdirs) do
            assert.is_not.equals(".git", d)
        end
    end)

    it("returns sorted results", function()
        local subdirs = directory.list_subdirs(tmpdir, { ".git" })
        assert.equals("alpha", subdirs[1])
        assert.equals("beta", subdirs[2])
        assert.equals("gamma", subdirs[3])
    end)

    it("does not include files", function()
        local subdirs = directory.list_subdirs(tmpdir, {})
        for _, d in ipairs(subdirs) do
            assert.is_not.equals("file.txt", d)
        end
    end)

    it("returns empty table for non-existent path", function()
        local subdirs = directory.list_subdirs(tmpdir .. "/nonexistent", {})
        assert.is_table(subdirs)
        assert.equals(0, #subdirs)
    end)
end)

describe("directory.ensure_path_exists", function()
    local tmpdir

    before_each(function()
        tmpdir = vim.fn.tempname() .. "_ensure_test"
    end)

    after_each(function()
        vim.fn.delete(tmpdir, "rf")
    end)

    it("creates directory when it does not exist", function()
        directory.ensure_path_exists(tmpdir)
        assert.equals(1, vim.fn.isdirectory(tmpdir))
    end)

    it("is idempotent", function()
        directory.ensure_path_exists(tmpdir)
        assert.has_no.errors(function()
            directory.ensure_path_exists(tmpdir)
        end)
    end)

    it("creates nested directories", function()
        local nested = tmpdir .. "/deep/nested/path"
        directory.ensure_path_exists(nested)
        assert.equals(1, vim.fn.isdirectory(nested))
    end)
end)
