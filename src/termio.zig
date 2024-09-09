const std = @import("std");
const builtin = @import("builtin");

pub const TerminalSize = struct {
    width: u16,
    height: u16,
};

pub fn getTerminalSize() !TerminalSize {
    if (builtin.os.tag == .windows) {
        var buffer: std.os.windows.CONSOLE_SCREEN_BUFFER_INFO = undefined;

        if (std.os.windows.kernel32.GetConsoleScreenBufferInfo(std.io.getStdOut().handle, &buffer) == std.os.windows.TRUE) {
            return .{
                .width = @intCast(buffer.srWindow.Right - buffer.srWindow.Left + 1),
                .height = @intCast(buffer.srWindow.Bottom - buffer.srWindow.Top + 1),
            };
        }
    } else {
        var buffer: std.posix.system.winsize = undefined;
        if (std.posix.errno(std.posix.system.ioctl(std.io.getStdOut().handle, std.posix.T.IOCGWINSZ, @intFromPtr(&buffer))) == .SUCCESS) {
            return .{
                .width = buffer.ws_col,
                .height = buffer.ws_row,
            };
        }
    }
    return error.Unexpected;
}
