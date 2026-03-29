const std = @import("std");
const dt = @import("datetime");
const dtlocal = @import("./datetime.zig");

pub const VEvent = struct {
    title: []u8 = "",
    dtstart: ?dt.datetime.Datetime = null,
    dtend: ?dt.datetime.Datetime = null,
    pub fn lessThan(_: void, a: VEvent, b: VEvent) bool {
        if (b.dtstart) |bdt| {
            if (a.dtstart) |adt| {
                return adt.lt(bdt);
            }
            return false;
        }
        return false;
    }
    pub fn deinit(event: VEvent, alloc: std.mem.Allocator) void {
        alloc.free(event.title);
    }
};

pub const VTodo = struct {
    title: []u8 = "",
    due: ?dt.datetime.Datetime = null,
    tags: std.ArrayList([]const u8) = .empty,
    pub fn lessThan(_: void, _: VTodo, _: VTodo) bool {
        return false;
    }
    pub fn deinit(todo: VTodo, alloc: std.mem.Allocator) void {
        alloc.free(todo.title);
    }
};

pub const CalendarItemTag = enum { vevent, vtodo };
pub const CalendarItem = union(CalendarItemTag) {
    vevent: VEvent,
    vtodo: VTodo,

    pub fn lessThan(k: void, item1: CalendarItem, item2: CalendarItem) bool {
        return switch (item1) {
            .vevent => |ev1| switch (item2) {
                .vevent => |ev2| VEvent.lessThan(k, ev1, ev2),
                else => false,
            },
            .vtodo => |todo1| switch (item2) {
                .vtodo => |todo2| VTodo.lessThan(k, todo1, todo2),
                else => false,
            },
        };
    }

    pub fn deinit(item: *CalendarItem, alloc: std.mem.Allocator) void {
        switch (item.*) {
            .vevent => |*e| e.deinit(alloc),
            .vtodo => |*t| t.deinit(alloc),
        }
        item.* = undefined;
    }
};

pub fn parseIcs(ical: []const u8, alloc: std.mem.Allocator) !std.ArrayList(CalendarItem) {
    var lines = std.mem.splitScalar(u8, ical, '\n');

    var items: std.ArrayList(CalendarItem) = .empty;
    var itemMaybe: ?CalendarItem = null;
    std.debug.print(".item\n", .{});
    while (lines.next()) |line| {
        if (std.mem.startsWith(u8, line, "BEGIN:VEVENT")) {
            std.debug.print("  .vevent\n", .{});
            itemMaybe = CalendarItem{ .vevent = VEvent{} };
        } else if (std.mem.startsWith(u8, line, "BEGIN:VTODO")) {
            std.debug.print("  .vtodo\n", .{});
            itemMaybe = CalendarItem{ .vtodo = VTodo{} };
        } else if (itemMaybe) |*item| {
            if (std.mem.startsWith(u8, line, "END:VEVENT") or std.mem.startsWith(u8, line, "END:VTODO")) {
                try items.append(alloc, item.*);
            } else if (std.mem.startsWith(u8, line, "DUE:") or std.mem.startsWith(u8, line, "DUE;")) {
                std.debug.print("    .due: {s}\n", .{line});
                const due = line[4..]; // Removing DUE: and DUE;
                switch (item.*) {
                    .vtodo => |*t| {
                        t.due = try parseIcsDateTime(due);
                    },
                    else => {},
                }
            } else if (std.mem.startsWith(u8, line, "DTSTART:") or std.mem.startsWith(u8, line, "DTSTART;")) {
                std.debug.print("    .dstart: {s}\n", .{line});
                const dtstart = line[8..]; // Removing DTSTART: and DTSTART;
                switch (item.*) {
                    .vevent => |*e| {
                        e.dtstart = try parseIcsDateTime(dtstart);
                    },
                    else => {},
                }
            } else if (std.mem.startsWith(u8, line, "DTEND:") or std.mem.startsWith(u8, line, "DTEND;")) {
                std.debug.print("    .dend: {s}\n", .{line});
                const dtend = line[6..]; // Removing DTEND: and DTEND;
                switch (item.*) {
                    .vevent => |*e| {
                        e.dtend = try parseIcsDateTime(dtend);
                    },
                    else => {},
                }
            } else if (std.mem.startsWith(u8, line, "SUMMARY:")) {
                const title = line[8..]; // Removing SUMMARY:
                std.debug.print("    .title: {s}\n", .{title});
                switch (item.*) {
                    .vevent => |*e| {
                        e.title = try alloc.dupe(u8, title);
                    },
                    .vtodo => |*t| {
                        t.title = try alloc.dupe(u8, title);
                    },
                }
            } else if (std.mem.startsWith(u8, line, "CATEGORIES:")) {
                const categories = line[11..]; // Removing CATEGORIES:
                std.debug.print("    .tags: {s}\n", .{categories});
                switch (item.*) {
                    .vtodo => |*t| {
                        var tags = std.mem.splitScalar(u8, categories, ',');
                        while (tags.next()) |tag| {
                            const tagCopy = try alloc.alloc(u8, tag.len);
                            @memcpy(tagCopy, tag);
                            try t.tags.append(alloc, tagCopy);
                        }
                    },
                    else => {},
                }
            }
        }
    }

    return items;
}

pub fn parseIcsDateTime(str: []const u8) !dt.datetime.Datetime {
    var dtparts = std.mem.splitScalar(u8, str, ':');
    const p1 = dtparts.next();
    const p2 = dtparts.next();
    var timezone: ?dt.datetime.Timezone = null;
    var datetime: []const u8 = undefined;
    if (p2) |time| {
        timezone = if (p1) |tz| dt.timezones.getByName(tz[5..]) catch null else null;
        datetime = time;
    } else if (p1) |time| {
        datetime = time;
    }
    return try dtlocal.parseIsoDatetime(datetime, timezone);
}
