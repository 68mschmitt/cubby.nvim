--- Tests for cubby.core.timestamp — Timestamp extraction, parsing, and fallback
local timestamp = require("cubby.core.timestamp")

describe("TIMESTAMP_PATTERN", function()
    it("matches a valid timestamp string", function()
        local ts = "2025-10-08_09-17-33"
        assert.truthy(ts:match(timestamp.TIMESTAMP_PATTERN))
    end)

    it("does not match incomplete timestamp", function()
        local ts = "2025-10-08"
        -- The pattern should not match a date-only string as a full timestamp
        local matched = ts:match("^" .. timestamp.TIMESTAMP_PATTERN .. "$")
        assert.is_nil(matched)
    end)
end)

describe("timestamp.extract_timestamp_from_filename", function()
    it("extracts timestamp from standard note filename", function()
        local ts = timestamp.extract_timestamp_from_filename("2025-10-08_09-17-33--note.md")
        assert.equals("2025-10-08_09-17-33", ts)
    end)

    it("extracts timestamp from labeled filename", function()
        local ts = timestamp.extract_timestamp_from_filename("miata-boost-2025-10-08_11-07-15--note.md")
        assert.equals("2025-10-08_11-07-15", ts)
    end)

    it("extracts timestamp from path with directories", function()
        local ts = timestamp.extract_timestamp_from_filename("/home/user/notes/inbox/2025-01-15_14-30-00--note.md")
        assert.equals("2025-01-15_14-30-00", ts)
    end)

    it("returns nil for filename with no timestamp", function()
        local ts = timestamp.extract_timestamp_from_filename("random-note.md")
        assert.is_nil(ts)
    end)

    it("returns nil for empty filename", function()
        local ts = timestamp.extract_timestamp_from_filename("")
        assert.is_nil(ts)
    end)
end)

describe("timestamp.parse_to_unix", function()
    it("parses a valid timestamp string to unix time", function()
        local unix = timestamp.parse_to_unix("2025-01-01_00-00-00")
        assert.is_not_nil(unix)
        assert.is_number(unix)
        -- Should be a reasonable unix timestamp (after 2024)
        assert.is_true(unix > 1700000000, "should be a recent unix timestamp")
    end)

    it("returns nil for nil input", function()
        assert.is_nil(timestamp.parse_to_unix(nil))
    end)

    it("returns nil for malformed string", function()
        assert.is_nil(timestamp.parse_to_unix("not-a-timestamp"))
    end)

    it("returns nil for empty string", function()
        assert.is_nil(timestamp.parse_to_unix(""))
    end)

    it("parses specific known date correctly", function()
        local unix = timestamp.parse_to_unix("2025-06-15_12-30-45")
        assert.is_not_nil(unix)
        local t = os.date("*t", unix)
        assert.equals(2025, t.year)
        assert.equals(6, t.month)
        assert.equals(15, t.day)
        assert.equals(12, t.hour)
        assert.equals(30, t.min)
        assert.equals(45, t.sec)
    end)
end)

describe("timestamp.preserve_or_fallback_timestamp", function()
    it("extracts timestamp from filename when present", function()
        local ts = timestamp.preserve_or_fallback_timestamp(
            "2025-10-08_09-17-33--note.md",
            "/tmp/nonexistent",
            "%Y-%m-%d_%H-%M-%S"
        )
        assert.equals("2025-10-08_09-17-33", ts)
    end)

    it("falls back to current time when no filename timestamp and no file", function()
        local ts = timestamp.preserve_or_fallback_timestamp(
            "random-note.md",
            "/tmp/definitely-does-not-exist-12345",
            "%Y-%m-%d_%H-%M-%S"
        )
        assert.is_not_nil(ts)
        assert.is_string(ts)
        -- Should match the timestamp pattern
        assert.truthy(ts:match("^%d%d%d%d%-%d%d%-%d%d_%d%d%-%d%d%-%d%d$"))
    end)
end)
