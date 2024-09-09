const std = @import("std");
const Termio = @import("Termio.zig");

pub fn main() !void {
    const size = try Termio.getTerminalSize();
    _ = try std.io.getStdOut().writer().print("{any}\n", .{size});
    _ = try std.io.getStdOut().writer().print("{any}\n", .{Termio.getCursor()});
    try Termio.setCursor(.{});
    _ = try std.io.getStdOut().writer().print("    CURSOR SET    ", .{});

    try Termio.setCursor(.{ .y = size.height - 1 });
    _ = try std.io.getStdOut().writer().print("{any}\n", .{Termio.getCursor()});
}
