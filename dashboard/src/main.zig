const rl = @import("raylib");
const std = @import("std");

const Time = struct {
  hours: u8 = 0,
  minutes: u8 = 0,
  seconds: u8 = 0,
  pub fn formatted(time: Time, alloc: std.mem.Allocator) error{OutOfMemory}![]u8 {
    const timefmt = try std.fmt.allocPrint(
        alloc,
        "{d:0>2}:{d:0>2}:{d:0>2}",
        .{ time.hours, time.minutes, time.seconds },
    );
    return timefmt;
  }
};

fn getCurrentTime() Time {
  // FIXME: hardcoded timezone offset
  const tzoffset = 5 * std.time.s_per_hour + 30 * std.time.s_per_min;
  const timestamp = @abs(std.time.timestamp() + tzoffset);
  var epoch = std.time.epoch.EpochSeconds{ .secs = timestamp };
  const time = epoch.getDaySeconds();
  var hours = time.getHoursIntoDay();
  hours = if (hours > 12) hours - 12 else hours;

  return Time {
    .hours = hours,
    .minutes = time.getMinutesIntoHour(),
    .seconds = time.getSecondsIntoMinute(),
  };
}

pub fn main() anyerror!void {
    const screenWidth = 800;
    const screenHeight = 600;

    rl.initWindow(screenWidth, screenHeight, "dashboard");
    defer rl.closeWindow();

    rl.setTargetFPS(2);

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    var timestr: [64:0]u8 = undefined;
    const fontSize = 180;
    const textWidth = rl.measureText("01:00:00", fontSize);

    while (!rl.windowShouldClose()) {
        rl.beginDrawing();
        defer rl.endDrawing();

        rl.clearBackground(.black);

        const time = getCurrentTime();
        const timefmt = try time.formatted(alloc);
        defer alloc.free(timefmt);

        timestr[timefmt.len] = 0;
        std.mem.copyForwards(u8, &timestr, timefmt);

        const x = @divFloor(rl.getScreenWidth() - textWidth, 2);
        const y = 50;

        rl.drawText(&timestr, x, y, fontSize, .white);
    }
}
