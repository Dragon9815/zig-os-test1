const instr = @import("instr.zig");
const std = @import("std");

pub const SerialPort = struct {
    base_port: u16,

    pub fn init(port: u16) !SerialPort {
        instr.out8(port + 1, 0x00);
        instr.out8(port + 3, 0x80);
        instr.out8(port + 0, 0x03);
        instr.out8(port + 1, 0x00);
        instr.out8(port + 3, 0x03);
        instr.out8(port + 2, 0xC7);
        instr.out8(port + 4, 0x0B);
        instr.out8(port + 4, 0x1E);
        instr.out8(port + 0, 0xAE);

        if (instr.in8(port) != 0xAE) {
            return error.LoopbackTestError;
        }

        instr.out8(port + 4, 0x0F);
        return .{ .base_port = port };
    }

    pub fn isTxBufferEmpty(self: SerialPort) bool {
        return (instr.in8(self.base_port + 5) & 0x20) != 0;
    }

    pub fn writeChar(self: SerialPort, c: u8) void {
        while (!self.isTxBufferEmpty()) {}
        instr.out8(self.base_port, c);
    }

    pub const Writer = std.io.Writer(SerialPort, error{}, writeFn);
    pub fn writer(self: SerialPort) Writer {
        return Writer{ .context = self };
    }

    fn writeFn(context: SerialPort, bytes: []const u8) error{}!usize {
        for (bytes) |b| {
            context.writeChar(b);
        }
        return bytes.len;
    }
};
