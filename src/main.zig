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
const frame_alloc = @import("alloc/frame.zig");

pub const std_options = .{
    .log_level = .debug,
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

fn default_isr(idx: i32, frame: *interrupt.Frame) callconv(.C) *interrupt.Frame {
    kernel_log.warn("unhandled isr #{} at {X:0>4}:{X:0>8}", .{ idx, frame.iret.cs, frame.iret.eip });
    frame.dump(kernel_log);
    return frame;
}

const default_isr_handlers: [idt.num_entries - 32]*const idt.InterruptHandler = handlers: {
    var tmp_handlers: [idt.num_entries - 32]*const idt.InterruptHandler = undefined;
    for (32..idt.num_entries) |i| {
        tmp_handlers[i - 32] = interrupt.isrUnhandledStub(i, default_isr);
    }
    break :handlers tmp_handlers;
};

fn install_default_isr() void {
    for (32..idt.num_entries) |i| {
        idt.setInterruptGate(@intCast(i), default_isr_handlers[i - 32]);
    }
}

export fn kmain(mb_magic: u32, mb_ptr: u32) callconv(.C) void {
    const serial_port = serial.SerialPort.init(0x3F8) catch unreachable;
    serial_port.writeChar('\n');
    output_serial_port = serial_port;

    kernel_log.info("starting zig kernel", .{});
    kernel_log.info("multiboot: magic=0x{X:0>8}, ptr=0x{X:0>8}", .{ mb_magic, mb_ptr });

    kernel_log.info("initializing gdt...", .{});
    gdt.init();

    kernel_log.info("initializing idt...", .{});
    idt.init();

    kernel_log.info("initializing exception isrs...", .{});
    exceptions.init();

    kernel_log.info("initializing unhandled isrs...", .{});
    install_default_isr();
}
