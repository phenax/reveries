const std = @import("std");
const rl = @import("raylib");
const dt = @import("datetime");
const dtlocal = @import("./datetime.zig");

pub const ClockWidget = struct {
    timezone: dt.datetime.Timezone,
    alloc: std.mem.Allocator,

    pub fn new(alloc: std.mem.Allocator, timezone: dt.datetime.Timezone) ClockWidget {
        return ClockWidget{ .alloc = alloc, .timezone = timezone };
    }

    pub fn update(_: ClockWidget) void {}

    pub fn draw(clock: ClockWidget, timeFont: rl.Font, dateFont: rl.Font) !void {
        const width = @divFloor(rl.getScreenWidth() * 5, 9);
        const timeFontSize = 120;
        const dateFontSize = 40;
        const textSpacing = 1;

        var now = dt.datetime.Datetime.now();
        now = now.shiftTimezone(clock.timezone);

        // Time
        var timefmtbuf: [8:0]u8 = undefined;
        const timefmt = try dtlocal.formatTime(now, &timefmtbuf);
        const timeTextMeasure = rl.measureTextEx(timeFont, timefmt, timeFontSize, textSpacing);
        const timex = @divFloor(width - @as(i32, @intFromFloat(timeTextMeasure.x)), 2);
        const timey = 28;
        rl.drawTextEx(timeFont, timefmt, rl.Vector2.init(@floatFromInt(timex), @floatFromInt(timey)), timeFontSize, textSpacing, .white);

        // Date
        var datefmtbuf: [64:0]u8 = undefined;
        const datefmt = try dtlocal.formatDate(now, &datefmtbuf);
        const dateTextMeasure = rl.measureTextEx(dateFont, datefmt, dateFontSize, textSpacing);
        const datex = @divFloor(width - @as(i32, @intFromFloat(dateTextMeasure.x)), 2);
        const datey = 170;
        rl.drawTextEx(dateFont, datefmt, rl.Vector2.init(@floatFromInt(datex), @floatFromInt(datey)), dateFontSize, textSpacing, .white);
    }

    pub fn deinit(_: *ClockWidget) !void {}
};
