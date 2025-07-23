const std = @import("std");
const Termio = @import("Termio.zig");

pub fn main() !void {
    var term = try Termio.init();
    defer term.deinit();

    try term.enterAlternateBuffer();
    const size = try term.screenGetSize();
    try term.drawBox(.{ .x = 1, .y = 1 }, size);

    try term.cursorSet(.{ .x = 2, .y = 2 });
    try term.print("size = {d}x{d}", .{ size.x, size.y });

    try term.drawRoundBox(.{ .x = 20, .y = 10 }, .{ .x = 25, .y = 12 });
    try term.cursorSet(.{ .x = 22, .y = 11 });
    try term.print("OK", .{});

    try term.drawBox(.{ .x = 20, .y = 13 }, .{ .x = 25, .y = 15 });
    try term.cursorSet(.{ .x = 22, .y = 14 });
    try term.print("OK", .{});

    _ = try term.getKey();
}
