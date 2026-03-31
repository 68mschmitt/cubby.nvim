---@class cubby.label
local M = {}

---Sanitize a user-provided label for use in filenames.
---Lowercases, replaces spaces with hyphens, strips special characters.
---@param input string? Raw label input
---@return string sanitized Sanitized label (may be empty)
function M.sanitize_label(input)
    if not input or input == "" then
        return ""
    end

    local label = input:lower()
    label = label:gsub("%s+", "-")
    label = label:gsub("[^a-z0-9%-]", "")
    label = label:gsub("%-+", "-")
    label = label:gsub("^%-+", "")
    label = label:gsub("%-+$", "")

    return label
end

---Check whether a label is non-empty and valid.
---@param label string? Label to validate
---@return boolean
function M.validate_label(label)
    return label ~= nil and label ~= ""
end

return M
