const std = @import("std");
const idt = @import("idt.zig");

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

    // will be pushed by exceptions with error codes,
    // the stub pushes a zero here so we can use a single structure
    err_code: u32,

    // interrupt stack
    eip: u32,
    cs: u32,
    eflags: u32,

    // is pushed sometimes, used for tasking stuff
    esp0: u32,
    ss0: u32,

    fn dump(self: *const @This(), comptime logger: type) void {
        logger.err("exception frame:", .{});
        logger.err("  EAX={X:0>8} EBX={X:0>8} ECX={X:0>8} EDX={X:0>8}", .{ self.eax, self.ebx, self.ecx, self.edx });
        logger.err("  ESI={X:0>8} EDI={X:0>8} EBP={X:0>8} ESP={X:0>8}", .{ self.esi, self.edi, self.ebp, self.esp });
        logger.err("  EIP={X:0>8} EFLAGS={X:0>8}", .{ self.eip, self.eflags });
        logger.err("  CS={X:0>4} DS={X:0>4} ES={X:0>4} FS={X:0>4} GS={X:0>4} SS={X:0>4}", .{ self.cs, self.ds, self.es, self.fs, self.gs, self.ss });
    }
};

const IretRegisters = packed struct {
    eip: usize,
    cs: usize,
    eflags: usize,

    // Only present if interrupt was rasied from another privilege level
    esp0: usize,
    ss0: usize,
};

const ScratchRegisters = packed struct {
    edx: u32,
    ecx: u32,
    eax: u32,
};

const PreservedRegister = packed struct {
    edi: u32,
    esi: u32,
    ebp: u32,
    esp: u32,
    ebx: u32,
};

const exception_log = std.log.scoped(.exception);

pub fn int0Handler(frame: *InterruptFrame) callconv(.C) *InterruptFrame {
    exception_log.err("division by zero at {X:0>4}:{X:0>8}", .{ frame.cs, frame.eip });
    frame.dump(std.log);
    while (true) {}
}

pub fn isrStub(comptime handler: fn (*InterruptFrame) callconv(.C) *InterruptFrame) idt.InterruptHandler {
    return struct {
        fn func() callconv(.Naked) void {
            asm volatile (
                \\ cli 
                \\
                \\ pushl $0 // push dummy 0 err code
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
