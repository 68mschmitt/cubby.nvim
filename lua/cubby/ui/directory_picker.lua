---@class cubby.ui.directory_picker
local M = {}

---Strip trailing slashes from a path.
---@param path string
---@return string
local function normalize_path(path)
    path = path:gsub("/+$", "")
    return path
end

---Compute a display-friendly relative path.
---@param base_dir string
---@param current_path string
---@return string
local function get_relative_path(base_dir, current_path)
    base_dir = normalize_path(base_dir)
    current_path = normalize_path(current_path)

    if current_path == base_dir then
        return "/"
    end

    local relative = current_path:gsub("^" .. vim.pesc(base_dir), "")
    return relative:gsub("^/", "")
end

---Sanitize user input for use as a directory name.
---@param name string? Raw input
---@return string? sanitized Sanitized name, or nil if invalid
local function sanitize_directory_name(name)
    if not name or name == "" then
        return nil
    end

    -- Remove path traversal components
    name = name:gsub("%.%.", "")
    -- Remove leading/trailing slashes
    name = name:gsub("^/+", "")
    name = name:gsub("/+$", "")
    -- Replace spaces with hyphens
    name = name:gsub("%s+", "-")
    -- Remove characters unsafe for directory names
    name = name:gsub("[^%w%-_./]", "")
    -- Collapse multiple hyphens or dots
    name = name:gsub("%-+", "-")
    name = name:gsub("%.+", ".")
    -- Remove leading/trailing hyphens and dots
    name = name:gsub("^[%-%.]+", "")
    name = name:gsub("[%-%.]+$", "")

    if name == "" then
        return nil
    end

    return name
end

---Show an interactive directory picker for choosing a destination.
---@param base_dir string Root directory (cannot navigate above this)
---@param current_path string Current directory being browsed
---@param exclude_dirs string[] Directories to exclude from listing
---@param callback fun(dir: string) Called with the chosen directory
function M.show_directory_picker(base_dir, current_path, exclude_dirs, callback)
    local directory = require("cubby.core.directory")

    current_path = current_path or base_dir
    current_path = normalize_path(current_path)
    base_dir = normalize_path(base_dir)

    local subdirs = directory.list_subdirs(current_path, exclude_dirs)
    local items = M.build_picker_items(base_dir, current_path, subdirs)

    local relative_path = get_relative_path(base_dir, current_path)
    local prompt = "Select destination [" .. relative_path .. "]"

    vim.ui.select(items, { prompt = prompt }, function(choice)
        if not choice then
            return
        end

        M.handle_picker_selection(choice, base_dir, current_path, exclude_dirs, callback)
    end)
end

---Build the list of items for the directory picker.
---@param base_dir string Root directory
---@param current_path string Current directory
---@param subdirs string[] Subdirectory names
---@return string[] items
function M.build_picker_items(base_dir, current_path, subdirs)
    local items = {}

    for _, subdir in ipairs(subdirs) do
        table.insert(items, subdir)
    end

    table.insert(items, "✓ Drop Here")
    table.insert(items, "+ Create New")

    if normalize_path(current_path) ~= normalize_path(base_dir) then
        table.insert(items, "← Go Back")
    end

    return items
end

---Handle a user's selection from the directory picker.
---@param choice string The selected item
---@param base_dir string Root directory
---@param current_path string Current directory
---@param exclude_dirs string[] Directories to exclude
---@param callback fun(dir: string) Called with the chosen directory
function M.handle_picker_selection(choice, base_dir, current_path, exclude_dirs, callback)
    local fs = require("cubby.core.fs")

    if choice == "← Go Back" then
        local parent = vim.fn.fnamemodify(current_path, ":h")
        M.show_directory_picker(base_dir, parent, exclude_dirs, callback)
    elseif choice == "✓ Drop Here" then
        callback(current_path)
    elseif choice == "+ Create New" then
        M.create_new_directory(current_path, base_dir, exclude_dirs, callback)
    else
        local next_path = fs.path_join(current_path, choice)
        M.show_directory_picker(base_dir, next_path, exclude_dirs, callback)
    end
end

---Prompt for and create a new directory, then continue browsing.
---@param parent_path string Parent directory for the new directory
---@param base_dir string Root directory
---@param exclude_dirs string[] Directories to exclude
---@param callback fun(dir: string) Called with the chosen directory
function M.create_new_directory(parent_path, base_dir, exclude_dirs, callback)
    local fs = require("cubby.core.fs")
    local notify = require("cubby.ui.notify")

    vim.ui.input({ prompt = "New directory name: " }, function(name)
        if not name or name == "" then
            M.show_directory_picker(base_dir, parent_path, exclude_dirs, callback)
            return
        end

        local sanitized = sanitize_directory_name(name)
        if not sanitized then
            notify.warn("Invalid directory name. Try again.")
            M.create_new_directory(parent_path, base_dir, exclude_dirs, callback)
            return
        end

        local new_path = fs.path_join(parent_path, sanitized)
        fs.ensure_dir(new_path)

        M.show_directory_picker(base_dir, new_path, exclude_dirs, callback)
    end)
end

return M
