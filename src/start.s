.section .bss
.align 16
stack_bottom:
.skip 16384 // 16 KiB of kernel stack
stack_top:

.section .text
.global _start
.type _start, @function
_start:
	mov $stack_top, %esp
	mov %esp, %ebp

	push %ebx
	push %eax

	call kmain

	cli
	hlt