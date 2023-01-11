const std = @import("std");

const json = std.json;

const net = std.net;

const Allocator = std.mem.Allocator;

const types = @import("types.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var s = try server.init(allocator);
    defer s.deinit() catch {};

    try s.register("add"[0..], server.handleAdd);

    try s.run("127.0.0.1"[0..]);
}

const funSig = *const fn (*net.Stream.Reader, *net.Stream.Writer) anyerror!void;

// allocates memory, deinit to deallocate
const server = struct {
    allocator: Allocator,

    funCache: std.StringHashMap(funSig),

    const Self = @This();

    pub fn init(allocator: Allocator) !Self {
        var funCache = std.StringHashMap(funSig).init(allocator);
        try funCache.put("add", Self.handleAdd);

        return .{
            .allocator = allocator,
            .funCache = funCache,
        };
    }

    pub fn deinit(self: *Self) !void {
        self.funCache.deinit();
    }

    pub fn register(self: *Self, name: []const u8, fun: funSig) !void {
        try self.funCache.put(name, fun);
    }

    fn handleAdd(r: *net.Stream.Reader, w: *net.Stream.Writer) anyerror!void {
        const stdout_file = std.io.getStdOut().writer();

        var buf: [100]u8 = undefined;

        try stdout_file.print("{s}\n", .{"bruhhh"});

        var n = try r.read(&buf);
        try stdout_file.print("{s}\n", .{buf[0..n]});

        var jsonStream = json.TokenStream.init(buf[0..n]);
        const jsonParsed = json.parse(types.addParams, &jsonStream, .{}) catch |err| {
            try stdout_file.print("parsinng error: \"{any}\"\n", .{@errorName(err)});
            try stdout_file.print("parsing error: {any}\n", .{@errorReturnTrace()});

            _ = try w.write("Invalid procedure call");
            return;
        };

        var result = jsonParsed.num1 + jsonParsed.num2;

        var outParams = types.addReturnVals{
            .ret = result,
        };

        var buf2: [100]u8 = undefined;
        var fba = std.heap.FixedBufferAllocator.init(&buf2);
        var string = std.ArrayList(u8).init(fba.allocator());
        try json.stringify(outParams, .{}, string.writer());

        try stdout_file.print("{s}\n", .{string.items});
        try w.print("{s}\n", .{string.items});
    }

    pub fn run(self: *Self, ipAddr: []const u8) !void {
        var tcpServer = net.StreamServer.init(.{});
        defer tcpServer.deinit();

        var ip = try net.Address.parseIp(ipAddr, 0);
        try tcpServer.listen(ip);

        const stdout_file = std.io.getStdOut().writer();
        try stdout_file.print("listening at \"{}\"\n", .{tcpServer.listen_address});

        var buf: [100]u8 = undefined;
        while (true) {
            var conn = try tcpServer.accept();

            while (true) {
                var reader = conn.stream.reader();
                var writer = conn.stream.writer();

                var name = try reader.readUntilDelimiter(&buf, ':');
                try stdout_file.print("name: `{s}`\n", .{name});

                var handler = self.funCache.get(name);
                if (handler) |h| {
                    try stdout_file.print("called: `{s}`", .{h});
                    h(&reader, &writer) catch |err| switch (err) {
                        error.EndOfStream => break,
                        else => return err,
                    };
                } else {
                    try writer.print("procedure \"{s}\" not found", .{name});
                    try stdout_file.print("procedure \"{s}\" not found", .{name});
                }
            }
        }
    }
};
