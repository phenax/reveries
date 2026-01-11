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

    pub fn draw(clock: ClockWidget) !void {
        const width = @divFloor(rl.getScreenWidth() * 5, 9);
        const timeFontSize = 170;
        const dateFontSize = 40;

        var now = dt.datetime.Datetime.now();
        now = now.shiftTimezone(clock.timezone);

        // Time
        var timefmtbuf: [8:0]u8 = undefined;
        const timefmt = try dtlocal.formatTime(now, &timefmtbuf);
        const timeTextWidth = rl.measureText(timefmt, timeFontSize);
        const timex = @divFloor(width - timeTextWidth, 2);
        const timey = 16;
        rl.drawText(timefmt, timex, timey, timeFontSize, .white);

        // Date
        var datefmtbuf: [64:0]u8 = undefined;
        const datefmt = try dtlocal.formatDate(now, &datefmtbuf);
        const dateTextWidth = rl.measureText(datefmt, dateFontSize);
        const datex = @divFloor(width - dateTextWidth, 2);
        const datey = 170;
        rl.drawText(datefmt, datex, datey, dateFontSize, .white);
    }

    pub fn deinit(_: *ClockWidget) !void {}
};
