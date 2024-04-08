const std = @import("std");

const height = 25;
const width = 80;

const Position = struct {
    x: u16,
    y: u16,

    fn toIdx(self: Position) usize {
        return self.y * width + self.x;
    }

    fn advance(self: *Position) bool {
        self.x += 1;
        if (self.x >= width) {
            return self.newline();
        }
        return false;
    }

    fn newline(self: *Position) bool {
        self.x = 0;
        self.y += 1;
        if (self.y >= height) {
            // clamp
            self.y = height - 1;
            return true;
        }
        return false;
    }
};

var position: Position = .{
    .x = 0,
    .y = 0,
};

var buffer = @as([*]volatile u16, @ptrFromInt(0xB8000));

pub fn init() void {
    clear();
}

pub fn clear() void {
    @memset(buffer[0..(height * width)], (0x0700 | ' '));
}

fn putChar(pos: Position, c: u8) void {
    buffer[pos.toIdx()] = 0x0700 | @as(u16, c);
}

fn writeCharOrControl(c: u8) void {
    if (c == '\n') {
        _ = position.newline();
    } else if (c > 0 and c < ' ') {
        putChar(position, '^');
        _ = position.advance();
        putChar(position, '0' + c);
        _ = position.advance();
    } else if (c == 127) {
        putChar(position, '^');
        _ = position.advance();
        putChar(position, 'Z');
        _ = position.advance();
    } else {
        putChar(position, c);
        _ = position.advance();
    }
}

fn writeString(s: []const u8) void {
    for (s) |c| {
        writeCharOrControl(c);
    }
}

fn writeCallback(_: void, s: []const u8) !usize {
    writeString(s);
    return s.len;
}

const Writer = std.io.Writer(void, error{}, writeCallback);
pub const writer = Writer{ .context = {} };
