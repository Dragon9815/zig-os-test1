const ALIGN = 1 << 0;
const MEMINFO = 1 << 1;
const MAGIC = 0x1BADB002;
const FLAGS = ALIGN | MEMINFO;

const MultibootHeader = extern struct {
    magic: i32 = MAGIC,
    flags: i32,
    checksum: i32,
};

export var multiboot align(4) linksection(".multiboot") = MultibootHeader{
    .flags = FLAGS,
    .checksum = -(MAGIC + FLAGS),
};

const std = @import("std");
const vga = @import("vga.zig");

pub const std_options = .{
    .log_level = .info,
    .logFn = logFn,
};

pub fn logFn(
    comptime level: std.log.Level,
    comptime scope: @TypeOf(.EnumLiteral),
    comptime format: []const u8,
    args: anytype,
) void {
    const scope_prefix = "(" ++ @tagName(scope) ++ "): ";
    const prefix = "[" ++ comptime level.asText() ++ "] " ++ scope_prefix;
    std.fmt.format(vga.writer, prefix ++ format ++ "\n", args) catch unreachable;
}

const kernel_log = std.log.scoped(.kernel);

export fn kmain(mb_magic: u32, mb_ptr: u32) callconv(.C) void {
    vga.init();
    kernel_log.info("starting zig kernel", .{});
    kernel_log.info("multiboot: magic=0x{X:0>8}, ptr=0x{X:0>8}", .{ mb_magic, mb_ptr });
}
