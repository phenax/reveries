const std = @import("std");
const rl = @import("raylib");

pub const Time = struct {
    hours: u8 = 0,
    minutes: u8 = 0,
    seconds: u8 = 0,

    pub fn formatted(time: Time, alloc: std.mem.Allocator) ![]u8 {
        const timefmt = try std.fmt.allocPrint(
            alloc,
            "{d:0>2}:{d:0>2}:{d:0>2}",
            .{ time.hours, time.minutes, time.seconds },
        );
        return timefmt;
    }
};

pub const ClockWidget = struct {
    fontSize: i32 = 180,
    textWidthCache: i32 = 0,
    pub fn new(fontSize: i32) ClockWidget {
        return ClockWidget{
            .fontSize = fontSize,
            .textWidthCache = rl.measureText("01:00:00", fontSize) + 20,
        };
    }

    pub fn draw(clock: ClockWidget, alloc: std.mem.Allocator) error{OutOfMemory}!void {
        var timestr: [8:0]u8 = undefined;

        const time = getCurrentTime();
        const timefmt = try time.formatted(alloc);
        defer alloc.free(timefmt);

        timestr[timefmt.len] = 0;
        std.mem.copyForwards(u8, &timestr, timefmt);

        const x = @divFloor(rl.getScreenWidth() - clock.textWidthCache, 2);
        const y = 30;
        rl.drawText(&timestr, x, y, clock.fontSize, .white);
    }
};

pub fn getCurrentTime() Time {
    // FIXME: hardcoded timezone offset
    const tzoffset = 5 * std.time.s_per_hour + 30 * std.time.s_per_min;
    const timestamp = @abs(std.time.timestamp() + tzoffset);
    var epoch = std.time.epoch.EpochSeconds{ .secs = timestamp };
    const time = epoch.getDaySeconds();
    var hours = time.getHoursIntoDay();
    hours = if (hours > 12) hours - 12 else hours;

    return Time{
        .hours = hours,
        .minutes = time.getMinutesIntoHour(),
        .seconds = time.getSecondsIntoMinute(),
    };
}
