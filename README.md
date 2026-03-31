# katasync.nvim

A minimal Neovim plugin for quick note creation and organization. Capture thoughts instantly in your inbox, then sort them into a structured hierarchy when ready.

## Features

### Quick Note Creation (`:NewNote`)
- **Single Command**: `:NewNote` creates a blank markdown file instantly
- **Unique Filenames**: Timestamped format `YYYY-MM-DD_HH-MM-SS--note.md`
- **Auto-open**: Immediately opens the new file for editing
- **Collision Handling**: Automatically handles filename conflicts

### Direct Note Creation (`:CreateNote`)
- **Create in Place**: Create notes directly in their final destination
- **Recent Destinations**: Quick access to recently used directories
- **Directory Drill-down**: Interactive navigation to choose location
- **Optional Labeling**: Add descriptive names or skip for timestamp-only filenames
- **Smart Naming**: Format becomes `{label}-{timestamp}--note.md` (or just `{timestamp}--note.md` if no label)

### Inbox Display (`:ListInbox`)
- **Visual Inbox**: Display all unsorted notes in your inbox
- **Relative Timestamps**: See how old each note is ("2 hours ago", "yesterday", etc.)
- **Interactive Picker**: Select notes to open and review
- **Sorting Options**: View notes newest-first or oldest-first
- **Empty Inbox Detection**: Helpful message when inbox is empty

### Note Sorting (`:SortNote`)
- **Recent Destinations**: Quick access to recently used directories
- **Directory Drill-down**: Interactive navigation through your note structure
- **Optional Labeling**: Add descriptive names or skip for timestamp-only filenames
- **Timestamp Preservation**: Keeps original creation timestamp
- **Smart Renaming**: Format becomes `{label}-{timestamp}--note.md` (or just `{timestamp}--note.md` if no label)
- **True Move**: Original file is moved, not copied
- **Cross-filesystem Support**: Works across different filesystems

## Installation

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "68mschmitt/katasync.nvim",
  cmd = { "NewNote", "CreateNote", "SortNote", "ListInbox" },
  keys = {
    { "<leader>nn", "<cmd>NewNote<cr>", desc = "New note (inbox)" },
    { "<leader>nc", "<cmd>CreateNote<cr>", desc = "Create note at location" },
    { "<leader>ns", "<cmd>SortNote<cr>", desc = "Sort/move note" },
    { "<leader>ni", "<cmd>ListInbox<cr>", desc = "List inbox notes" },
  },
  opts = {
    inbox_dir = "~/notes/inbox",
    base_dir = "~/notes",
  },
}
```

### Using [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use {
  '68mschmitt/katasync.nvim',
  config = function()
    require('katasync').setup({
      inbox_dir = '~/notes/inbox',
    })
  end
}
```

## Configuration

```lua
require("katasync").setup({
  inbox_dir = "~/notes/inbox",              -- Directory for new notes
  base_dir = "~/notes",                      -- Base directory for CreateNote and sorting
  file_ext = ".md",                          -- File extension
  timestamp_fmt = "%Y-%m-%d_%H-%M-%S",      -- Timestamp format (see note below)
  open_after_create = true,                  -- Open file after creating
  auto_save_new_note = false,                -- Auto-save new notes to disk (false = manual :w)
  notify = true,                             -- Show notifications
  trailing_marker = "--note",                -- Filename suffix marker
  exclude_dirs = { ".git", ".obsidian" },   -- Directories to exclude from picker
  confirm_on_cross_fs = false,               -- Confirm cross-filesystem moves
  allow_non_md = true,                       -- Allow sorting non-markdown files

  -- Recent Destinations (for CreateNote and SortNote)
  enable_recent_dirs = true,                 -- Enable recent destinations feature
  max_recent_dirs = 5,                       -- Number of recent destinations to remember
  recent_state_file = vim.fn.stdpath("state") .. "/katasync-mru.json",
})
```

### Auto-Save Behavior

- **`auto_save_new_note = false`** (default): File is only created in a buffer. You must save with `:w` to persist it. Closing the buffer without saving leaves no empty file behind.
- **`auto_save_new_note = true`**: File is immediately saved to disk when created. The file exists in your filesystem before you start editing.

### Timestamp Format

