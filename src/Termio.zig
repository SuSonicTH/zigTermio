//! This module provides functions for ansi terminal control

/// this represents a position on the screen
pub const Position = struct {
    x: u16 = 0,
    y: u16 = 0,
};

pub const Size = Position;

const Self = @This();
in: std.fs.File = undefined,
out: std.fs.File = undefined,
oldCodePage: windows.UINT = 0,
originalOutMode: windows.DWORD = 0,
originalInMode: windows.DWORD = 0,
alternateBuffer: bool = false,

/// initializes the Termio struct, has to be called before anything else
/// you have to call deinit before program exist
pub fn init() !Self {
    if (builtin.os.tag == .windows) {
        var self: Self = .{
            .out = std.io.getStdOut(),
            .in = std.io.getStdIn(),
        };

        self.oldCodePage = GetConsoleOutputCP();
        if (self.oldCodePage != utf8CodePage) {
            _ = SetConsoleOutputCP(utf8CodePage);
        }

        const stdoutHandle = windows.kernel32.GetStdHandle(windows.STD_OUTPUT_HANDLE) orelse return error.NoStandardHandleAttached;
        if (GetConsoleMode(stdoutHandle, &self.originalOutMode) == windows.FALSE) return error.Unexpected;
        if (SetConsoleMode(stdoutHandle, OUTPUT_MODE) == windows.FALSE) return error.Unexpected;

        const stdinHandle = windows.kernel32.GetStdHandle(windows.STD_INPUT_HANDLE) orelse return error.NoStandardHandleAttached;
        if (GetConsoleMode(stdinHandle, &self.originalInMode) == windows.FALSE) return error.Unexpected;
        if (SetConsoleMode(stdinHandle, INPUT_MODE) == windows.FALSE) return error.Unexpected;

        return self;
    }
}

/// resets the terminal to the same state as before
pub fn deinit(self: *Self) void {
    self.exitAlternateBuffer() catch {};

    if (builtin.os.tag == .windows) {
        if (windows.kernel32.GetStdHandle(windows.STD_OUTPUT_HANDLE)) |stdoutHandle| {
            _ = SetConsoleMode(stdoutHandle, self.originalOutMode);
        }
        if (windows.kernel32.GetStdHandle(windows.STD_INPUT_HANDLE)) |stdinHandle| {
            _ = SetConsoleMode(stdinHandle, self.originalInMode);
        }

        if (self.oldCodePage > 0 and self.oldCodePage != utf8CodePage) {
            _ = SetConsoleOutputCP(self.oldCodePage);
        }
    }
}

/// convinence function to write bytes to the terminal
/// works as normal write but doeas not return the bytes written
pub inline fn write(self: *Self, bytes: []const u8) !void {
    _ = try self.out.write(bytes);
}

/// convinence function to print at the current cursor position
/// just calls standard print
pub inline fn print(self: Self, comptime format: []const u8, args: anytype) !void {
    try self.out.writer().print(format, args);
}

/// enters an alternate buffer and clears the screen
/// this saves the original text that was displayed before which is restored with exitAlternateBuffer
/// exitAlternateBuffer will be automatically called on deinit
pub fn enterAlternateBuffer(self: *Self) !void {
    if (!self.alternateBuffer) {
        try self.write(CSI ++ "?1049h");
        self.alternateBuffer = true;
    }
}

/// this restores the original text that was displayed before enterAlternateBuffer
/// exitAlternateBuffer will be automatically called on deinit
pub fn exitAlternateBuffer(self: *Self) !void {
    if (self.alternateBuffer) {
        try self.write(CSI ++ "?1049l");
        self.alternateBuffer = false;
    }
}

///////////////// Cursor /////////////////

/// get the current position of the cursor on the screen
pub inline fn cursorGet(self: *Self) !Position {
    try self.write(CSI ++ "6n");
    const pos = self.readTill('[', 'R');
    if (instring(pos, ';')) |sep| {
        return .{
            .y = try std.fmt.parseInt(u16, pos[0..sep], 10),
            .x = try std.fmt.parseInt(u16, pos[sep + 1 ..], 10),
        };
    }
    return error.CouldNotParsePosition;
}

/// sets the current position of the cursor on the screen
pub inline fn cursorSet(self: *Self, pos: Position) !void {
    var buffer: [14]u8 = undefined;
    const output = try std.fmt.bufPrint(&buffer, CSI ++ "{d};{d}H", .{ pos.y, pos.x });
    try self.write(output);
}

pub inline fn cursorSetHorizontal(self: *Self, n: u16) !void {
    var buffer: [14]u8 = undefined;
    const output = try std.fmt.bufPrint(&buffer, CSI ++ "{d}G", .{n});
    try self.write(output);
}

pub inline fn cursorSave(self: *Self) !void {
    try self.write(CSI ++ "s");
}

pub inline fn cursorRestore(self: *Self) !void {
    try self.write(CSI ++ "u");
}
pub inline fn cursorHome(self: *Self) !void {
    try self.write(CSI ++ "1;1H");
}

pub inline fn cursorUp(self: *Self, n: u16) !void {
    try self.print(CSI ++ "{d}A", .{n});
}

pub inline fn cursorDown(self: *Self, n: u16) !void {
    try self.print(CSI ++ "{d}B", .{n});
}

