const std = @import("std");
const instr = @import("instr.zig");

const IdtEntry = packed struct {
    offset_lo: u16,
    segment_selector: u16,
    reserved: u8,
    gate_type: u4,
    zero: u1,
    privilege: u2,
    present: u1,
    offset_hi: u16,

    const interrupt_gate_32bit_type = 0xE;

    fn initZero() IdtEntry {
        return IdtEntry{
            .offset_lo = 0,
            .segment_selector = 0,
            .reserved = 0,
            .gate_type = 0,
            .zero = 0,
            .privilege = 0,
            .present = 0,
            .offset_hi = 0,
        };
    }

    fn initInterruptGate(address: u32, segment_selector: u16, privilege: u2) IdtEntry {
        return IdtEntry{
            .offset_lo = @truncate(address),
            .segment_selector = segment_selector,
            .reserved = 0,
            .gate_type = interrupt_gate_32bit_type,
            .zero = 0,
            .privilege = privilege,
            .present = 1,
            .offset_hi = @truncate(address >> 16),
        };
    }
};

pub const IdtPtr = packed struct {
    size: u16,
    offset: u32,
};

pub const InterruptHandler = fn () callconv(.Naked) void;

const num_entries = 256;
var entries: [num_entries]IdtEntry = [_]IdtEntry{IdtEntry.initZero()} ** num_entries;
var idtr = IdtPtr{
    .size = num_entries * @sizeOf(IdtEntry) - 1,
    .offset = 0,
};

pub fn setInterruptGate(index: u8, handler: *const InterruptHandler) void {
    entries[index] = IdtEntry.initInterruptGate(@intFromPtr(handler), 0x08, 0);
}

pub fn init() void {
    setInterruptGate(0, &interruptStub(int0Handler));

    idtr.offset = @intFromPtr(&entries);
    instr.lidt(&idtr);

    std.log.err("{any}", .{std.fmt.fmtSliceHexUpper(std.mem.asBytes(&entries[0]))});
}

const InterruptFrame = struct {
    eip: u32,
    cs: u32,
    eflags: u32,
    esp: u32,
    ss: u32,
};

fn int0Handler(frame: *InterruptFrame) *InterruptFrame {
    std.log.err("test", .{});
    std.log.err("EIP: 0x{X:0>8}, CS: 0x{X:0>4}, EFLAGS: 0x{X:0>8}", .{ frame.eip, frame.cs, frame.eflags });
    while (true) {}
    return frame;
}

fn interruptStub(comptime handler: fn (*InterruptFrame) *InterruptFrame) InterruptHandler {
    return struct {
        fn func() callconv(.Naked) void {
            asm volatile (
                \\ cli 
                \\
                \\ pusha
                \\ push  %%ds
                \\ push  %%es
                \\ push  %%fs
                \\ push  %%gs
                \\
                \\ mov   $0x10, %%ax
                \\ mov   %%ax, %%ds
                \\ mov   %%ax, %%es
                \\ mov   %%ax, %%fs
                \\ mov   %%ax, %%gs
                \\
                \\ mov   %%esp, %%eax
                \\ push  %%eax
            );

            asm volatile ("call *%%ebx"
                :
                : [handler] "{ebx}" (&handler),
            );

            asm volatile (
                \\ add   $4, %%esp
                \\
                \\ pop   %%gs
                \\ pop   %%fs
                \\ pop   %%es
                \\ pop   %%ds
                \\ popa
                \\ iret
            );
        }
    }.func;
}
