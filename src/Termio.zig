pub const Position = struct {
    x: u16,
    y: u16,
};

pub const Size = Position;

const Self = @This();
in: std.fs.File = undefined,
out: std.fs.File = undefined,
oldCodePage: windows.UINT = 0,
originalOutMode: windows.DWORD = 0,
originalInMode: windows.DWORD = 0,
alternateBuffer: bool = false,

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

pub fn deinit(self: *Self) void {
    if (builtin.os.tag == .windows) {
        self.exitAlternateBuffer() catch {};
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

pub inline fn write(self: *Self, bytes: []const u8) !void {
    _ = try self.out.write(bytes);
}

pub inline fn print(self: Self, comptime format: []const u8, args: anytype) !void {
    try self.out.writer().print(format, args);
}

pub fn enterAlternateBuffer(self: *Self) !void {
    if (!self.alternateBuffer) {
        try self.write(ENTER_ALTERNATE_BUFFER);
        self.alternateBuffer = true;
    }
}

pub fn exitAlternateBuffer(self: *Self) !void {
    if (self.alternateBuffer) {
        try self.write(EXIT_ALTERNATE_BUFFER);
        self.alternateBuffer = false;
    }
}

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

pub inline fn cursorSet(self: *Self, pos: Position) !void {
    var buffer: [14]u8 = undefined;
    const output = try std.fmt.bufPrint(&buffer, CSI ++ "{d};{d}H", .{ pos.y, pos.x });
    try self.write(output);
}

pub inline fn CursorHome(self: *Self) !void {
    try self.write(SET_CURSOR_HOME);
}

pub inline fn clearScreen(self: *Self, home: bool) !void {
    try self.write(CLEAR_SCREEN);
    if (home) try self.CursorHome();
}

pub inline fn getTerminalSize(self: *Self) !Size {
    const oldPos = try self.cursorGet();
    try self.write(CSI ++ "9999;9999H");
    const pos = try self.cursorGet();

    try self.cursorSet(oldPos);
    return pos;
}

pub inline fn getKey(self: *Self) !u8 {
    var key: [1]u8 = undefined;
    _ = try self.in.read(&key);
    return key[0];
}

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

/////////////////////////
/// private functions
/////////////////////////

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
        return readTillBuffer[0..pos];
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

/////////////////////////////
/// Imports and Constants
/////////////////////////////

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

const ENTER_ALTERNATE_BUFFER: []const u8 = CSI ++ "?1049h";
const EXIT_ALTERNATE_BUFFER: []const u8 = CSI ++ "?1049l";
const CLEAR_SCREEN = CSI ++ "2J";
const SET_CURSOR_HOME = CSI ++ "1;1H";