The `timestamp_fmt` option controls how timestamps appear in filenames. The default format `%Y-%m-%d_%H-%M-%S` produces timestamps like `2025-10-08_09-17-33`.

**Important:** The plugin's filename parsing depends on the `YYYY-MM-DD_HH-MM-SS` pattern. Changing `timestamp_fmt` will break timestamp extraction from filenames, relative time display in `:ListInbox`, and timestamp preservation during `:SortNote`. Only change this if you understand the consequences.

## Usage

### Commands

- `:NewNote` - Creates a blank markdown file in your inbox
- `:CreateNote` - Create a note directly in a chosen location with optional label
- `:ListInbox` - Display all inbox notes with relative timestamps for easy review
  - `:ListInbox newest` - Sort by newest first (default)
  - `:ListInbox oldest` - Sort by oldest first
- `:SortNote` - Move and rename the current note with interactive directory selection

### Workflows

#### Capture-Then-Sort (Unknown destination)
1. **Capture**: Use `:NewNote` to quickly create a note in your inbox
2. **Edit**: Write your content without worrying about organization
3. **Review**: Use `:ListInbox` to see all unsorted notes with relative timestamps
   - Select a note to open and review
   - See at a glance which notes need attention
4. **Sort**: When ready, use `:SortNote` to:
   - **Quick path**: Select from recent destinations
   - **Full path**: Navigate through your directory structure
   - Choose a destination (or create new directories)
   - Optionally provide a descriptive label (or press Enter to skip)
   - File is automatically moved and renamed

#### Create-In-Place (Known destination)
1. **Create**: Use `:CreateNote` to create a note directly:
   - **Quick path**: Select from recent destinations
   - **Full path**: Navigate through your directory structure
   - Choose a destination (or create new directories)
   - Optionally provide a descriptive label (or press Enter to skip)
2. **Edit**: Write your content in the final location

**Recent Destinations**: The plugin remembers your last 5 used directories for both `:CreateNote` and `:SortNote`. Select a recent entry to skip directory navigation and go straight to the label prompt.

### Programmatic API

```lua
local katasync = require("katasync")

-- Create a new note in inbox and get the path
local path = katasync.new_note()

-- Create a note in chosen location (interactive)
katasync.create_note_at()

-- Display inbox notes (interactive)
katasync.list_inbox()

-- Sort the current note
katasync.sort_note()
```

## File Naming

### New Notes (`:NewNote`)
- `2025-10-08_09-17-33--note.md` - Inbox format
- `2025-10-08_09-17-33--note--2.md` - With collision handling

### Created Notes (`:CreateNote`)
- `miata-boost-2025-10-14_13-42-10--note.md` - With label
- `2025-10-14_13-42-10--note.md` - Without label (skipped)
- Created directly in final destination
- Collision handling with `--2`, `--3`, etc.

### Sorted Notes (`:SortNote`)
- `miata-boost-2025-10-08_11-07-15--note.md` - With label
- `2025-10-08_11-07-15--note.md` - Without label (skipped)
- Timestamp is preserved from original file
- Label precedes timestamp for readability (when provided)
- Collision handling with `--2`, `--3`, etc.

## Recent Destinations

The plugin tracks your most recently used directories when using `:CreateNote` and `:SortNote`. When you invoke these commands, you'll see:

```
Select destination:
→ projects/miata (2 hours ago)
→ journal (today)
Browse directories...
```

**Benefits:**
- Skip directory navigation for frequent destinations
- Faster workflow for repeated destinations
- Shared history between `:CreateNote` and `:SortNote`

**Storage:** Recent destinations are stored locally in `~/.local/state/nvim/katasync-mru.json`

## Directory Navigation

When browsing directories, you'll see:
- **[Subdirectories]** - Existing subdirectories (alphabetical)
- **✓ Drop Here** - Select current directory as destination
- **+ Create New** - Create a new subdirectory (names are sanitized)
- **← Go Back** - Navigate to parent directory (hidden at base)

## Philosophy

**Two workflows for different needs**

- **Capture fast, organize later**: `:NewNote` → `:SortNote`
  - Zero friction capture to inbox
  - Thoughtful organization when ready
- **Create in place**: `:CreateNote`
  - Direct creation when destination is known
  - Recent destinations for fast repeated workflows
- Timestamp preservation maintains creation history
- Clean, predictable file naming for easy searching

## License

MIT
