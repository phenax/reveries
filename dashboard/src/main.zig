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

    const font7Segment = try rl.loadFontFromMemory(".ttf", @embedFile("./static/DSEG7Classic-Regular.ttf"), 160, null);
    defer rl.unloadFont(font7Segment);
    rl.setTextureFilter(font7Segment.texture, rl.TextureFilter.trilinear);

    const fontData = @embedFile("./static/3270NerdFontMono-Regular.ttf");
    const font = try rl.loadFontFromMemory(".ttf", fontData, 20, null);
    defer rl.unloadFont(font);
    rl.setTextureFilter(font.texture, rl.TextureFilter.trilinear);
    const fontLg = try rl.loadFontFromMemory(".ttf", fontData, 60, null);
    defer rl.unloadFont(fontLg);
    rl.setTextureFilter(fontLg.texture, rl.TextureFilter.trilinear);

    rl.setTargetFPS(2);

    while (!rl.windowShouldClose()) {
        rl.beginDrawing();
        rl.clearBackground(.black);

        try clockWidget.draw(font7Segment, fontLg);
        slideshowWidget.draw();
        try agendaWidget.draw(font);

        rl.endDrawing();

        clockWidget.update();
        slideshowWidget.update();
        agendaWidget.update();
    }
}
