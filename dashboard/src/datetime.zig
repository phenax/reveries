const std = @import("std");
const dt = @import("datetime");

const Datetime = dt.datetime.Datetime;

// Move datetime specific things to its own module
pub fn parseIsoDatetime(str: []const u8, timezone: ?dt.datetime.Timezone) error{ InvalidDate, InvalidTime }!Datetime {
    if (str.len < 15) return error.InvalidDate;
    const year = std.fmt.parseInt(u32, str[0..4], 10) catch return error.InvalidDate;
    const month = std.fmt.parseInt(u32, str[4..6], 10) catch return error.InvalidDate;
    const day = std.fmt.parseInt(u32, str[6..8], 10) catch return error.InvalidDate;
    const hour = std.fmt.parseInt(u32, str[9..11], 10) catch return error.InvalidTime;
    const minute = std.fmt.parseInt(u32, str[11..13], 10) catch return error.InvalidTime;
    const second = std.fmt.parseInt(u32, str[13..15], 10) catch return error.InvalidTime;
    return Datetime.create(year, month, day, hour, minute, second, 0, timezone);
}

pub fn formatTime(time: Datetime, buf: []u8) ![:0]const u8 {
    const hour = if (time.time.hour > 12) time.time.hour - 12 else time.time.hour;
    return try std.fmt.bufPrintZ(
        buf,
        "{d:0>2}:{d:0>2}",
        .{ hour, time.time.minute },
    );
}

pub fn formatDate(time: Datetime, buf: []u8) ![:0]const u8 {
    return try std.fmt.bufPrintZ(
        buf,
        "{s}, {d} {s}",
        .{ time.date.weekdayName(), time.date.day, time.date.monthName() },
    );
}

pub fn formatISO8601Basic(alloc: std.mem.Allocator, datetime: Datetime) ![]const u8 {
    return try std.fmt.allocPrint(
        alloc,
        "{d:0>2}{d:0>2}{d:0>2}T{d:0>2}{d:0>2}{d:0>2}Z",
        .{ datetime.date.year, datetime.date.month, datetime.date.day, datetime.time.hour, datetime.time.minute, datetime.time.second },
    );
}

pub fn between(datetime: Datetime, start: Datetime, end: Datetime) bool {
    return datetime.gte(start) and datetime.lte(end);
}
