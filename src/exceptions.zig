const std = @import("std");
const interrupt = @import("interrupt.zig");
const idt = @import("idt.zig");

pub fn init() void {
    idt.setInterruptGate(0, interrupt.isrStub(division_error));
    idt.setInterruptGate(1, interrupt.isrStub(debug_trap));
    // 2 = NMI
    idt.setInterruptGate(3, interrupt.isrStub(breakpoint_trap));
    idt.setInterruptGate(4, interrupt.isrStub(overflow_trap));
    idt.setInterruptGate(5, interrupt.isrStub(bound_range_exceeded));
    idt.setInterruptGate(6, interrupt.isrStub(invalid_opcode));
    idt.setInterruptGate(7, interrupt.isrStub(device_not_available));
    idt.setInterruptGate(8, interrupt.isrErrorStub(double_fault));
    // 9 = Coprocessor Segment Overrun, not used anymore
    idt.setInterruptGate(10, interrupt.isrErrorStub(invalid_tss));
    idt.setInterruptGate(11, interrupt.isrErrorStub(segment_not_present));
    idt.setInterruptGate(12, interrupt.isrErrorStub(stack_segment_fault));
    idt.setInterruptGate(13, interrupt.isrErrorStub(general_protection_fault));
    idt.setInterruptGate(14, interrupt.isrErrorStub(page_fault));
    idt.setInterruptGate(16, interrupt.isrStub(floating_point_except));
    idt.setInterruptGate(17, interrupt.isrErrorStub(alignment_check));
    idt.setInterruptGate(18, interrupt.isrStub(machine_check));
    idt.setInterruptGate(19, interrupt.isrStub(simd_floating_point_except));
    idt.setInterruptGate(20, interrupt.isrStub(virtualization_except));
    idt.setInterruptGate(21, interrupt.isrErrorStub(control_protection_except));
    // 22 - 27 reserved
    idt.setInterruptGate(28, interrupt.isrStub(hypervisor_injection_except));
    idt.setInterruptGate(28, interrupt.isrErrorStub(vmm_communication_except));
    idt.setInterruptGate(28, interrupt.isrErrorStub(security_exception));
}

const exception_log = std.log.scoped(.exception);

fn division_error(frame: *interrupt.Frame) callconv(.C) *interrupt.Frame {
    exception_log.err("division by zero at {X:0>4}:{X:0>8}", .{ frame.iret.cs, frame.iret.eip });
    frame.dump(exception_log);
    exception_log.err("cannot continue", .{});
    while (true) {}
}

fn debug_trap(frame: *interrupt.Frame) callconv(.C) *interrupt.Frame {
    exception_log.err("debug trap at {X:0>4}:{X:0>8}", .{ frame.iret.cs, frame.iret.eip });
    frame.dump(exception_log);
    return frame;
}

fn breakpoint_trap(frame: *interrupt.Frame) callconv(.C) *interrupt.Frame {
    // eip actually points at the next instruction and int3 is 1 byte long
    exception_log.err("breakpoint trap at {X:0>4}:{X:0>8}", .{ frame.iret.cs, frame.iret.eip - 1 });
    frame.dump(exception_log);
    while (true) {}
    return frame;
}

fn overflow_trap(frame: *interrupt.Frame) callconv(.C) *interrupt.Frame {
    exception_log.err("overflow trap at {X:0>4}:{X:0>8}", .{ frame.iret.cs, frame.iret.eip });
    frame.dump(exception_log);
    return frame;
}

fn bound_range_exceeded(frame: *interrupt.Frame) callconv(.C) *interrupt.Frame {
    exception_log.err("bound range exceeded at {X:0>4}:{X:0>8}", .{ frame.iret.cs, frame.iret.eip });
    frame.dump(exception_log);
    exception_log.err("cannot continue", .{});
    while (true) {}
}

fn invalid_opcode(frame: *interrupt.Frame) callconv(.C) *interrupt.Frame {
    exception_log.err("invalid_opcode at {X:0>4}:{X:0>8}", .{ frame.iret.cs, frame.iret.eip });
    frame.dump(exception_log);
    exception_log.err("cannot continue", .{});
    while (true) {}
}

fn device_not_available(frame: *interrupt.Frame) callconv(.C) *interrupt.Frame {
    exception_log.err("device not available at {X:0>4}:{X:0>8}", .{ frame.iret.cs, frame.iret.eip });
    frame.dump(exception_log);
    exception_log.err("cannot continue", .{});
    while (true) {}
}

fn double_fault(frame: *interrupt.ErrorFrame) callconv(.C) *interrupt.ErrorFrame {
    exception_log.err("double fault at {X:0>4}:{X:0>8}", .{ frame.iframe.iret.cs, frame.iframe.iret.eip });
    frame.dump(exception_log);
    exception_log.err("cannot continue", .{});
    while (true) {}
}

