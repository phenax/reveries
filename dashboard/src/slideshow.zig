const std = @import("std");
const rl = @import("raylib");
const dt = @import("datetime");

pub const SlideshowWidget = struct {
    texture: rl.Texture,
    albumDirectory: []u8,

    pub fn new(alloc: std.mem.Allocator) !SlideshowWidget {
        const texture = try loadImageTexture("/home/imsohexy/Downloads/photos/1747916632474.jpg");
        var envMap = try std.process.getEnvMap(alloc);
        defer envMap.deinit();
        const homeDir = envMap.get("HOME") orelse "/";
        std.debug.print(":::: {s}\n", .{homeDir});

        const appDir = try std.fmt.allocPrint(alloc, "{s}/Pictures/slideshow", .{homeDir});
        defer alloc.free(appDir);
        std.debug.print("::::app:::: {s}\n", .{appDir});

        // const albumDir = try std.fs.openDirAbsolute(appDir, .{ .iterate = true });
        // var dirIter = albumDir.iterate();

        // while (try dirIter.next()) |file| {
        //     const name = file.name;
        //     const kind = file.kind;

        //     std.debug.print("* {s} ({s})\n", .{
        //         name,
        //         @tagName(kind),
        //     });
        // }

        return SlideshowWidget{
            .texture = texture,
            .albumDirectory = "",
        };
    }

    pub fn draw(slideshow: SlideshowWidget, _: std.mem.Allocator) !void {
        const width = @divFloor(rl.getScreenWidth() * 5, 9);

        // @divFloor(width - slideshow.texture.width, 2), 240
        const imgx = width;
        const imgy = 20;
        rl.drawTexture(slideshow.texture, imgx, imgy, .white);
    }
};

fn loadImageTexture(url: [:0]const u8) !rl.Texture {
    var img = try rl.loadImage(url);
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
