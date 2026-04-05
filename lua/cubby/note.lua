---@class cubby.note
local M = {}

local fs = require("cubby.fs")
local naming = require("cubby.naming")
local ui = require("cubby.ui")
local config = require("cubby.config")

---@class cubby.InboxNote
---@field filepath string Full file path
---@field filename string Filename only
---@field timestamp integer Unix epoch timestamp
---@field relative_time string Human-readable relative time
---@field preview string|nil First non-empty line of content, truncated
---@field display_text string Formatted display string

---Create a blank note in the specified inbox directory.
---@param inbox_dir string Directory to create the note in
---@return string? path Full path to the created note, or nil on failure
function M.create_blank_note(inbox_dir)
    local cfg = config.get()

    local ok, err = fs.ensure_dir(inbox_dir)
    if not ok then
        ui.warn("Failed to create inbox directory: " .. tostring(err))
        return nil
    end

    local timestamp = naming.now_stamp(cfg.timestamp_fmt)
    local base_filename = timestamp .. cfg.trailing_marker .. cfg.file_ext
    local unique_filename, unique_err = naming.ensure_unique(inbox_dir, base_filename)

    if not unique_filename then
        ui.warn("Failed to create note: " .. tostring(unique_err))
        return nil
    end

    local full_path = fs.path_join(inbox_dir, unique_filename)

    if cfg.auto_save_new_note then
        local success = fs.write_file(full_path, "")

        if not success then
            ui.warn("Failed to create note: " .. full_path)
            return nil
        end
    end

    if cfg.open_after_create then
        vim.cmd.edit(full_path)
        if not cfg.auto_save_new_note then
            vim.bo.filetype = "markdown"
        end
    end

    ui.info("Created note: " .. full_path)

    return full_path
end

---Create a note with the given parameters in the specified directory.
---@param dest_dir string Destination directory
---@param label string? Optional descriptive label
---@return string? path Full path to the created note, or nil on failure
function M.create_with_params(dest_dir, label)
    local cfg = config.get()
    local timestamp = naming.now_stamp(cfg.timestamp_fmt)
    local new_filename = naming.build_sorted_filename(label, timestamp, cfg.file_ext, cfg.trailing_marker)
    local unique_filename, unique_err = naming.ensure_unique(dest_dir, new_filename)

    if not unique_filename then
        ui.warn("Failed to create note: " .. tostring(unique_err))
        return nil
    end

    local full_path = fs.path_join(dest_dir, unique_filename)

    if cfg.auto_save_new_note then
        local ok, err = fs.ensure_dir(dest_dir)
        if not ok then
            ui.warn("Failed to create directory: " .. tostring(err))
            return nil
        end
        local success = fs.write_file(full_path, "")

        if not success then
            ui.warn("Failed to create note: " .. full_path)
            return nil
        end
    end

    if cfg.open_after_create then
        vim.cmd.edit(full_path)
        if not cfg.auto_save_new_note then
            vim.bo.filetype = "markdown"
        end
    end

    local relative = full_path:gsub("^" .. vim.pesc(cfg.base_dir) .. "/", "")
    ui.info("Created → " .. relative)

    return full_path
end

---Run the full create-at workflow with directory picker and label prompt.
local function do_full_create_workflow()
    local cfg = config.get()

    ui.show_directory_picker(cfg.base_dir, cfg.base_dir, cfg.exclude_dirs, function(dest_dir)
        ui.prompt_for_label(function(label)
            M.create_with_params(dest_dir, label)
        end)
    end)
end

---Entry point for creating a note at a chosen location.
function M.create_note_at()
    do_full_create_workflow()
end

---Scan the inbox directory for note files.
---@param inbox_dir string Inbox directory path
---@param file_ext string Expected file extension
---@param allow_non_md boolean Whether to include non-markdown files
---@return string[] filepaths List of full file paths
local function scan_inbox_files(inbox_dir, file_ext, allow_non_md)
    if not fs.dir_exists(inbox_dir) then
        return {}
    end

    local files = {}
    local handle = vim.uv.fs_scandir(inbox_dir)
    if not handle then
        return files
    end

    while true do
        local name, type = vim.uv.fs_scandir_next(handle)
        if not name then
            break
        end

        if type == "file" then
            if allow_non_md or vim.endswith(name, file_ext) then
                table.insert(files, fs.path_join(inbox_dir, name))
            end
        end
    end

    return files
