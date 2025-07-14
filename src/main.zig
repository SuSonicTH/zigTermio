const std = @import("std");
const Termio = @import("termio.zig");

pub fn main() !void {
    try Termio.init();
    defer Termio.deinit();

    try Termio.enterAlternateBuffer();
    const writer = std.io.getStdOut().writer();

    const size = try Termio.getTerminalSize();
    try Termio.drawBox(.{ .x = 1, .y = 1 }, size);
    try Termio.setCursor(.{ .x = 2, .y = 2 });
    _ = try writer.print("size = {d}x{d}", .{ size.x, size.y });
    _ = try Termio.getKey();
}
