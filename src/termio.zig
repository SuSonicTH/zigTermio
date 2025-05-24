const std = @import("std");
const builtin = @import("builtin");
const windows = std.os.windows;

extern "kernel32" fn GetConsoleMode(hConsoleHandle: windows.HANDLE, lpMode: *windows.DWORD) callconv(windows.WINAPI) windows.BOOL;
extern "kernel32" fn SetConsoleMode(hConsoleHandle: windows.HANDLE, dwMode: windows.DWORD) callconv(windows.WINAPI) windows.BOOL;

extern "kernel32" fn GetConsoleOutputCP() callconv(windows.WINAPI) windows.UINT;
extern "kernel32" fn SetConsoleOutputCP(codepage: windows.UINT) callconv(windows.WINAPI) windows.BOOL;

const utf8CodePage: windows.UINT = 65001;
var oldCodePage: windows.UINT = 0;

var stdoutHandle: windows.HANDLE = undefined;
var originalOutMode: windows.DWORD = undefined;
var out: std.fs.File = undefined;

const ENABLE_VIRTUAL_TERMINAL_PROCESSING: windows.DWORD = 0x4;
const ENABLE_PROCESSED_OUTPUT: windows.DWORD = 0x0001;
const OUTPUT_MODE = ENABLE_VIRTUAL_TERMINAL_PROCESSING | ENABLE_PROCESSED_OUTPUT;

var stdinHandle: windows.HANDLE = undefined;
var originalInMode: windows.DWORD = undefined;
var in: std.fs.File = undefined;

const ENABLE_VIRTUAL_TERMINAL_INPUT: windows.DWORD = 0x200;
const ENABLE_WINDOW_INPUT: windows.DWORD = 0x0008;
const ENABLE_MOUSE_INPUT: windows.DWORD = 0x0010;
const ENABLE_EXTENDED_FLAGS: windows.DWORD = 0x0080;
const INPUT_MODE = ENABLE_VIRTUAL_TERMINAL_INPUT | ENABLE_WINDOW_INPUT | ENABLE_MOUSE_INPUT | ENABLE_EXTENDED_FLAGS;

const ESC: []const u8 = "\x1b";
const CSI: []const u8 = ESC ++ "[";

const ENTER_ALTERNATE_BUFFER: []const u8 = CSI ++ "?1049h";
const EXIT_ALTERNATE_BUFFER: []const u8 = CSI ++ "?1049l";
const CLEAR_SCREEN = CSI ++ "2J";
const SET_CURSOR_HOME = CSI ++ "1;1H";

pub fn init() !void {
    if (builtin.os.tag == .windows) {
        oldCodePage = GetConsoleOutputCP();
        if (oldCodePage != utf8CodePage) {
            _ = SetConsoleOutputCP(utf8CodePage);
        }

        stdoutHandle = windows.kernel32.GetStdHandle(windows.STD_OUTPUT_HANDLE) orelse return error.NoStandardHandleAttached;
        if (GetConsoleMode(stdoutHandle, &originalOutMode) == windows.FALSE) return error.Unexpected;
        if (SetConsoleMode(stdoutHandle, OUTPUT_MODE) == windows.FALSE) return error.Unexpected;

        stdinHandle = windows.kernel32.GetStdHandle(windows.STD_INPUT_HANDLE) orelse return error.NoStandardHandleAttached;
        if (GetConsoleMode(stdinHandle, &originalInMode) == windows.FALSE) return error.Unexpected;
        if (SetConsoleMode(stdinHandle, INPUT_MODE) == windows.FALSE) return error.Unexpected;

        out = std.io.getStdOut();
        in = std.io.getStdIn();
        write(ENTER_ALTERNATE_BUFFER);
        write(SET_CURSOR_HOME);
    }
}

inline fn write(command: []const u8) void {
    _ = out.write(command) catch {};
}

pub fn deinit() void {
    if (builtin.os.tag == .windows) {
        //write(EXIT_ALTERNATE_BUFFER);
        _ = SetConsoleMode(stdoutHandle, originalOutMode);
        _ = SetConsoleMode(stdinHandle, originalInMode);

        if (oldCodePage > 0 and oldCodePage != utf8CodePage) {
            _ = SetConsoleOutputCP(oldCodePage);
        }
    }
}

pub const Position = struct {
    x: u16,
    y: u16,
};

var readTillBuffer: [128]u8 = undefined;
pub fn readTill(comptime start: u8, comptime end: u8) []const u8 {
    var pos: u8 = 0;
    while ((in.reader().readByte() catch {
        return readTillBuffer[0..pos];
    }) != start) {}
    while (pos < readTillBuffer.len) {
        readTillBuffer[pos] = in.reader().readByte() catch {
            return readTillBuffer[0..pos];
        };
        if (readTillBuffer[pos] == end) {
            return readTillBuffer[0..pos];
        }
        pos += 1;
    }
    return readTillBuffer[1..pos];
}

