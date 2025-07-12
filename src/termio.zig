pub const Position = struct {
    x: u16,
    y: u16,
};

pub const Size = Position;

var alternateBuffer: bool = false;

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

        _ = try out.write(SET_CURSOR_HOME);
    }
}

pub fn deinit() void {
    if (builtin.os.tag == .windows) {
        exitAlternateBuffer() catch {};
        _ = SetConsoleMode(stdoutHandle, originalOutMode);
        _ = SetConsoleMode(stdinHandle, originalInMode);

        if (oldCodePage > 0 and oldCodePage != utf8CodePage) {
            _ = SetConsoleOutputCP(oldCodePage);
        }
    }
}

pub fn enterAlternateBuffer() !void {
    if (!alternateBuffer) {
        _ = try out.write(ENTER_ALTERNATE_BUFFER);
        alternateBuffer = true;
    }
}

pub fn exitAlternateBuffer() !void {
    if (!alternateBuffer) {
        _ = try out.write(EXIT_ALTERNATE_BUFFER);
        alternateBuffer = false;
    }
}

pub fn getCursor() !Position {
    _ = try out.write(CSI ++ "6n");
    const pos = readTill('[', 'R');
    if (instring(pos, ';')) |sep| {
        return .{
            .y = try std.fmt.parseInt(u16, pos[0..sep], 10),
            .x = try std.fmt.parseInt(u16, pos[sep + 1 ..], 10),
        };
    }
    return error.CouldNotParsePosition;
}

pub fn setCursor(pos: Position) !void {
    var buffer: [14]u8 = undefined;
    const output = try std.fmt.bufPrint(&buffer, CSI ++ "{d};{d}H", .{ pos.y, pos.x });
    _ = try out.write(output);
}

pub fn setCursorHome() !void {
    _ = try out.write(SET_CURSOR_HOME);
}

pub fn clearScreen(home: bool) !void {
    _ = try out.write(CLEAR_SCREEN);
    if (home) try setCursorHome();
}

pub fn getTerminalSize() !Size {
    const oldPos = try getCursor();
    _ = try out.write(CSI ++ "9999;9999H");
    const pos = try getCursor();
    try setCursor(oldPos);
    return pos;
}

pub fn getKey() !u8 {
    var key: [1]u8 = undefined;
    _ = try in.read(&key);
    return key[0];
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
fn readTill(comptime start: u8, comptime end: u8) []const u8 {
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
