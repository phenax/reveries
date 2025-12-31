const std = @import("std");
const rl = @import("raylib");

const clock = @import("./clock.zig");
const slideshow = @import("./slideshow.zig");
const agenda = @import("./agenda.zig");

pub fn main() anyerror!void {
    const screenWidth = 1024;
    const screenHeight = 576;

    // var mainAlloc = std.heap.DebugAllocator(.{}){};
    // defer {
    //     const deinit_status = mainAlloc.deinit();
    //     if (deinit_status == .leak) @panic("Leak");
    // }
    var rootArena = std.heap.ArenaAllocator.init(std.heap.c_allocator);
    defer rootArena.deinit();
    const alloc = rootArena.allocator();
    var arena = std.heap.ArenaAllocator.init(std.heap.c_allocator);
    const loopAlloc = arena.allocator();

    const clockWidget = clock.ClockWidget.new();
    var slideshowWidget = try slideshow.SlideshowWidget.new(alloc);
    defer slideshowWidget.deinit(alloc) catch {};
    var agendaWidget = try agenda.AgendaWidget.new(alloc);
    defer agendaWidget.deinit() catch {};

    rl.initWindow(screenWidth, screenHeight, "dashboard");
    defer rl.closeWindow();

    rl.setTargetFPS(2);

    while (!rl.windowShouldClose()) {
        rl.beginDrawing();
        rl.clearBackground(.black);

        try clockWidget.draw(loopAlloc);
        try slideshowWidget.draw(loopAlloc);
        try agendaWidget.draw(loopAlloc);

        rl.endDrawing();
        arena.deinit();
    }
}
