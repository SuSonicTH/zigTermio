const std = @import("std");
const Termio = @import("Termio.zig");

pub fn main() !void {
    try Termio.init();
    defer Termio.deinit();
    try Termio.enterAlternateBuffer();
    const writer = std.io.getStdOut().writer();

    _ = try writer.write("HELLO\n");
    _ = try writer.write("HELLO2\n");
    const size = try Termio.getTerminalSize();
    _ = try writer.print("size = {d}x{d}", .{ size.x, size.y });
    _ = try Termio.getKey();

    try Termio.clearScreen(true);
    _ = try writer.print("screen cleard", .{});
    _ = try Termio.getKey();
}
