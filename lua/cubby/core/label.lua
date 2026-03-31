local M = {}

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

function M.validate_label(label)
    return label ~= nil and label ~= ""
end

return M

