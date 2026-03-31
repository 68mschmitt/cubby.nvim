---@class cubby.recent
local M = {}

---@class cubby.RecentEntry
---@field dir string Directory path
---@field timestamp integer Unix epoch of last use

---@return string
local function get_state_file_path()
    local config = require("cubby.config").get()
    return config.recent_state_file or (vim.fn.stdpath("state") .. "/cubby-mru.json")
end

---Load recent directory data from the state file.
---@return { recent: cubby.RecentEntry[] }
function M.load_recent()
    local state_file = get_state_file_path()

    if vim.fn.filereadable(state_file) == 0 then
        return { recent = {} }
    end

    local file = io.open(state_file, "r")
    if not file then
        return { recent = {} }
    end

    local content = file:read("*a")
    file:close()

    local success, data = pcall(vim.json.decode, content)
    if not success or type(data) ~= "table" then
        return { recent = {} }
    end

    return data
end

---Save recent directory data to the state file.
---@param data { recent: cubby.RecentEntry[] }
---@return boolean success
function M.save_recent(data)
    local state_file = get_state_file_path()
    local state_dir = vim.fn.fnamemodify(state_file, ":h")

    if vim.fn.isdirectory(state_dir) == 0 then
        vim.fn.mkdir(state_dir, "p")
    end

    local json = vim.json.encode(data)

    local file = io.open(state_file, "w")
    if not file then
        return false
    end

    file:write(json)
    file:close()
    return true
end

---Record a directory as recently used, bumping it to the front.
---@param dir string Directory path to record
function M.add_recent_entry(dir)
    local config = require("cubby.config").get()

    if not config.enable_recent_dirs then
        return
    end

    local data = M.load_recent()
    local recent = data.recent or {}

    local existing_idx = nil
    for i, entry in ipairs(recent) do
        if entry.dir == dir then
            existing_idx = i
            break
        end
    end

    if existing_idx then
        table.remove(recent, existing_idx)
    end

    table.insert(recent, 1, {
        dir = dir,
        timestamp = os.time(),
    })

    while #recent > config.max_recent_dirs do
        table.remove(recent)
    end

    data.recent = recent
    M.save_recent(data)
end

---Get the list of recent directories, filtering out those that no longer exist.
---Returns copies of entries to avoid mutating the loaded data.
---@return cubby.RecentEntry[]
function M.get_recent_list()
    local config = require("cubby.config").get()

    if not config.enable_recent_dirs then
        return {}
    end

    local data = M.load_recent()
    local recent = data.recent or {}

    local valid_entries = {}
    for _, entry in ipairs(recent) do
        local expanded_dir = vim.fn.expand(entry.dir)
        if vim.fn.isdirectory(expanded_dir) == 1 then
            table.insert(valid_entries, {
                dir = expanded_dir,
                timestamp = entry.timestamp,
            })
        end
    end

    return valid_entries
end

---Format a recent entry for display in the picker.
---@param entry cubby.RecentEntry
---@param base_dir string Base directory for computing relative paths
---@return string display Formatted string like "projects/miata (2 hours ago)"
function M.format_recent_display(entry, base_dir)
    local time = require("cubby.core.time")
    local relative = entry.dir:gsub("^" .. vim.pesc(base_dir) .. "/", "")
    local time_ago = time.format_relative_time(entry.timestamp)
    return string.format("%s (%s)", relative, time_ago)
end

return M
