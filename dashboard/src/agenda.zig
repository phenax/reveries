const std = @import("std");
const rl = @import("raylib");
const xml = @import("xml");
const dt = @import("datetime");
const ics_parser = @import("./ics_parser.zig");
const dtlocal = @import("./datetime.zig");

const CalendarItem = ics_parser.CalendarItem;
const Datetime = dt.datetime.Datetime;

const defaultRefreshIntervalSeconds: i64 = 60;

pub const AgendaWidget = struct {
    caldavUrl: [:0]const u8,
    alloc: std.mem.Allocator,
    refreshIntervalSeconds: i64 = defaultRefreshIntervalSeconds,
    timezone: dt.datetime.Timezone,
    dtstart: Datetime,
    dtend: Datetime,
    items: std.ArrayList(CalendarItem) = .empty,
    errorText: ?[:0]const u8 = null,
    lastFetchTimestamp: i64 = 0,

    pub fn new(alloc: std.mem.Allocator, caldavUrl: [:0]const u8, timezone: dt.datetime.Timezone) !AgendaWidget {
        const refreshIntervalSeconds = defaultRefreshIntervalSeconds;
        var agenda = AgendaWidget{
            .alloc = alloc,
            .caldavUrl = caldavUrl,
            .timezone = timezone,
            .dtstart = Datetime.now(),
            .dtend = Datetime.now(),
            .refreshIntervalSeconds = refreshIntervalSeconds,
            // Load events 1 second after start
            .lastFetchTimestamp = std.time.timestamp() - refreshIntervalSeconds + 1,
        };
        agenda.updateDateRange();
        return agenda;
    }

    pub fn update(agenda: *AgendaWidget) void {
        agenda.updateDateRange();
        agenda.refreshCalendar();
    }

    pub fn draw(agenda: AgendaWidget, font: rl.Font) !void {
        const boxY = 230;
        const boxWidth: f32 = @floatFromInt(@divFloor(rl.getScreenWidth() * 5, 9));
        const boxHeight: f32 = @floatFromInt(rl.getScreenHeight() - boxY - 20);
        const textSpacing = 1;

        var y: f32 = boxY + 16;
        const x: f32 = 16;
        const fontSize: f32 = @floatFromInt(font.baseSize);

        rl.drawLine(0, 230, @intFromFloat(boxWidth), 230, .dark_gray);

        // Draw error text
        if (agenda.errorText) |err| {
            rl.drawTextEx(font, err, rl.Vector2.init(x, y + boxHeight - 20), fontSize, textSpacing, .red);
        }

        // Empty state
        if (agenda.items.items.len == 0) {
            rl.drawTextEx(font, "<no events>", rl.Vector2.init(x, y), fontSize, textSpacing, .gray);
            return;
        }

        var titleBuf: [50:0]u8 = undefined;
        var timeStartBuf: [8:0]u8 = undefined;
        var timeEndBuf: [8:0]u8 = undefined;
        var timerangeBuf: [18:0]u8 = undefined;
        const maxTextChars = 34;
        for (agenda.items.items) |item| {
            switch (item) {
                .vevent => |e| {
                    const title = agenda.displayTitle("📅", e.title, maxTextChars, &titleBuf);
                    rl.drawTextEx(font, title, rl.Vector2.init(x, y), fontSize, textSpacing, .white);

                    const timestr = try std.fmt.bufPrintZ(
                        &timerangeBuf,
                        "{s} - {s}",
                        .{ agenda.displayTime(e.dtstart, &timeStartBuf), agenda.displayTime(e.dtend, &timeEndBuf) },
                    );
                    const width: f32 = @floatFromInt(rl.measureText(timestr, @intFromFloat(fontSize)));
                    rl.drawTextEx(font, timestr, rl.Vector2.init(boxWidth - width - x, y), fontSize, textSpacing, .white);
                },
                .vtodo => |t| {
                    const title = agenda.displayTitle("✔", t.title, maxTextChars, &titleBuf);
                    rl.drawTextEx(font, title, rl.Vector2.init(x, y), fontSize, textSpacing, .white);
                },
            }
            y = y + 30;
        }
    }

    fn refreshCalendar(agenda: *AgendaWidget) void {
        if (std.time.timestamp() - agenda.lastFetchTimestamp < agenda.refreshIntervalSeconds) return;

        std.debug.print("::::: REFRESHING AGENDA\n", .{});
        agenda.lastFetchTimestamp = std.time.timestamp();
        agenda.errorText = "";
        agenda.loadCalendarItems() catch |e| {
            agenda.errorText = std.fmt.allocPrintSentinel(agenda.alloc, "Error loading calendar items: {s}", .{@errorName(e)}, 0) catch @errorName(e);
            std.debug.print("{s}", .{@errorName(e)});
        };
    }

    pub fn updateDateRange(agenda: *AgendaWidget) void {
        // TODO: Remove shift
        var today = Datetime.now();
        today.time.hour = 0;
        today.time.minute = 0;
        today.time.second = 0;
        today.time.nanosecond = 0;
        agenda.dtstart = today.shiftDays(-10);
        agenda.dtend = today.shiftDays(10);
    }

    fn loadCalendarItems(agenda: *AgendaWidget) !void {
        for (agenda.items.items) |*item|
            item.deinit(agenda.alloc);
        agenda.items.clearAndFree(agenda.alloc);

        var events = try agenda.fetchEvents();
        defer events.deinit(agenda.alloc);
        std.mem.sort(CalendarItem, events.items, {}, CalendarItem.lessThan);
        try agenda.items.appendSlice(agenda.alloc, events.items);

        var todos = try agenda.fetchTodos();
        defer todos.deinit(agenda.alloc);
        try agenda.items.appendSlice(agenda.alloc, todos.items);
    }

    fn fetchEvents(agenda: *AgendaWidget) !std.ArrayList(CalendarItem) {
        const startDt = try dtlocal.formatISO8601Basic(agenda.alloc, agenda.dtstart);
        defer agenda.alloc.free(startDt);
        const endDt = try dtlocal.formatISO8601Basic(agenda.alloc, agenda.dtend);
        defer agenda.alloc.free(endDt);
        const filter = try std.fmt.allocPrint(agenda.alloc,
            \\<C:comp-filter name="VCALENDAR">
            \\  <C:time-range start="{s}" end="{s}"/>
            \\  <C:comp-filter name="VEVENT" />
            \\</C:comp-filter>
        , .{ startDt, endDt });
        defer agenda.alloc.free(filter);

        var events = try agenda.searchCaldavWithRetry(filter);
        defer events.deinit(agenda.alloc);

        return try filterCalendarItems(agenda.alloc, events, agenda.dtstart, agenda.dtend);
    }

    fn fetchTodos(agenda: *AgendaWidget) !std.ArrayList(CalendarItem) {
        const filter = try std.fmt.allocPrint(agenda.alloc,
            \\<C:comp-filter name="VCALENDAR">
            \\  <C:comp-filter name="VTODO" />
            \\</C:comp-filter>
        , .{});
        defer agenda.alloc.free(filter);

        var tasks = try agenda.searchCaldavWithRetry(filter);
        defer tasks.deinit(agenda.alloc);

        return try filterCalendarItems(agenda.alloc, tasks, agenda.dtstart, agenda.dtend);
    }

    fn searchCaldavWithRetry(agenda: *AgendaWidget, filter: []u8) !std.ArrayList(CalendarItem) {
        var retries: u8 = 0;
        retry: while (true) {
            retries = retries + 1;
            return agenda.searchCaldav(filter) catch |err| {
                if (retries < 5) {
                    std.debug.print("[log] retrying {d}...\n", .{retries});
                    std.Thread.sleep(1 * std.time.ns_per_s);
                    continue :retry;
                } else {
                    return err;
                }
            };
        }
    }

    fn searchCaldav(agenda: *AgendaWidget, filter: []u8) !std.ArrayList(CalendarItem) {
        var client = std.http.Client{ .allocator = agenda.alloc };
        defer client.deinit();

        const uri = try std.Uri.parse(agenda.caldavUrl);
        const host = try uri.getHostAlloc(agenda.alloc);
        const port = uri.port orelse 80;
        const path = uri.path.toRawMaybeAlloc(agenda.alloc) catch "/";
        const protocol = std.http.Client.Protocol.fromUri(uri) orelse .plain;

        var conn = try client.connect(host, port, protocol);
        defer client.connection_pool.release(conn);

        const requestBody = try std.fmt.allocPrint(agenda.alloc,
            \\<?xml version="1.0" encoding="utf-8" ?>
            \\<C:calendar-query xmlns:D="DAV:" xmlns:C="urn:ietf:params:xml:ns:caldav">
            \\  <D:prop>
            \\    <C:calendar-data/>
            \\  </D:prop>
            \\  <C:filter>
            \\    {s}
            \\  </C:filter>
            \\</C:calendar-query>
        , .{filter});
        defer agenda.alloc.free(requestBody);

        var writer = conn.writer();
        try writer.print("{s} {s} HTTP/1.1\r\n", .{ "REPORT", path });
        try writer.print("Host: {s}:{d}\r\n", .{ host, port });
        try writer.print("Authorization: {s}\r\n", .{"joe:joe"});
        try writer.print("Content-Length: {d}\r\n", .{requestBody.len});
        try writer.writeAll("Content-Type: application/xml; charset=utf-8\r\n" ++
            "Depth: 1\r\n" ++
            "Connection: close\r\n" ++
            "\r\n");
        try writer.writeAll(requestBody);
        try writer.flush();
        try conn.end();

        var reader = conn.reader();
        const responseRaw = try reader.allocRemaining(agenda.alloc, .unlimited);
        defer agenda.alloc.free(responseRaw);
        var resp = try agenda.parseResponse(responseRaw);
        std.debug.print(":::::: {s}...\n", .{responseRaw[0..@min(responseRaw.len, 500)]});

        var doc = try xml.tree.parse(agenda.alloc, &resp.body, null);
        defer doc.deinit(agenda.alloc);

        var items: std.ArrayList(CalendarItem) = .empty;

        var walker = doc.walkElementsByName("C:calendar-data");
        while (walker.next()) |el| {
            var newItems = try ics_parser.parseIcs(el.text(), agenda.alloc);
            defer newItems.deinit(agenda.alloc);
            try items.appendSlice(agenda.alloc, newItems.items);
        }

        return items;
    }

    // Manual filter needed because caldav api is dumb
    fn filterCalendarItems(alloc: std.mem.Allocator, events: std.ArrayList(CalendarItem), dtstart: Datetime, dtend: Datetime) !std.ArrayList(CalendarItem) {
        var filteredItems: std.ArrayList(CalendarItem) = .empty;

        for (events.items) |item| {
            switch (item) {
                .vtodo => |*t| {
                    if (t.due) |due| {
                        if (dtlocal.between(due, dtstart, dtend)) {
                            try filteredItems.append(alloc, item);
                        }
                    }
                },
                .vevent => |*e| {
                    if (e.dtstart) |evStart| {
                        if (dtlocal.between(evStart, dtstart, dtend)) {
                            try filteredItems.append(alloc, item);
                        } else if (e.dtend) |evEnd| {
                            if (dtlocal.between(evEnd, dtstart, dtend)) {
                                try filteredItems.append(alloc, item);
                            }
                        }
                    }
                },
            }
        }

        return filteredItems;
    }

    const Resp = struct {
        head: std.http.Client.Response.Head,
        body: std.Io.Reader,
    };

    fn parseResponse(_: *AgendaWidget, response: []u8) !Resp {
        var p = std.http.HeadParser{};
        const readLen = p.feed(response);
        if (p.state != .finished) unreachable;

        const head = try std.http.Client.Response.Head.parse(response[0..readLen]);
        const responseBody = std.Io.Reader.fixed(response[readLen..]);
        return Resp{ .head = head, .body = responseBody };
    }

    pub fn deinit(agenda: *AgendaWidget) !void {
        for (agenda.items.items) |*item|
            item.deinit(agenda.alloc);
        agenda.items.clearAndFree(agenda.alloc);
        agenda.items.deinit(agenda.alloc);
    }

    fn displayTime(agenda: AgendaWidget, datetime: ?Datetime, buf: []u8) [*:0]const u8 {
        if (datetime) |time| {
            const timeAdjusted = time.shiftTimezone(agenda.timezone);
            return dtlocal.formatTime(timeAdjusted, buf) catch "<error>";
        } else {
            return "";
        }
    }

    fn displayTitle(_: AgendaWidget, prefix: []const u8, title: []u8, maxTextChars: usize, buf: []u8) [:0]const u8 {
        const ellipsis = if (title.len > maxTextChars) "..." else "";
        const titletrimmed = if (title.len > maxTextChars) title[0..maxTextChars] else title;
        return std.fmt.bufPrintZ(buf, "{s} {s}{s}", .{ prefix, titletrimmed, ellipsis }) catch "<error>";
    }
};
