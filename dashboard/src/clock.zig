const std = @import("std");
const rl = @import("raylib");
const dt = @import("datetime");

pub const ClockWidget = struct {
    pub fn new() ClockWidget {
        return ClockWidget{};
    }

    pub fn draw(_: ClockWidget, _: std.mem.Allocator) !void {
        const width = @divFloor(rl.getScreenWidth() * 5, 9);
        const timeFontSize = 170;
        const dateFontSize = 40;

        // TODO: Remove timezone hardcoding
        const zone = dt.timezones.Asia.Kolkata;
        var now = dt.datetime.Datetime.now();
        now = now.shiftSeconds(zone.offsetSeconds());

        // Time
        var timefmtbuf: [8:0]u8 = undefined;
        const timefmt = try formatTime(now, &timefmtbuf);
        const timeTextWidth = rl.measureText(timefmt, timeFontSize);
        const timex = @divFloor(width - timeTextWidth, 2);
        const timey = 16;
        rl.drawText(timefmt, timex, timey, timeFontSize, .white);

        // Date
        var datefmtbuf: [64:0]u8 = undefined;
        const datefmt = try formatDate(now, &datefmtbuf);
        const dateTextWidth = rl.measureText(datefmt, dateFontSize);
        const datex = @divFloor(width - dateTextWidth, 2);
        const datey = 170;
        rl.drawText(datefmt, datex, datey, dateFontSize, .white);
    }
};

pub fn formatTime(time: dt.datetime.Datetime, buf: []u8) ![:0]const u8 {
    const hour = if (time.time.hour > 12) time.time.hour - 12 else time.time.hour;
    return try std.fmt.bufPrintZ(
        buf,
        "{d:0>2}:{d:0>2}",
        .{ hour, time.time.minute },
    );
}

pub fn formatDate(time: dt.datetime.Datetime, buf: []u8) ![:0]const u8 {
    return try std.fmt.bufPrintZ(
        buf,
        "{s}, {d} {s}",
        .{ time.date.weekdayName(), time.date.day, time.date.monthName() },
    );
}
