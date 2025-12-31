const std = @import("std");
const dt = @import("datetime");
const dtlocal = @import("./datetime.zig");

pub const VEvent = struct { title: []u8 = "", dtstart: ?dt.datetime.Datetime = null, dtend: ?dt.datetime.Datetime = null };
pub const VTodo = struct { title: []u8 = "", due: ?dt.datetime.Datetime = null };
pub const CalendarItemTag = enum { vevent, vtodo };
pub const CalendarItem = union(CalendarItemTag) {
    vevent: VEvent,
    vtodo: VTodo,

    pub fn lessThan(_: void, a: CalendarItem, b: CalendarItem) bool {
        // TODO: Please do something about this
        switch (a) {
            .vevent => |a1| {
                switch (b) {
                    .vevent => |b1| {
                        if (a1.dtstart) |adt| {
                            if (b1.dtstart) |bdt| {
                                return adt.lt(bdt);
                            }
                        }
                    },
                    else => {},
                }
            },
            else => {},
        }
        return false;
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
            } else if (std.mem.startsWith(u8, line, "DUE:")) {
                std.debug.print("    .due: {s}\n", .{line});
                const due = line[4..]; // Removing DUE: and DUE;
                switch (item.*) {
                    .vtodo => |*t| {
                        t.due = try parseIcsDateTime(due);
                    },
                    else => {},
                }
            } else if (std.mem.startsWith(u8, line, "DTSTART")) {
                std.debug.print("    .dstart: {s}\n", .{line});
                const dtstart = line[8..]; // Removing DTSTART: and DTSTART;
                switch (item.*) {
                    .vevent => |*e| {
                        e.dtstart = try parseIcsDateTime(dtstart);
                    },
                    else => {},
                }
            } else if (std.mem.startsWith(u8, line, "DTEND")) {
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
