local M = {}

function M.now_stamp(fmt)
    assert(fmt, "cubby: timestamp format required (did you call setup()?)")
    return os.date(fmt)
end

function M.format_relative_time(unix_timestamp)
    local now = os.time()
    local diff = now - unix_timestamp

    if diff < 60 then
        return "just now"
    elseif diff < 3600 then
        local minutes = math.floor(diff / 60)
        return string.format("%d minute%s ago", minutes, minutes > 1 and "s" or "")
    elseif diff < 86400 then
        local hours = math.floor(diff / 3600)
        return string.format("%d hour%s ago", hours, hours > 1 and "s" or "")
    elseif diff < 172800 then
        return "yesterday"
    elseif diff < 604800 then
        local days = math.floor(diff / 86400)
        return string.format("%d day%s ago", days, days > 1 and "s" or "")
    elseif diff < 1209600 then
        return "1 week ago"
    elseif diff < 2592000 then
        local weeks = math.floor(diff / 604800)
        return string.format("%d week%s ago", weeks, weeks > 1 and "s" or "")
    elseif diff < 5184000 then
        return "1 month ago"
    else
        local months = math.floor(diff / 2592000)
        return string.format("%d month%s ago", months, months > 1 and "s" or "")
    end
end

return M
