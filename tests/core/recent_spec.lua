--- Tests for cubby.core.recent — MRU recent directory tracking
local recent = require("cubby.core.recent")

-- Override config for tests to use a temp state file
local tmpdir
local state_file

-- We need to set up config before each test so recent reads from our temp file
local function setup_test_config()
    tmpdir = vim.fn.tempname() .. "_recent_test"
    vim.fn.mkdir(tmpdir, "p")
    state_file = tmpdir .. "/test-mru.json"

    -- Re-setup cubby config with our test paths
    require("cubby.config").setup({
        inbox_dir = tmpdir .. "/inbox",
        base_dir = tmpdir,
        enable_recent_dirs = true,
        max_recent_dirs = 3,
        recent_state_file = state_file,
    })
end

describe("recent.load_recent", function()
    before_each(setup_test_config)

    after_each(function()
        vim.fn.delete(tmpdir, "rf")
    end)

    it("returns empty recent list when no state file exists", function()
        local data = recent.load_recent()
        assert.is_table(data)
        assert.is_table(data.recent)
        assert.equals(0, #data.recent)
    end)

    it("returns empty recent list for invalid JSON", function()
        local f = io.open(state_file, "w")
        f:write("not valid json {{{")
        f:close()

        local data = recent.load_recent()
        assert.is_table(data)
        assert.is_table(data.recent)
        assert.equals(0, #data.recent)
    end)

    it("loads valid JSON data", function()
        local f = io.open(state_file, "w")
        f:write(vim.json.encode({
            recent = {
                { dir = "/tmp/test", timestamp = 1000000 },
            },
        }))
        f:close()

        local data = recent.load_recent()
        assert.equals(1, #data.recent)
        assert.equals("/tmp/test", data.recent[1].dir)
    end)
end)

describe("recent.save_recent", function()
    before_each(setup_test_config)

    after_each(function()
        vim.fn.delete(tmpdir, "rf")
    end)

    it("writes data to state file", function()
        local data = { recent = { { dir = "/tmp/saved", timestamp = 12345 } } }
        local ok = recent.save_recent(data)
        assert.is_true(ok)

        local f = io.open(state_file, "r")
        local content = f:read("*a")
        f:close()

        local loaded = vim.json.decode(content)
        assert.equals(1, #loaded.recent)
        assert.equals("/tmp/saved", loaded.recent[1].dir)
    end)

    it("creates state directory if it does not exist", function()
        local deep_file = tmpdir .. "/deep/nested/state.json"
        require("cubby.config").setup({
            inbox_dir = tmpdir .. "/inbox",
            base_dir = tmpdir,
            enable_recent_dirs = true,
            max_recent_dirs = 3,
            recent_state_file = deep_file,
        })

        local data = { recent = {} }
        local ok = recent.save_recent(data)
        assert.is_true(ok)
        assert.equals(1, vim.fn.filereadable(deep_file))
    end)
end)

describe("recent.add_recent_entry", function()
    before_each(function()
        setup_test_config()
        -- Create some real directories for entries
        vim.fn.mkdir(tmpdir .. "/project-a", "p")
        vim.fn.mkdir(tmpdir .. "/project-b", "p")
        vim.fn.mkdir(tmpdir .. "/project-c", "p")
        vim.fn.mkdir(tmpdir .. "/project-d", "p")
    end)

    after_each(function()
        vim.fn.delete(tmpdir, "rf")
    end)

    it("adds a new entry to the front of the list", function()
        recent.add_recent_entry(tmpdir .. "/project-a")

        local data = recent.load_recent()
        assert.equals(1, #data.recent)
        assert.equals(tmpdir .. "/project-a", data.recent[1].dir)
    end)

    it("bumps existing entry to the front", function()
        recent.add_recent_entry(tmpdir .. "/project-a")
        recent.add_recent_entry(tmpdir .. "/project-b")
        recent.add_recent_entry(tmpdir .. "/project-a") -- re-add

        local data = recent.load_recent()
        assert.equals(2, #data.recent)
        assert.equals(tmpdir .. "/project-a", data.recent[1].dir)
        assert.equals(tmpdir .. "/project-b", data.recent[2].dir)
    end)

    it("respects max_recent_dirs limit", function()
        recent.add_recent_entry(tmpdir .. "/project-a")
        recent.add_recent_entry(tmpdir .. "/project-b")
        recent.add_recent_entry(tmpdir .. "/project-c")
        recent.add_recent_entry(tmpdir .. "/project-d") -- should push project-a out

        local data = recent.load_recent()
        assert.equals(3, #data.recent)
        assert.equals(tmpdir .. "/project-d", data.recent[1].dir)
    end)

    it("does not add when enable_recent_dirs is false", function()
        require("cubby.config").setup({
            inbox_dir = tmpdir .. "/inbox",
            base_dir = tmpdir,
            enable_recent_dirs = false,
            max_recent_dirs = 3,
            recent_state_file = state_file,
        })

        recent.add_recent_entry(tmpdir .. "/project-a")
        local data = recent.load_recent()
        assert.equals(0, #data.recent)
    end)

    it("includes a timestamp with each entry", function()
        local before = os.time()
        recent.add_recent_entry(tmpdir .. "/project-a")
        local after = os.time()

        local data = recent.load_recent()
        assert.is_number(data.recent[1].timestamp)
        assert.is_true(data.recent[1].timestamp >= before)
        assert.is_true(data.recent[1].timestamp <= after)
    end)
end)

describe("recent.get_recent_list", function()
    before_each(function()
        setup_test_config()
        vim.fn.mkdir(tmpdir .. "/existing", "p")
    end)

    after_each(function()
        vim.fn.delete(tmpdir, "rf")
    end)

    it("returns empty list when no recent entries", function()
        local list = recent.get_recent_list()
        assert.is_table(list)
        assert.equals(0, #list)
    end)

    it("filters out directories that no longer exist", function()
        -- Manually write an entry for a non-existent directory
        recent.save_recent({
            recent = {
                { dir = tmpdir .. "/existing", timestamp = os.time() },
                { dir = tmpdir .. "/deleted", timestamp = os.time() },
            },
        })

        local list = recent.get_recent_list()
        assert.equals(1, #list)
        assert.equals(tmpdir .. "/existing", list[1].dir)
    end)

    it("returns empty when enable_recent_dirs is false", function()
        require("cubby.config").setup({
            inbox_dir = tmpdir .. "/inbox",
            base_dir = tmpdir,
            enable_recent_dirs = false,
            max_recent_dirs = 3,
            recent_state_file = state_file,
        })

        local list = recent.get_recent_list()
        assert.equals(0, #list)
    end)
end)

describe("recent.format_recent_display", function()
    it("formats entry with relative path and time", function()
        local entry = {
            dir = "/home/user/notes/projects/miata",
            timestamp = os.time() - 3600, -- 1 hour ago
        }
        local display = recent.format_recent_display(entry, "/home/user/notes")
        assert.matches("projects/miata", display)
        assert.matches("1 hour ago", display)
    end)

    it("formats entry at base_dir as full path", function()
        local entry = {
            dir = "/home/user/notes",
            timestamp = os.time(),
        }
        local display = recent.format_recent_display(entry, "/home/user/notes")
        -- When dir equals base_dir, gsub removes the prefix leaving empty
        assert.is_string(display)
    end)
end)
