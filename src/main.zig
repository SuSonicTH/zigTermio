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
    for (0..10) |_| {
        const k = try term.getKey();
        try term.print("key={d} \n", .{k});
    }
}
