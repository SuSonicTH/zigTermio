const std = @import("std");
const builtin = @import("builtin");

pub const TerminalSize = struct {
    width: u16,
    height: u16,
};

pub fn getTerminalSize() !TerminalSize {
    if (builtin.os.tag == .windows) {
        const info = try getConsoleScreenBufferInfo();
        return .{
            .width = @intCast(info.srWindow.Right - info.srWindow.Left + 1),
            .height = @intCast(info.srWindow.Bottom - info.srWindow.Top + 1),
        };
    } else {
        var buffer: std.posix.system.winsize = undefined;
        if (std.posix.errno(std.posix.system.ioctl(std.io.getStdOut().handle, std.posix.T.IOCGWINSZ, @intFromPtr(&buffer))) == .SUCCESS) {
            return .{
                .width = buffer.ws_col,
                .height = buffer.ws_row,
            };
        } else {
            return error.Unexpected;
        }
    }
}

pub const Position = struct {
    x: u16 = 0,
    y: u16 = 0,
};

pub fn getCursor() !Position {
    if (builtin.os.tag == .windows) {
        const info = try getConsoleScreenBufferInfo();
        return .{
            .x = @intCast(info.dwCursorPosition.X - info.srWindow.Left),
            .y = @intCast(info.dwCursorPosition.Y - info.srWindow.Top),
        };
    }
}

pub fn setCursor(position: Position) !void {
    if (builtin.os.tag == .windows) {
        var info = try getConsoleScreenBufferInfo();
        //info.dwCursorPosition.X = @intCast(position.x + @as(u16, @intCast(info.srWindow.Left)));
        //info.dwCursorPosition.Y = @intCast(position.y + @as(u16, @intCast(info.srWindow.Top)));
        info.dwCursorPosition.X = @as(i16, @intCast(position.x)) + info.srWindow.Left;
        info.dwCursorPosition.Y = @as(i16, @intCast(position.y)) + info.srWindow.Top;
        _ = try std.io.getStdOut().writer().print(">>{any}\n", .{info.srWindow});
        _ = try std.io.getStdOut().writer().print(">>{any}\n", .{info.dwCursorPosition});
        if (std.os.windows.kernel32.SetConsoleCursorPosition(std.io.getStdOut().handle, info.dwCursorPosition) != std.os.windows.TRUE) {
            return error.Unexpected;
        }
    }
}

var consoleScreenBufferInfo: std.os.windows.CONSOLE_SCREEN_BUFFER_INFO = undefined;
fn getConsoleScreenBufferInfo() !std.os.windows.CONSOLE_SCREEN_BUFFER_INFO {
    if (std.os.windows.kernel32.GetConsoleScreenBufferInfo(std.io.getStdOut().handle, &consoleScreenBufferInfo) == std.os.windows.TRUE) {
        return consoleScreenBufferInfo;
    }
    return error.Unexpected;
}
