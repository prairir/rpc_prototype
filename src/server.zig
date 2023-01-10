const std = @import("std");

const json = std.json;

const net = std.net;

const Allocator = std.mem.Allocator;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var s = try server.init(allocator);
    defer s.deinit() catch {};
    const stdout_file = std.io.getStdOut().writer();
    try stdout_file.print("{d}\n", .{s.add(1, 2)});
}

// allocates memory, deinit to deallocate
const server = struct {
    allocator: Allocator,
    cache: std.StringHashMap(*const fn (i32, i32) i64),

    const Self = @This();

    pub fn init(allocator: Allocator) !Self {
        var cache = std.StringHashMap(*const fn (i32, i32) i64).init(allocator);
        try cache.put("add", Self.addNum);

        return .{
            .allocator = allocator,
            .cache = cache,
        };
    }

    pub fn deinit(self: *Self) !void {
        self.cache.deinit();
    }

    fn addNum(num1: i32, num2: i32) i64 {
        return num1 + num2;
    }

    pub fn add(self: *Self, num1: i32, num2: i32) i64 {
        var a = self.cache.get("add");
        if (a) |ad| {
            return ad(num1, num2);
        } else {
            return 0;
        } // TODO: figure this out
    }

    pub fn run(self: *Self, ipAddr: []u8) !void {
        //var buf: [100]u8 = undefined;
        while (true) {
            var ip = try net.Address.parseIp(ipAddr, 0);
            var conn = try self.tcpServer.accept(ip);
            _ = conn.accept();
        }
    }
};
