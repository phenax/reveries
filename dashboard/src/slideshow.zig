const std = @import("std");
const rl = @import("raylib");
const dt = @import("datetime");

pub const SlideshowWidget = struct {
    texturesCache: std.StringHashMap(rl.Texture),
    filePaths: std.ArrayList([]u8),
    current: usize = 0,
    nextSlideTimestamp: i64,
    slideDuration: u16,

    pub fn new(alloc: std.mem.Allocator) !SlideshowWidget {
        var localArena = std.heap.ArenaAllocator.init(std.heap.c_allocator);
        defer localArena.deinit();
        const localAlloc = localArena.allocator();

        var envMap = try std.process.getEnvMap(localAlloc);
        const homeDir = envMap.get("HOME") orelse "/";
        const appDir = try std.fmt.allocPrint(localAlloc, "{s}/Pictures/slideshow", .{homeDir});
        std.debug.print("[log] albumdir: {s}\n", .{appDir});

        const albumDir = std.fs.openDirAbsolute(appDir, .{ .iterate = true }) catch mkdir: {
            try std.fs.makeDirAbsolute(appDir);
            break :mkdir try std.fs.openDirAbsolute(appDir, .{ .iterate = true });
        };
        var dirIter = albumDir.iterate();
        var filePaths: std.ArrayList([]u8) = .empty;

        while (try dirIter.next()) |file| {
            if (file.kind == .file) {
                const path = try albumDir.realpathAlloc(alloc, file.name);
                std.debug.print("- file: {s}\n", .{path});
                try filePaths.append(alloc, path);
            }
        }

        const slideDuration = 2;
        return SlideshowWidget{
            .filePaths = filePaths,
            .texturesCache = std.StringHashMap(rl.Texture).init(alloc),
            .nextSlideTimestamp = std.time.timestamp() + slideDuration,
            .slideDuration = slideDuration,
        };
    }

    pub fn draw(slideshow: *SlideshowWidget, _: std.mem.Allocator) !void {
        const width = @divFloor(rl.getScreenWidth() * 5, 9);
        const count = slideshow.filePaths.items.len;

        if (count == 0) return;
        if (slideshow.current > count) return;

        if (try slideshow.getTexture()) |texture| {
            const imgx = width;
            const imgy = 20;
            rl.drawTexture(texture, imgx, imgy, .white);
        }

        // Switch to next image
        const now = std.time.timestamp();
        if (slideshow.nextSlideTimestamp < now) {
            slideshow.current = @mod(slideshow.current + 1, count);
            slideshow.nextSlideTimestamp = now + slideshow.slideDuration;
            std.debug.print(":::: {d} {d}\n", .{ slideshow.current, count });
        }
    }

    fn loadImageIntoCache(slideshow: *SlideshowWidget, path: []u8) !rl.Texture {
        const texture = try loadImageTexture(path);
        try slideshow.texturesCache.put(path, texture);
        return texture;
    }

    fn getTexture(slideshow: *SlideshowWidget) !?rl.Texture {
        const count = slideshow.filePaths.items.len;
        if (count == 0) return null;
        if (slideshow.current > count) return null;

        const path = slideshow.filePaths.items[slideshow.current];
        std.debug.print("- loading {s}\n", .{path});
        return slideshow.texturesCache.get(path) orelse try slideshow.loadImageIntoCache(path);
    }

    pub fn deinit(slideshow: *SlideshowWidget, alloc: std.mem.Allocator) !void {
        for (slideshow.filePaths.items) |p| {
            alloc.free(p);
        }
        slideshow.filePaths.deinit(alloc);
        slideshow.texturesCache.deinit();
    }
};

fn loadImageTexture(path: []u8) !rl.Texture {
    var pathbuf: [std.fs.max_path_bytes:0]u8 = undefined;
    std.mem.copyForwards(u8, &pathbuf, path);
    pathbuf[path.len] = 0;
    var img = try rl.loadImage(&pathbuf);
    defer rl.unloadImage(img);

    const padding = 40;
    rl.imageCrop(&img, rl.Rectangle.init(0, @floatFromInt(padding), @floatFromInt(img.width), @floatFromInt(img.height - padding)));
    const aspectRatio = @as(f32, @floatFromInt(img.width)) / @as(f32, @floatFromInt(img.height));
    const height = rl.getScreenHeight(); // 320
    const width = @as(i32, @intFromFloat(@as(f32, @floatFromInt(height)) * aspectRatio));
    rl.imageResize(&img, width, height - 40);
    const texture = try rl.loadTextureFromImage(img);

    return texture;
}
