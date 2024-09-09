const std = @import("std");
const Termio = @import("Termio.zig");

pub fn main() !void {
    _ = try std.io.getStdOut().writer().print("{any}", .{Termio.getTerminalSize()});
}
