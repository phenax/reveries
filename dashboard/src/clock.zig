const std = @import("std");
const rl = @import("raylib");
const dt = @import("datetime");

pub const ClockWidget = struct {
    pub fn new() ClockWidget {
        return ClockWidget{};
    }

    pub fn draw(_: ClockWidget, alloc: std.mem.Allocator) error{OutOfMemory}!void {
        var timestr: [8:0]u8 = undefined;
        var datestr: [64:0]u8 = undefined;

        // TODO: Remove timezone hardcoding
        const zone = dt.timezones.Asia.Kolkata;

        var now = dt.datetime.Datetime.now();
        now = now.shiftSeconds(zone.offsetSeconds());

        const timefmt = try formatTime(now, alloc);
        defer alloc.free(timefmt);
        timestr[timefmt.len] = 0;
        std.mem.copyForwards(u8, &timestr, timefmt);

        const datefmt = try formatDate(now, alloc);
        defer alloc.free(datefmt);
        datestr[datefmt.len] = 0;
        std.mem.copyForwards(u8, &datestr, datefmt);

        const width = @divFloor(rl.getScreenWidth() * 5, 9);

        const timeFontSize = 140;
        const dateFontSize = 40;

        const timeTextWidth = rl.measureText(&timestr, timeFontSize);
        const timex = @divFloor(width - timeTextWidth, 2);
        const y = 16;
        rl.drawText(&timestr, timex, y, timeFontSize, .white);

        const dateTextWidth = rl.measureText(&datestr, dateFontSize);
        const datex = @divFloor(width - dateTextWidth, 2);
        rl.drawText(&datestr, datex, 180, dateFontSize, .white);
    }
};

pub fn formatTime(time: dt.datetime.Datetime, alloc: std.mem.Allocator) ![]u8 {
    const hour = if (time.time.hour > 12) time.time.hour - 12 else time.time.hour;
    const timefmt = try std.fmt.allocPrint(
        alloc,
        "{d:0>2}:{d:0>2}",
        .{ hour, time.time.minute },
    );
    return timefmt;
}

pub fn formatDate(time: dt.datetime.Datetime, alloc: std.mem.Allocator) ![]u8 {
    const timefmt = try std.fmt.allocPrint(
        alloc,
        "{s}, {d} {s}",
        .{ time.date.weekdayName(), time.date.day, time.date.monthName() },
    );
    return timefmt;
}
