const std = @import("std");
const rl = @import("raylib");
const dt = @import("datetime");

const clock = @import("./clock.zig");
const slideshow = @import("./slideshow.zig");
const agenda = @import("./agenda.zig");

pub fn main() anyerror!void {
    const screenWidth = 1024;
    const screenHeight = 576;

    var mainAlloc = std.heap.DebugAllocator(.{}){};
    defer {
        const deinit_status = mainAlloc.deinit();
        if (deinit_status == .leak) @panic("Leak");
    }
    const alloc = mainAlloc.allocator();

    // TODO: parse /etc/localtime
    const timezone = dt.timezones.Asia.Kolkata;

    var clockWidget = clock.ClockWidget.new(alloc, timezone);
    defer clockWidget.deinit() catch {};

    var slideshowWidget = try slideshow.SlideshowWidget.new(alloc);
    defer slideshowWidget.deinit() catch {};

    var agendaWidget = try agenda.AgendaWidget.new(alloc, "http://calendar.local/joe/Work", timezone);
    defer agendaWidget.deinit() catch {};

    rl.initWindow(screenWidth, screenHeight, "dashboard");
    defer rl.closeWindow();

    rl.setTargetFPS(2);

    while (!rl.windowShouldClose()) {
        rl.beginDrawing();
        rl.clearBackground(.black);

        try clockWidget.draw();
        slideshowWidget.draw();
        try agendaWidget.draw();

        rl.endDrawing();

        clockWidget.update();
        slideshowWidget.update();
        agendaWidget.update();
    }
}
