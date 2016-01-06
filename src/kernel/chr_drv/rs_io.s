/*
 *  linux/kernel/rs_io.s
 *
 *  (C) 1991  Linus Torvalds
 */

/*
 *	rs_io.s
 *
 * This module implements the rs232 io interrupts.
 */

	.section .text
	.global rs1_interrupt, rs2_interrupt

size	= 1024					# must be power of two !
								# and must match the value
								# in tty_io.c!!! */

/* these are the offsets into the read/write buffer structures */
rs_addr		= 0
head		= 4
tail		= 8
proc_list	= 12
buf			= 16

startup		= 256			/* chars left in write queue when we restart it */

/*
 * These are the actual interrupt routines. They look where
 * the interrupt is coming from, and take appropriate action.
 */
.align 4
rs1_interrupt:
	push $table_list+8
	jmp rs_int
.align 4
rs2_interrupt:
	push $table_list+16
rs_int:
	push %edx
	push %ecx
	push %ebx
	push %eax
	push %es
	push %ds					/* as this is an interrupt, we cannot */
	push $0x10					/* know that bs is ok. Load it */
	pop %ds
	push $0x10
	pop %es
	mov 24(%esp), %edx
	mov (%edx), %edx
	mov rs_addr(%edx), %edx
	add $2, %edx				/* interrupt ident. reg */
rep_int:
	xor %eax, %eax
	in %dx, %al
	test $1, %al
	jne end
	cmp $6, %al					/* this shouldn't happen, but ... */
	ja end
	mov 24(%esp), %ecx
	push %edx
	sub $2, %edx
	call *jmp_table(, %eax, 2)		/* NOTE! not *4, bit0 is 0 already */
	pop %edx
	jmp rep_int
end:
	mov $0x20, %al
	out %al, $0x20				/* EOI */
	pop %ds
	pop %es
	pop %eax
	pop %ebx
	pop %ecx
	pop %edx
	add $4, %esp				# jump over _table_list entry
	iret

jmp_table:
	.long modem_status, write_char, read_char, line_status

.align 4
modem_status:
	add $6, %edx				/* clear intr by reading modem status reg */
	in %dx, %al
	ret

.align 4
line_status:
	add $5, %edx				/* clear intr by reading line status reg. */
	in %dx, %al
	ret

.align 4
read_char:
	in %dx, %al
	mov %ecx, %edx
	sub $table_list, %edx
	shr $3, %edx
	mov (%ecx), %ecx			# read-queue
	mov head(%ecx), %ebx
	mov %al, buf(%ecx, %ebx)
	inc %ebx
	and $size-1, %ebx
	cmp tail(%ecx), %ebx
	je 1f
	mov %ebx, head(%ecx)
1:	add $63, %edx
	push %edx
	call do_tty_interrupt
	add $4, %esp
	ret

.align 4
write_char:
	mov 4(%ecx), %ecx			# write-queue
	mov head(%ecx), %ebx
	sub tail(%ecx), %ebx
	and $size-1, %ebx			# nr chars in queue
	je write_buffer_empty
	cmp $startup, %ebx
	ja 1f
	mov proc_list(%ecx), %ebx	# wake up sleeping process
	test %ebx, %ebx				# is there any?
	je 1f
	mov $0, (%ebx)
1:	mov tail(%ecx), %ebx
	mov buf(%ecx, %ebx), %al
	out %al, %dx
	inc %ebx
	and $size-1, %ebx
	mov %ebx, tail(%ecx)
	cmp head(%ecx), %ebx
	je write_buffer_empty
	ret
.align 4
write_buffer_empty:
	mov proc_list(%ecx), %ebx	# wake up sleeping process
	test %ebx, %ebx				# is there any?
	je 1f
	mov $0, (%ebx)
1:	inc %edx
	in %dx, %al
	jmp 1f
1:	jmp 1f
1:	and $0xd, %al				/* disable transmit interrupt */
	out %al, %dx
	ret
