const std = @import("std");
const Termio = @import("Termio.zig");

pub fn main() !void {
    const size = try Termio.getTerminalSize();
    _ = try std.io.getStdOut().writer().print("{any}\n", .{size});
    _ = try std.io.getStdOut().writer().print("{any}\n", .{Termio.getCursor()});
    try Termio.setCursor(.{ .y = 2 });
    _ = try std.io.getStdOut().writer().print("xxxxx  CURSOR SET  xxxxx\n", .{});

    try Termio.setCursorVisible(false);
    _ = try std.io.getStdIn().reader().readByte();
    _ = try std.io.getStdIn().reader().readByte();
    _ = try std.io.getStdIn().reader().readByte();
    _ = try std.io.getStdIn().reader().readByte();
    try Termio.setCursorVisible(true);
    try Termio.setCursor(.{ .y = size.height - 2 });
    _ = try std.io.getStdOut().writer().print("{any}\n", .{Termio.getCursor()});
}
