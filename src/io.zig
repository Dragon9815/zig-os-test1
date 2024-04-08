pub fn writePort8(address: u16, value: u8) void {
    asm volatile ("outb %al, %dx"
        :
        : [dx] "{dx}" (address),
          [al] "{al}" (value),
        : "edx", "eax"
    );
}

pub fn readPort8(address: u16) u8 {
    return asm volatile ("inb %dx, %al"
        : [al] "={al}" (-> u8),
        : [dx] "{dx}" (address),
        : "edx"
    );
}
