const std = @import("std");
const rl = @import("raylib");
const dt = @import("datetime");

const defaultSlideDurationSeconds: u16 = 30;

pub const SlideshowWidget = struct {
    alloc: std.mem.Allocator,
    texturesCache: std.StringHashMap(rl.Texture),
    filePaths: std.ArrayList([]u8),
    current: usize = 1,
    nextSlideTimestamp: i64,
    slideDurationSeconds: u16 = defaultSlideDurationSeconds,
    paddingX: i32 = 0,
    paddingY: i32 = 0,

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

        const slideDurationSeconds = defaultSlideDurationSeconds;
        return SlideshowWidget{
            .alloc = alloc,
            .filePaths = filePaths,
            .texturesCache = std.StringHashMap(rl.Texture).init(alloc),
            .nextSlideTimestamp = std.time.timestamp() + slideDurationSeconds,
            .slideDurationSeconds = slideDurationSeconds,
        };
    }

    pub fn update(slideshow: *SlideshowWidget) void {
        const now = std.time.timestamp();
        if (slideshow.nextSlideTimestamp < now) {
            const count = slideshow.filePaths.items.len;
            slideshow.current = @mod(slideshow.current + 1, count);
            slideshow.nextSlideTimestamp = now + slideshow.slideDurationSeconds;
        }
    }

    pub fn draw(slideshow: *SlideshowWidget) void {
        const width = @divFloor(rl.getScreenWidth() * 5, 9);
        const count = slideshow.filePaths.items.len;

        if (count == 0) return;
        if (slideshow.current > count) return;

        if (slideshow.getTexture()) |texture| {
            const imgx = width + slideshow.paddingX;
            const imgy = slideshow.paddingY;
            rl.drawTexture(texture, imgx, imgy, .white);
        }
    }

    fn getTexture(slideshow: *SlideshowWidget) ?rl.Texture {
        const count = slideshow.filePaths.items.len;
        if (count == 0) return null;
        if (slideshow.current > count) return null;

        const path = slideshow.filePaths.items[slideshow.current];
        return slideshow.texturesCache.get(path) orelse slideshow.loadImageIntoCache(path) catch null;
    }

    fn loadImageIntoCache(slideshow: *SlideshowWidget, path: []u8) !rl.Texture {
        const texture = try slideshow.loadImageTexture(path);
        std.debug.print("- loading {s}\n", .{path});
        try slideshow.texturesCache.put(path, texture);
        return texture;
    }

    fn loadImageTexture(slideshow: SlideshowWidget, path: []u8) !rl.Texture {
        var pathbuf: [std.fs.max_path_bytes:0]u8 = undefined;
        std.mem.copyForwards(u8, &pathbuf, path);
        pathbuf[path.len] = 0;
        var img = try rl.loadImage(&pathbuf);
        defer rl.unloadImage(img);

        const sw = @divFloor(rl.getScreenWidth() * 4, 9) - 2 * slideshow.paddingX;
        const sh = rl.getScreenHeight() - 2 * slideshow.paddingY;
        const boxAspectRatio = @as(f32, @floatFromInt(sw)) / @as(f32, @floatFromInt(sh));

        std.debug.print(":::::: fooo {d}x{d}\n", .{ sw, sh });

        const imgHeight = @as(f32, @floatFromInt(img.height));
        const imgWidth = @as(f32, @floatFromInt(img.width));
        // const aspectRatio = imgWidth / imgHeight;

        const isLandscape = img.width > img.height;
        const www = if (isLandscape) imgHeight * boxAspectRatio else imgWidth;
        const hhh = if (isLandscape) imgHeight else imgWidth / boxAspectRatio;
        const offsetX = (imgWidth - www) / 2;
        const offsetY = (imgHeight - hhh) / 2;
        std.debug.print(":::::: swsh {d}x{d}:{d}-{d}\n", .{ offsetX, offsetY, imgWidth - 2 * offsetX, imgHeight - 2 * offsetY });

        rl.imageCrop(&img, rl.Rectangle.init(@floor(offsetX), @floor(offsetY), @floor(imgWidth - 2 * offsetX), @floor(imgHeight - 2 * offsetY)));
        rl.imageResize(&img, sw, sh);

        return try rl.loadTextureFromImage(img);
    }

    pub fn deinit(slideshow: *SlideshowWidget) !void {
        for (slideshow.filePaths.items) |p| {
            slideshow.alloc.free(p);
        }
        slideshow.filePaths.deinit(slideshow.alloc);
        slideshow.texturesCache.deinit();
    }
};
