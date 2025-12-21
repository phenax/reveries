const std = @import("std");
const rl = @import("raylib");

const clock = @import("./clock.zig");

pub fn main() anyerror!void {
    const screenWidth = 1024;
    const screenHeight = 576;

    rl.initWindow(screenWidth, screenHeight, "dashboard");
    defer rl.closeWindow();

    rl.setTargetFPS(2);

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    // var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer {
        const deinit_status = gpa.deinit();
        if (deinit_status == .leak) @panic("Leak");
    }
    const alloc = gpa.allocator();

    const clockwidget = clock.ClockWidget.new(190);

    while (!rl.windowShouldClose()) {
        rl.beginDrawing();
        rl.clearBackground(.black);

        try clockwidget.draw(alloc);
        rl.endDrawing();
    }
}
