--- Tests for cubby.core.time — Time formatting and relative time display
local time = require("cubby.core.time")

describe("time.now_stamp", function()
    it("returns a formatted timestamp string", function()
        local stamp = time.now_stamp("%Y-%m-%d_%H-%M-%S")
        assert.is_string(stamp)
        assert.truthy(stamp:match("^%d%d%d%d%-%d%d%-%d%d_%d%d%-%d%d%-%d%d$"))
    end)

    it("errors when format is nil", function()
        assert.has.errors(function()
            time.now_stamp(nil)
        end)
    end)

    it("respects custom format", function()
        local stamp = time.now_stamp("%Y")
        assert.is_string(stamp)
        assert.truthy(stamp:match("^%d%d%d%d$"))
    end)
end)

describe("time.format_relative_time", function()
    local now = os.time()

    it("returns 'just now' for timestamps within 60 seconds", function()
        assert.equals("just now", time.format_relative_time(now))
        assert.equals("just now", time.format_relative_time(now - 30))
        assert.equals("just now", time.format_relative_time(now - 59))
    end)

    it("returns minutes ago for 1-59 minutes", function()
        assert.equals("1 minute ago", time.format_relative_time(now - 60))
        assert.equals("5 minutes ago", time.format_relative_time(now - 300))
        assert.equals("59 minutes ago", time.format_relative_time(now - 3540))
    end)

    it("handles singular minute", function()
        assert.equals("1 minute ago", time.format_relative_time(now - 60))
        assert.equals("1 minute ago", time.format_relative_time(now - 119))
    end)

    it("returns hours ago for 1-23 hours", function()
        assert.equals("1 hour ago", time.format_relative_time(now - 3600))
        assert.equals("5 hours ago", time.format_relative_time(now - 18000))
        assert.equals("23 hours ago", time.format_relative_time(now - 82800))
    end)

    it("handles singular hour", function()
        assert.equals("1 hour ago", time.format_relative_time(now - 3600))
    end)

    it("returns 'yesterday' for 24-47 hours", function()
        assert.equals("yesterday", time.format_relative_time(now - 86400))
        assert.equals("yesterday", time.format_relative_time(now - 172799))
    end)

    it("returns days ago for 2-6 days", function()
        assert.equals("2 days ago", time.format_relative_time(now - 172800))
        assert.equals("6 days ago", time.format_relative_time(now - 518400))
    end)

    it("returns '1 week ago' for 7-13 days", function()
        assert.equals("1 week ago", time.format_relative_time(now - 604800))
        assert.equals("1 week ago", time.format_relative_time(now - 1209599))
    end)

    it("returns weeks ago for 2-4 weeks", function()
        assert.equals("2 weeks ago", time.format_relative_time(now - 1209600))
        assert.equals("3 weeks ago", time.format_relative_time(now - 2000000))
    end)

    it("returns '1 month ago' for 30-59 days", function()
        assert.equals("1 month ago", time.format_relative_time(now - 2592000))
        assert.equals("1 month ago", time.format_relative_time(now - 5183999))
    end)

    it("returns months ago for 2+ months", function()
        assert.equals("2 months ago", time.format_relative_time(now - 5184000))
    end)
end)