pub inline fn cursorRight(self: *Self, n: u16) !void {
    try self.print(CSI ++ "{d}C", .{n});
}

pub inline fn cursorLeft(self: *Self, n: u16) !void {
    try self.print(CSI ++ "{d}D", .{n});
}

pub inline fn cursorNextLine(self: *Self, n: u16) !void {
    try self.print(CSI ++ "{d}E", .{n});
}

pub inline fn cursorPreviousLine(self: *Self, n: u16) !void {
    try self.print(CSI ++ "{d}F", .{n});
}

///////////////// Screen /////////////////

pub inline fn screenClearDown(self: *Self) !void {
    try self.write(CSI ++ "0J");
}

pub inline fn screenClearUp(self: *Self) !void {
    try self.write(CSI ++ "1J");
}

pub inline fn screenClear(self: *Self) !void {
    try self.write(CSI ++ "2J");
}

pub inline fn screenClearAndScrollBack(self: *Self) !void {
    try self.write(CSI ++ "3J");
}

pub inline fn screenGetSize(self: *Self) !Size {
    try self.cursorSave();
    defer self.cursorRestore() catch unreachable;

    try self.write(CSI ++ "9999;9999H");
    return try self.cursorGet();
}

pub inline fn screenClearLineRight(self: *Self) !void {
    try self.write(CSI ++ "0K");
}

pub inline fn screenClearLineLeft(self: *Self) !void {
    try self.write(CSI ++ "1K");
}

pub inline fn screenClearLine(self: *Self) !void {
    try self.write(CSI ++ "2K");
}

///////////////// Input /////////////////

pub inline fn getKey(self: *Self) !u8 {
    var key: [1]u8 = undefined;
    _ = try self.in.read(&key);
    return key[0];
}

///////////////// Misc /////////////////

pub inline fn drawBox(self: *Self, topLeft: Position, bottomRight: Position) !void {
    const oldPos = try self.cursorGet();

    try self.cursorSet(topLeft);
    try self.write("┌");
    for (topLeft.x + 1..bottomRight.x) |_| {
        try self.write("─");
    }
    try self.write("┐");

    try self.cursorSet(.{ .x = topLeft.x, .y = bottomRight.y });
    try self.write("└");
    for (topLeft.x + 1..bottomRight.x) |_| {
        try self.write("─");
    }
    try self.write("┘");

    for (topLeft.y + 1..bottomRight.y) |y| {
        try self.cursorSet(.{ .x = topLeft.x, .y = @intCast(y) });
        try self.write("│");
        try self.cursorSet(.{ .x = bottomRight.x, .y = @intCast(y) });
        try self.write("│");
    }
    try self.cursorSet(oldPos);
}

///////////////// private functions /////////////////

fn instring(string: []const u8, char: u8) ?usize {
    for (0..string.len) |i| {
        if (string[i] == char) {
            return i;
        }
    }
    return null;
}

var readTillBuffer: [128]u8 = undefined;
fn readTill(self: *Self, comptime start: u8, comptime end: u8) []const u8 {
    var pos: u8 = 0;
    while ((self.in.reader().readByte() catch {
        return readTillBuffer[0..0];
    }) != start) {}

    while (pos < readTillBuffer.len) {
        readTillBuffer[pos] = self.in.reader().readByte() catch {
            return readTillBuffer[0..pos];
        };
        if (readTillBuffer[pos] == end) {
            return readTillBuffer[0..pos];
        }
        pos += 1;
    }
    return readTillBuffer[1..pos];
}

///////////////// Imports and Constants /////////////////

const std = @import("std");
const builtin = @import("builtin");
const windows = std.os.windows;

extern "kernel32" fn GetConsoleMode(hConsoleHandle: windows.HANDLE, lpMode: *windows.DWORD) callconv(windows.WINAPI) windows.BOOL;
extern "kernel32" fn SetConsoleMode(hConsoleHandle: windows.HANDLE, dwMode: windows.DWORD) callconv(windows.WINAPI) windows.BOOL;

extern "kernel32" fn GetConsoleOutputCP() callconv(windows.WINAPI) windows.UINT;
extern "kernel32" fn SetConsoleOutputCP(codepage: windows.UINT) callconv(windows.WINAPI) windows.BOOL;

const utf8CodePage: windows.UINT = 65001;

const ENABLE_VIRTUAL_TERMINAL_PROCESSING: windows.DWORD = 0x4;
const ENABLE_PROCESSED_OUTPUT: windows.DWORD = 0x0001;
const OUTPUT_MODE = ENABLE_VIRTUAL_TERMINAL_PROCESSING | ENABLE_PROCESSED_OUTPUT;

const ENABLE_VIRTUAL_TERMINAL_INPUT: windows.DWORD = 0x200;
const ENABLE_WINDOW_INPUT: windows.DWORD = 0x0008;
const ENABLE_MOUSE_INPUT: windows.DWORD = 0x0010;
const ENABLE_EXTENDED_FLAGS: windows.DWORD = 0x0080;
const INPUT_MODE = ENABLE_VIRTUAL_TERMINAL_INPUT | ENABLE_WINDOW_INPUT | ENABLE_MOUSE_INPUT | ENABLE_EXTENDED_FLAGS;

const ESC: []const u8 = "\x1b";
const CSI: []const u8 = ESC ++ "[";
