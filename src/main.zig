const std = @import("std");

const json = std.json;

const net = std.net;

const Allocator = std.mem.Allocator;

pub fn main() !void {
    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();
    defer bw.flush() catch {}; // don't forget to flush!

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var hash = std.StringHashMap(*const fn (num1: i32, num2: i32) i64).init(allocator);

    try hash.put("add", addNum);

    var a = hash.get("add");
    if (a) |add| {
        try stdout.print("add: {d}\n", .{add(1, 3)});
    } else {
        try stdout.print(":( \n", .{});
    }
}

fn addNum(num1: i32, num2: i32) i64 {
    return num1 + num2;
}

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}