fn invalid_tss(frame: *interrupt.ErrorFrame) callconv(.C) *interrupt.ErrorFrame {
    exception_log.err("invalid TSS at {X:0>4}:{X:0>8}", .{ frame.iframe.iret.cs, frame.iframe.iret.eip });
    frame.dump(exception_log);
    exception_log.err("cannot continue", .{});
    while (true) {}
}

fn segment_not_present(frame: *interrupt.ErrorFrame) callconv(.C) *interrupt.ErrorFrame {
    exception_log.err("segment not present at {X:0>4}:{X:0>8}", .{ frame.iframe.iret.cs, frame.iframe.iret.eip });
    frame.dump(exception_log);
    exception_log.err("cannot continue", .{});
    while (true) {}
}

fn stack_segment_fault(frame: *interrupt.ErrorFrame) callconv(.C) *interrupt.ErrorFrame {
    exception_log.err("stack segment fault at {X:0>4}:{X:0>8}", .{ frame.iframe.iret.cs, frame.iframe.iret.eip });
    frame.dump(exception_log);
    exception_log.err("cannot continue", .{});
    while (true) {}
}

fn general_protection_fault(frame: *interrupt.ErrorFrame) callconv(.C) *interrupt.ErrorFrame {
    exception_log.err("general protection fault at {X:0>4}:{X:0>8}", .{ frame.iframe.iret.cs, frame.iframe.iret.eip });
    frame.dump(exception_log);
    exception_log.err("cannot continue", .{});
    while (true) {}
}

fn page_fault(frame: *interrupt.ErrorFrame) callconv(.C) *interrupt.ErrorFrame {
    exception_log.err("page fault at {X:0>4}:{X:0>8}", .{ frame.iframe.iret.cs, frame.iframe.iret.eip });
    frame.dump(exception_log);
    exception_log.err("cannot continue", .{});
    while (true) {}
}

fn floating_point_except(frame: *interrupt.Frame) callconv(.C) *interrupt.Frame {
    exception_log.err("floating point exception at {X:0>4}:{X:0>8}", .{ frame.iret.cs, frame.iret.eip });
    frame.dump(exception_log);
    exception_log.err("cannot continue", .{});
    while (true) {}
}

fn alignment_check(frame: *interrupt.ErrorFrame) callconv(.C) *interrupt.ErrorFrame {
    exception_log.err("alignment check fault at {X:0>4}:{X:0>8}", .{ frame.iframe.iret.cs, frame.iframe.iret.eip });
    frame.dump(exception_log);
    exception_log.err("cannot continue", .{});
    while (true) {}
}

fn machine_check(frame: *interrupt.Frame) callconv(.C) *interrupt.Frame {
    exception_log.err("machine check error at {X:0>4}:{X:0>8}", .{ frame.iret.cs, frame.iret.eip });
    frame.dump(exception_log);
    exception_log.err("cannot continue", .{});
    while (true) {}
}

fn simd_floating_point_except(frame: *interrupt.Frame) callconv(.C) *interrupt.Frame {
    exception_log.err("SIMD floating point exception at {X:0>4}:{X:0>8}", .{ frame.iret.cs, frame.iret.eip });
    frame.dump(exception_log);
    exception_log.err("cannot continue", .{});
    while (true) {}
}

fn virtualization_except(frame: *interrupt.Frame) callconv(.C) *interrupt.Frame {
    exception_log.err("virtualization exception at {X:0>4}:{X:0>8}", .{ frame.iret.cs, frame.iret.eip });
    frame.dump(exception_log);
    exception_log.err("cannot continue", .{});
    while (true) {}
}

fn control_protection_except(frame: *interrupt.ErrorFrame) callconv(.C) *interrupt.ErrorFrame {
    exception_log.err("contol protection exception at {X:0>4}:{X:0>8}", .{ frame.iframe.iret.cs, frame.iframe.iret.eip });
    frame.dump(exception_log);
    exception_log.err("cannot continue", .{});
    while (true) {}
}

fn hypervisor_injection_except(frame: *interrupt.Frame) callconv(.C) *interrupt.Frame {
    exception_log.err("hypervisor injection exception at {X:0>4}:{X:0>8}", .{ frame.iret.cs, frame.iret.eip });
    frame.dump(exception_log);
    exception_log.err("cannot continue", .{});
    while (true) {}
}

fn vmm_communication_except(frame: *interrupt.ErrorFrame) callconv(.C) *interrupt.ErrorFrame {
    exception_log.err("VMM communication exception at {X:0>4}:{X:0>8}", .{ frame.iframe.iret.cs, frame.iframe.iret.eip });
    frame.dump(exception_log);
    exception_log.err("cannot continue", .{});
    while (true) {}
}

fn security_exception(frame: *interrupt.ErrorFrame) callconv(.C) *interrupt.ErrorFrame {
    exception_log.err("Security exception at {X:0>4}:{X:0>8}", .{ frame.iframe.iret.cs, frame.iframe.iret.eip });
    frame.dump(exception_log);
    exception_log.err("cannot continue", .{});
    while (true) {}
}
