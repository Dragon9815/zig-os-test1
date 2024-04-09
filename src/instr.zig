const gdt = @import("gdt.zig");

pub fn out8(address: u16, value: u8) void {
    asm volatile ("outb %al, %dx"
        :
        : [dx] "{dx}" (address),
          [al] "{al}" (value),
        : "edx", "eax"
    );
}

pub fn in8(address: u16) u8 {
    return asm volatile ("inb %dx, %al"
        : [al] "={al}" (-> u8),
        : [dx] "{dx}" (address),
        : "edx"
    );
}

pub fn lgdt(gdtr: *gdt.GdtPtr) void {
    asm volatile ("lgdt (%%eax)"
        :
        : [gdtr] "{eax}" (gdtr),
    );

    // Load the kernel data segment, index into the GDT
    asm volatile ("mov $0x10, %%bx");
    asm volatile ("mov %%bx, %%ds");
    asm volatile ("mov %%bx, %%es");
    asm volatile ("mov %%bx, %%fs");
    asm volatile ("mov %%bx, %%gs");
    asm volatile ("mov %%bx, %%ss");

    // Load the kernel code segment into the CS register
    asm volatile (
        \\ljmp $0x08, $1f
        \\1:
    );
}
