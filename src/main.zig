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

export var stack_bytes: [16 * 1024]u8 align(16) linksection(".bss") = undefined;
export fn _start() callconv(.Naked) noreturn {
    // todo initialize stack
    asm volatile (
        \\ movl %[stk], %esp
        \\ movl %esp, %ebp
        \\ call kmain
        :
        : [stk] "{ecx}" (@intFromPtr(&stack_bytes) + @sizeOf(@TypeOf(stack_bytes))),
    );

    while (true) {}
}

const VGA_WIDTH = 80;
const VGA_HEIGHT = 25;
const VGA_SIZE = VGA_WIDTH * VGA_HEIGHT;
var buffer = @as([*]volatile u16, @ptrFromInt(0xB8000));

export fn kmain() callconv(.C) void {
    @memset(buffer[0..VGA_SIZE], (0x0700 | ' '));
    buffer[0] = 0x0700 | 'H';
    buffer[1] = 0x0700 | 'e';
    buffer[2] = 0x0700 | 'l';
    buffer[3] = 0x0700 | 'l';
    buffer[4] = 0x0700 | 'o';
}