pub fn getTerminalSize() Position {
    write(CSI ++ "9999;9999H");
    write(CSI ++ "6n");
    const size = readTill('[', 'R');
    write("\n");
    write(SET_CURSOR_HOME);
    for (size, 0..) |c, i| {
        out.writer().print("{d}:{d}:{c}\n", .{ i, c, c }) catch {};
    }
    out.writer().print("got:'{s}'\n", .{size}) catch {};
    write(size);
    return .{
        .x = 0,
        .y = 0,
    };
}

//pub const TerminalSize = struct {
//    width: u16,
//    height: u16,
//};
//
//pub fn getTerminalSize() !TerminalSize {
//    if (builtin.os.tag == .windows) {
//        const info = try getConsoleScreenBufferInfo();
//        return .{
//            .width = @intCast(info.srWindow.Right - info.srWindow.Left + 1),
//            .height = @intCast(info.srWindow.Bottom - info.srWindow.Top + 1),
//        };
//    } else {
//        var buffer: std.posix.system.winsize = undefined;
//        if (std.posix.errno(std.posix.system.ioctl(std.io.getStdOut().handle, std.posix.T.IOCGWINSZ, @intFromPtr(&buffer))) == .SUCCESS) {
//            return .{
//                .width = buffer.ws_col,
//                .height = buffer.ws_row,
//            };
//        } else {
//            return error.Unexpected;
//        }
//    }
//}
//
//pub const Position = struct {
//    x: u16 = 0,
//    y: u16 = 0,
//};
//
//pub fn getCursor() !Position {
//    if (builtin.os.tag == .windows) {
//        const info = try getConsoleScreenBufferInfo();
//        return .{
//            .x = @intCast(info.dwCursorPosition.X - info.srWindow.Left),
//            .y = @intCast(info.dwCursorPosition.Y - info.srWindow.Top),
//        };
//    }
//}
//
//pub fn setCursor(position: Position) !void { //todo: check for valid position?
//    if (builtin.os.tag == .windows) {
//        var info = try getConsoleScreenBufferInfo();
//        info.dwCursorPosition.X = @as(i16, @intCast(position.x)) + info.srWindow.Left;
//        info.dwCursorPosition.Y = @as(i16, @intCast(position.y)) + info.srWindow.Top;
//        if (std.os.windows.kernel32.SetConsoleCursorPosition(std.io.getStdOut().handle, info.dwCursorPosition) != std.os.windows.TRUE) {
//            return error.Unexpected;
//        }
//    }
//}
//
//const CONSOLE_CURSOR_INFO = extern struct {
//    dwSize: std.os.windows.DWORD,
//    bVisible: std.os.windows.BOOL,
//};
//
//extern "kernel32" fn GetConsoleCursorInfo(hConsoleOutput: std.os.windows.HANDLE, lpConsoleCursorInfo: *CONSOLE_CURSOR_INFO) callconv(std.os.windows.WINAPI) std.os.windows.BOOL;
//extern "kernel32" fn SetConsoleCursorInfo(hConsoleOutput: std.os.windows.HANDLE, lpConsoleCursorInfo: *CONSOLE_CURSOR_INFO) callconv(std.os.windows.WINAPI) std.os.windows.BOOL;
//
//pub fn setCursorVisible(visible: bool) !void {
//    if (builtin.os.tag == .windows) {
//        var info: CONSOLE_CURSOR_INFO = undefined;
//        if (GetConsoleCursorInfo(std.io.getStdOut().handle, &info) == std.os.windows.TRUE) {
//            info.bVisible = if (visible) std.os.windows.TRUE else std.os.windows.FALSE;
//            if (SetConsoleCursorInfo(std.io.getStdOut().handle, &info) == std.os.windows.TRUE) {
//                return;
//            }
//        }
//        return error.Unexpected;
//    }
//}
//
//var consoleScreenBufferInfo: std.os.windows.CONSOLE_SCREEN_BUFFER_INFO = undefined;
//fn getConsoleScreenBufferInfo() !std.os.windows.CONSOLE_SCREEN_BUFFER_INFO {
//    if (std.os.windows.kernel32.GetConsoleScreenBufferInfo(std.io.getStdOut().handle, &consoleScreenBufferInfo) == std.os.windows.TRUE) {
//        return consoleScreenBufferInfo;
//    }
//    return error.Unexpected;
//}
//
