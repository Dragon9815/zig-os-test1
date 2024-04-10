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
}

const exception_log = std.log.scoped(.exception);

const InterruptFrame = struct {
    // manually pushed
    ss: u32,
    gs: u32,
    fs: u32,
    es: u32,
    ds: u32,

    // pusha
    edi: u32,
    esi: u32,
    ebp: u32,
    esp: u32,
    ebx: u32,
    edx: u32,
    ecx: u32,
    eax: u32,

    // interrupt stack
    eip: u32,
    cs: u32,
    eflags: u32,

    // is pushed sometimes, used for tasking stuff
    esp0: u32,
    ss0: u32,

    fn dump(self: *const @This()) void {
        exception_log.err("exception frame:", .{});
        exception_log.err("  EAX={X:0>8} EBX={X:0>8} ECX={X:0>8} EDX={X:0>8}", .{ self.eax, self.ebx, self.ecx, self.edx });
        exception_log.err("  ESI={X:0>8} EDI={X:0>8} EBP={X:0>8} ESP={X:0>8}", .{ self.esi, self.edi, self.ebp, self.esp });
        exception_log.err("  EIP={X:0>8} EFLAGS={X:0>8}", .{ self.eip, self.eflags });
        exception_log.err("  CS={X:0>4} DS={X:0>4} ES={X:0>4} FS={X:0>4} GS={X:0>4} SS={X:0>4}", .{ self.cs, self.ds, self.es, self.fs, self.gs, self.ss });
    }
};

fn int0Handler(frame: *InterruptFrame) callconv(.C) *InterruptFrame {
    exception_log.err("division by zero at {X:0>4}:{X:0>8}", .{ frame.cs, frame.eip });
    frame.dump();
    while (true) {}
}

fn interruptStub(comptime handler: fn (*InterruptFrame) callconv(.C) *InterruptFrame) InterruptHandler {
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
                \\ push  %%ss
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
                \\ mov   %%eax, %%esp
                \\
                \\ pop   %%ss
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
