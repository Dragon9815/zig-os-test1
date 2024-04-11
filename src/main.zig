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
const serial = @import("serial.zig");
const gdt = @import("gdt.zig");
const idt = @import("idt.zig");
const interrupt = @import("interrupt.zig");
const exceptions = @import("exceptions.zig");

pub const std_options = .{
    .log_level = .info,
    .logFn = logFn,
};

var output_serial_port: ?serial.SerialPort = null;

pub fn logFn(
    comptime level: std.log.Level,
    comptime scope: @TypeOf(.EnumLiteral),
    comptime format: []const u8,
    args: anytype,
) void {
    const scope_prefix = "(" ++ @tagName(scope) ++ "): ";
    const prefix = "[" ++ comptime level.asText() ++ "] " ++ scope_prefix;
    const port = output_serial_port orelse return;
    std.fmt.format(port.writer(), prefix ++ format ++ "\n", args) catch unreachable;
}

const kernel_log = std.log.scoped(.kernel);

export fn kmain(mb_magic: u32, mb_ptr: u32) callconv(.C) void {
    const serial_port = serial.SerialPort.init(0x3F8) catch unreachable;
    serial_port.writeChar('\n');
    output_serial_port = serial_port;

    kernel_log.info("starting zig kernel", .{});
    kernel_log.info("multiboot: magic=0x{X:0>8}, ptr=0x{X:0>8}", .{ mb_magic, mb_ptr });

    gdt.init();
    kernel_log.info("gdt initialized", .{});

    idt.init();
    exceptions.init();

    // const c = asm volatile ("div %%ecx"
    //     : [c] "={eax}" (-> u32),
    //     : [a] "{eax}" (3),
    //       [b] "{ecx}" (0),
    //     : "eax"
    // );
    // kernel_log.info("c = {}", .{c});
    asm volatile (
        \\ int $0x80
    );
}