end

-- 60 chars keeps the picker scannable across terminal widths
local MAX_PREVIEW_LEN = 60

---Truncate a preview line to fit in the picker display.
---@param line string|nil Raw first line from file
---@return string|nil preview Truncated preview, or nil if no content
local function format_preview(line)
    if not line or line == "" then
        return nil
    end
    if #line > MAX_PREVIEW_LEN then
        return line:sub(1, MAX_PREVIEW_LEN - 1) .. "…"
    end
    return line
end

---Extract display metadata from a note file path.
---@param filepath string Full file path
---@return cubby.InboxNote
local function extract_note_metadata(filepath)
    local fname = vim.fn.fnamemodify(filepath, ":t")

    local timestamp_str = naming.extract_timestamp_from_filename(fname)
    local unix_timestamp = naming.parse_to_unix(timestamp_str)

    if not unix_timestamp then
        local stat = vim.uv.fs_stat(filepath)
        if stat then
            unix_timestamp = stat.mtime.sec
        else
            unix_timestamp = os.time()
        end
    end

    local relative_time = naming.format_relative_time(unix_timestamp)

    local raw_preview, _ = fs.read_first_nonempty_line(filepath)
    local preview = format_preview(raw_preview)

    local display_text
    if preview then
        display_text = string.format("[%s] %s — %s", relative_time, fname, preview)
    else
        display_text = string.format("[%s] %s", relative_time, fname)
    end

    return {
        filepath = filepath,
        filename = fname,
        timestamp = unix_timestamp,
        relative_time = relative_time,
        preview = preview,
        display_text = display_text,
    }
end

---Load and enrich all inbox notes with metadata.
---@param inbox_dir string Inbox directory path
---@param file_ext string Expected file extension
---@param allow_non_md boolean Whether to include non-markdown files
---@return cubby.InboxNote[]
local function get_inbox_notes(inbox_dir, file_ext, allow_non_md)
    local filepaths = scan_inbox_files(inbox_dir, file_ext, allow_non_md)
    local notes = {}

    for _, filepath in ipairs(filepaths) do
        local metadata = extract_note_metadata(filepath)
        table.insert(notes, metadata)
    end

    return notes
end

---Sort notes by timestamp.
---@param notes cubby.InboxNote[]
---@param sort_order string? "newest" (default) or "oldest"
---@return cubby.InboxNote[]
local function sort_notes(notes, sort_order)
    sort_order = sort_order or "newest"

    table.sort(notes, function(a, b)
        if sort_order == "oldest" then
            return a.timestamp < b.timestamp
        end
        return a.timestamp > b.timestamp
    end)

    return notes
end

---Open a selected note in the current window.
---@param note cubby.InboxNote?
local function handle_note_selection(note)
    if not note or not note.filepath then
        ui.error("Invalid note selection")
        return
    end

    if not fs.file_exists(note.filepath) then
        ui.error("Note file not found: " .. note.filename)
        return
    end

    vim.cmd.edit(note.filepath)
end

