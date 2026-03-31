local M = {}

local function scan_inbox_files(inbox_dir, file_ext, allow_non_md)
    local fs = require("cubby.core.fs")

    if not fs.dir_exists(inbox_dir) then
        return {}
    end

    local files = {}
    local handle = vim.loop.fs_scandir(inbox_dir)
    if not handle then
        return files
    end

    while true do
        local name, type = vim.loop.fs_scandir_next(handle)
        if not name then
            break
        end

        if type == "file" then
            if allow_non_md or vim.endswith(name, file_ext) then
                table.insert(files, inbox_dir .. "/" .. name)
            end
        end
    end

    return files
end

local function extract_note_metadata(filepath)
    local timestamp_mod = require("cubby.core.timestamp")
    local time = require("cubby.core.time")

    local fname = vim.fn.fnamemodify(filepath, ":t")

    local timestamp_str = timestamp_mod.extract_timestamp_from_filename(fname)
    local unix_timestamp = timestamp_mod.parse_to_unix(timestamp_str)

    if not unix_timestamp then
        local stat = vim.loop.fs_stat(filepath)
        if stat then
            unix_timestamp = stat.mtime.sec
        else
            unix_timestamp = os.time()
        end
    end

    local relative_time = time.format_relative_time(unix_timestamp)
    local display_text = string.format("[%s] %s", relative_time, fname)

    return {
        filepath = filepath,
        filename = fname,
        timestamp = unix_timestamp,
        relative_time = relative_time,
        display_text = display_text,
    }
end

local function get_inbox_notes(inbox_dir, file_ext, allow_non_md)
    local filepaths = scan_inbox_files(inbox_dir, file_ext, allow_non_md)
    local notes = {}

    for _, filepath in ipairs(filepaths) do
        local metadata = extract_note_metadata(filepath)
        table.insert(notes, metadata)
    end

    return notes
end

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

local function handle_note_selection(note)
    local notify = require("cubby.ui.notify")
    local fs = require("cubby.core.fs")

    if not note or not note.filepath then
        notify.error("Invalid note selection")
        return
    end

    if not fs.file_exists(note.filepath) then
        notify.error("Note file not found: " .. note.filename)
        return
    end

    vim.cmd.edit(note.filepath)
end

local function show_inbox_picker(notes)
    local notify = require("cubby.ui.notify")

    if #notes == 0 then
        notify.info("Inbox is empty! Great work!")
        return
    end

    local items = {}
    for _, note in ipairs(notes) do
        table.insert(items, note.display_text)
    end

    vim.ui.select(items, {
        prompt = string.format("Inbox (%d note%s)", #notes, #notes == 1 and "" or "s"),
        format_item = function(item)
            return item
        end,
    }, function(choice, idx)
        if not choice then
            return
        end
        handle_note_selection(notes[idx])
    end)
end

function M.list_inbox(args)
    args = args or {}

    local config = require("cubby.config").get()
    local notify = require("cubby.ui.notify")
    local fs = require("cubby.core.fs")

    local inbox_dir = config.inbox_dir

    if not fs.dir_exists(inbox_dir) then
        notify.error(string.format("Inbox directory not found: %s\nCreate it with: mkdir -p %s", inbox_dir, inbox_dir))
        return
    end

    local success, notes = pcall(get_inbox_notes, inbox_dir, config.file_ext, config.allow_non_md)
    if not success then
        notify.error("Error loading inbox notes: " .. tostring(notes))
        return
    end

    local sort_order = args.sort or "newest"
    notes = sort_notes(notes, sort_order)

    show_inbox_picker(notes)
end

return M
