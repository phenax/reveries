const std = @import("std");
const rl = @import("raylib");
const dt = @import("datetime");
const dtlocal = @import("./datetime.zig");

pub const ClockWidget = struct {
    // TODO: Remove timezone hardcoding
    timezone: dt.datetime.Timezone = dt.timezones.Asia.Kolkata,

    pub fn new() ClockWidget {
        return ClockWidget{};
    }

    pub fn draw(clock: ClockWidget, _: std.mem.Allocator) !void {
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
};