---Display the inbox picker for note selection.
---@param notes cubby.InboxNote[]
local function show_inbox_picker(notes)
    if #notes == 0 then
        ui.info("Inbox is empty! Great work!")
        return
    end

    local items = {}
    for _, note in ipairs(notes) do
        table.insert(items, note.display_text)
    end

    vim.ui.select(items, {
        prompt = string.format("Inbox (%d note%s)", #notes, #notes == 1 and "" or "s"),
    }, function(choice, idx)
        if not choice then
            return
        end
        handle_note_selection(notes[idx])
    end)
end

---List inbox notes in a picker with relative timestamps.
---@param args { sort: string? }? Optional arguments
function M.list_inbox(args)
    args = args or {}

    local cfg = config.get()

    local inbox_dir = cfg.inbox_dir

    if not fs.dir_exists(inbox_dir) then
        ui.error(string.format("Inbox directory not found: %s\nCreate it with: mkdir -p %s", inbox_dir, inbox_dir))
        return
    end

    local success, notes = pcall(get_inbox_notes, inbox_dir, cfg.file_ext, cfg.allow_non_md)
    if not success then
        ui.error("Error loading inbox notes: " .. tostring(notes))
        return
    end

    local sort_order = args.sort or "newest"
    notes = sort_notes(notes, sort_order)

    show_inbox_picker(notes)
end

---Validate that the current buffer is a sortable note.
---@return boolean valid
---@return string file_or_error File path on success, error message on failure
function M.validate_current_buffer()
    local current_file = vim.api.nvim_buf_get_name(0)

    if current_file == "" then
        return false, "Current buffer has no file"
    end

    local cfg = config.get()
    if not cfg.allow_non_md and not current_file:match("%.md$") then
        return false, "Current file is not a markdown file"
    end

    if vim.fn.filereadable(current_file) == 0 then
        return false, "Current file does not exist on disk"
    end

    return true, current_file
end

---Execute the file move and buffer switch for a sort operation.
---@param current_path string Current file path
---@param dest_dir string Destination directory
---@param label string? Optional new label (replaces existing label)
---@return boolean success
---@return string? new_path Destination path on success, or nil
function M.execute_sort(current_path, dest_dir, label)
    local cfg = config.get()

    local extracted_timestamp = naming.preserve_or_fallback_timestamp(current_path, current_path, cfg.timestamp_fmt)

    local new_filename =
        naming.build_filename_for_sort(label, current_path, extracted_timestamp, cfg.file_ext, cfg.trailing_marker)

    local unique_filename, unique_err = naming.ensure_unique(dest_dir, new_filename)

    if not unique_filename then
        ui.warn("Failed to sort note: " .. tostring(unique_err))
        return false, nil
    end

    local dest_path = fs.path_join(dest_dir, unique_filename)

    local original_bufnr = vim.api.nvim_get_current_buf()

    if vim.bo.modified then
        vim.cmd("write")
    end

    local success, err = fs.move_file(current_path, dest_path)

    if not success then
        ui.warn("Failed to move file: " .. tostring(err))
        return false, nil
    end

    vim.cmd.edit(dest_path)

    -- WORKAROUND: Some plugins (e.g., markview.nvim) start debounce timers on
    -- cursor/text autocmd events from the OLD buffer before the sort runs.
    -- Firing CursorMoved on the new buffer flushes those stale timers so the
    -- new buffer renders correctly. Remove this if the upstream plugin fixes
    -- its debounce handling, or if it causes problems with other plugins.
    -- See: https://github.com/OXY2DEV/markview.nvim
    vim.api.nvim_exec_autocmds("CursorMoved", { buffer = 0 })

    if vim.api.nvim_buf_is_valid(original_bufnr) then
        pcall(vim.api.nvim_buf_delete, original_bufnr, { force = true })
    end

    return true, dest_path
end

---Handle post-sort notifications.
---@param old_path string Original file path (unused, kept for context)
---@param new_path string New file path after sort
---@param dest_dir string Destination directory
function M.handle_sort_completion(old_path, new_path, dest_dir)
    local cfg = config.get()

    local relative = new_path:gsub("^" .. vim.pesc(cfg.base_dir) .. "/", "")
    ui.info("Sorted → " .. relative)
end

---Run the full sort workflow with directory picker and label prompt.
---@param current_file string Path to the file being sorted
local function do_full_sort_workflow(current_file)
    local cfg = config.get()

    ui.show_directory_picker(cfg.base_dir, cfg.base_dir, cfg.exclude_dirs, function(dest_dir)
        ui.prompt_for_label(function(label)
            local success, new_path = M.execute_sort(current_file, dest_dir, label)

            if success then
                M.handle_sort_completion(current_file, new_path, dest_dir)
            end
        end)
    end)
end

---Entry point for sorting the current note.
---Validates the buffer, then shows directory picker.
function M.sort_current_note()
    local valid, current_file = M.validate_current_buffer()

    if not valid then
        ui.warn(current_file)
        return
    end

    do_full_sort_workflow(current_file)
end

return M
