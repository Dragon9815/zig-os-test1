const std = @import("std");
const idt = @import("idt.zig");

const IretRegisters = packed struct {
    eip: usize,
    cs: usize,
    eflags: usize,

    // Only present if interrupt was rasied from another privilege level
    esp0: usize,
    ss0: usize,

    fn dump(self: *const @This(), comptime logger: type) void {
        logger.debug("SS0: {X:0>8} ESP0: {X:0>8} EFLAGS: {X:0>8}", .{ self.ss0, self.esp0, self.eflags });
        logger.debug("CS:  {X:0>4}     EIP:  {X:0>8}", .{ self.cs, self.eip });
    }
};

const ScratchRegisters = packed struct {
    edx: usize,
    ecx: usize,
    eax: usize,

    fn dump(self: *const @This(), comptime logger: type) void {
        logger.debug("EAX: {X:0>8} ECX:  {X:0>8} EDX: {X:0>8}", .{ self.eax, self.ecx, self.edx });
    }
};

// eax is not pushed here, because it has special handling for some stubs
inline fn pushScratchRegs() void {
    asm volatile (
        \\ push  %%ecx
        \\ push  %%edx
    );
}

inline fn popScratchRegs() void {
    asm volatile (
        \\ pop  %%edx
        \\ pop  %%ecx
        \\ pop  %%eax
    );
}

const PreservedRegisters = packed struct {
    edi: usize,
    esi: usize,
    ebp: usize,
    ebx: usize,

    fn dump(self: *const @This(), comptime logger: type) void {
        logger.debug("EBX: {X:0>8} EBP:  {X:0>8}", .{ self.ebx, self.ebp });
        logger.debug("ESI: {X:0>8} EDI:  {X:0>8}", .{ self.esi, self.edi });
    }
};

inline fn pushPreservedRegs() void {
    asm volatile (
        \\ push  %%ebx
        \\ push  %%ebp
        \\ push  %%esi
        \\ push  %%edi
    );
}

inline fn popPreservedRegs() void {
    asm volatile (
        \\ pop  %%edi
        \\ pop  %%esi
        \\ pop  %%ebp
        \\ pop  %%ebx
    );
}

const SegmentRegisters = packed struct {
    gs: usize,
    fs: usize,
    es: usize,
    ds: usize,

    fn dump(self: *const @This(), comptime logger: type) void {
        logger.debug("DS: {X:0>4}  ES: {X:0>4}  FS: {X:0>4}  GS: {X:0>4}", .{ self.ds, self.es, self.fs, self.gs });
    }
};

inline fn pushSegments() void {
    asm volatile (
        \\ push  %%ds
        \\ push  %%es
        \\ push  %%fs
        \\ push  %%gs
    );
}

inline fn popSegments() void {
    asm volatile (
        \\ pop  %%gs
        \\ pop  %%fs
        \\ pop  %%es
        \\ pop  %%ds
    );
}

pub const Frame = packed struct {
    segments: SegmentRegisters,
    preserved: PreservedRegisters,
    scratch: ScratchRegisters,
    iret: IretRegisters,

    pub fn dump(self: *const @This(), comptime logger: type) void {
        self.iret.dump(logger);
        self.scratch.dump(logger);
        self.preserved.dump(logger);
        self.segments.dump(logger);
    }
};

pub const ErrorFrame = packed struct {
    error_code: usize,
    iframe: Frame,

    pub fn dump(self: *const @This(), comptime logger: type) void {
        logger.debug("ERROR_CODE: {X:0>8}", .{self.error_code});
        self.iframe.dump(logger);
    }
};

/// Handler type for interrupts without an error code
const Handler = fn (*Frame) callconv(.C) *Frame;
/// Handler type for interrupts with an error code
const ErrorHandler = fn (*ErrorFrame) callconv(.C) *ErrorFrame;
/// Handler type for the default handler, this handler is used for all interrupt handlers that are not set up
const DefaultHandler = fn (i32, *Frame) callconv(.C) *Frame;

pub fn isrStub(comptime handler: Handler) idt.InterruptHandler {
    return struct {
        fn func() callconv(.Naked) void {
            asm volatile (
                \\ cli
            );

            asm volatile (
                \\ push  %%eax
            );

            pushScratchRegs();
            pushPreservedRegs();
            pushSegments();

            // TODO: is this actually needed, do these ever get changed?
            asm volatile (
                \\ mov   $0x10, %%ax
                \\ mov   %%ax, %%ds
                \\ mov   %%ax, %%es
                \\ mov   %%ax, %%fs
                \\ mov   %%ax, %%gs
            );

            asm volatile (
                \\ mov   %%esp, %%eax
                \\ push  %%eax
            );

            asm volatile ("call *%%ebx"
                :
                : [handler] "{ebx}" (&handler),
            );

            asm volatile ("mov   %%eax, %%esp");

            popSegments();
            popPreservedRegs();
            popScratchRegs();

            asm volatile (
                \\ iret
            );
        }
    }.func;
}

pub fn isrErrorStub(comptime handler: ErrorHandler) idt.InterruptHandler {
    return struct {
        fn func() callconv(.Naked) void {
            asm volatile (
                \\ cli
            );

            asm volatile (
                \\ xchg %%eax, (%%esp)
            );

            pushScratchRegs();
            pushPreservedRegs();
            pushSegments();

            asm volatile (
                \\ push %%eax
            );

            // TODO: is this actually needed, do these ever get changed?
            asm volatile (
                \\ mov   $0x10, %%ax
                \\ mov   %%ax, %%ds
                \\ mov   %%ax, %%es
                \\ mov   %%ax, %%fs
                \\ mov   %%ax, %%gs
            );

            asm volatile (
                \\ mov   %%esp, %%eax
                \\ push  %%eax
            );

            asm volatile (
                \\ call  *%%ebx
                :
                : [handler] "{ebx}" (&handler),
            );

            asm volatile (
                \\ add   4, %%esp
                \\ mov   %%eax, %%esp
            );

            popSegments();
            popPreservedRegs();
            popScratchRegs();

            asm volatile (
                \\ iret
            );
        }
    }.func;
}

pub fn isrUnhandledStub(comptime idx: comptime_int, comptime handler: DefaultHandler) idt.InterruptHandler {
    return struct {
        fn func() callconv(.Naked) void {
            asm volatile (
                \\ cli
            );

            asm volatile (
                \\ push  %%eax
            );

            pushScratchRegs();
            pushPreservedRegs();
            pushSegments();

            // TODO: is this actually needed, do these ever get changed?
            asm volatile (
                \\ mov   $0x10, %%ax
                \\ mov   %%ax, %%ds
                \\ mov   %%ax, %%es
                \\ mov   %%ax, %%fs
                \\ mov   %%ax, %%gs
            );

            asm volatile (
                \\ mov   %%esp, %%eax
                \\ push  %%eax
            );

            asm volatile (
                \\ push %%eax
                :
                : [idx] "{eax}" (idx),
            );

            asm volatile (
                \\ call *%%ebx
                :
                : [handler] "{ebx}" (&handler),
            );

            asm volatile ("mov   %%eax, %%esp");

            popSegments();
            popPreservedRegs();
            popScratchRegs();

            asm volatile (
                \\ iret
            );
        }
    }.func;
}
