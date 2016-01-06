	.code16

/*
 * SYS_SIZE is the number of clicks (16 bytes) to be loaded.
 * 0x3000 is 0x30000 bytes = 196kB, more than enough for current
 * versions of linux
 */

#include <linux/config.h>

SYSSIZE		= DEF_SYSSIZE
SETUPLEN	= 4					/* nr of setup-sectors */
BOOTSEG		= 0x07c0			/* original address of boot-sector */
INITSEG		= DEF_INITSEG		/* we move boot here - out of the way */
SETUPSEG	= DEF_SETUPSEG		/* setup starts here */
SYSSEG		= DEF_SYSSEG		/* system loaded at 0x10000 (65536). */
ENDSEG		= SYSSEG + SYSSIZE	/* where to stop loading */

/* ROOT_DEV & SWAP_DEV are now written by "build". */
ROOT_DEV	= 0
SWAP_DEV	= 0

/*
 *	bootsect.s		(C) 1991 Linus Torvalds
 *	modified by Drew Eckhardt
 *
 * bootsect.s is loaded at 0x7c00 by the bios-startup routines, and moves
 * iself out of the way to address 0x90000, and jumps there.
 *
 * It then loads 'setup' directly after itself (0x90200), and the system
 * at 0x10000, using BIOS interrupts. 
 *
 * NOTE! currently system is at most 8*65536 bytes long. This should be no
 * problem, even in the future. I want to keep it simple. This 512 kB
 * kernel size should be enough, especially as this doesn't contain the
 * buffer cache as in minix
 *
 * The loader has been made as simple as possible, and continuos
 * read errors will result in a unbreakable loop. Reboot by hand. It
 * loads pretty fast by getting whole sectors at a time whenever possible.
 */

	.section ".BootsectText", "ax"
	.global _start
_start:
	mov $BOOTSEG, %ax
	mov %ax, %ds
	mov $INITSEG, %ax
	mov %ax, %es
	mov $256, %cx
	sub %si, %si
	sub %di, %di
	rep
	movsw
	ljmp $INITSEG, $go

go:
	mov %cs, %ax
	mov $0xfef4, %dx			/* arbitrary value >>512 - disk parm size */

	mov %ax, %ds
	mov %ax, %es
	push %ax

	mov %ax, %ss				/* put stack at 0x9ff00 - 12. */
	mov %dx, %sp

/*
 *	Many BIOS's default disk parameter tables will not 
 *	recognize multi-sector reads beyond the maximum sector number
 *	specified in the default diskette parameter tables - this may
 *	mean 7 sectors in some cases.
 *
 *	Since single sector reads are slow and out of the question,
 *	we must take care of this by creating new parameter tables
 *	(for the first disk) in RAM.  We will set the maximum sector
 *	count to 18 - the most we will encounter on an HD 1.44.  
 *
 *	High doesn't hurt.  Low does.
 *
 *	Segments are as follows: ds=es=ss=cs - INITSEG,
 *		fs = 0, gs = parameter table segment
 */


	push $0
	pop %fs
	mov $0x78, %bx				/* fs:bx is parameter table address */
	lgs %fs:(%bx), %si			/* gs:si is source */

	mov %dx, %di				/* es:di is destination */
	mov $6, %cx					/* copy 12 bytes */
	cld

	rep
	movsw %gs:(%si), %es:(%di)

	mov %dx, %di
	movb $18, 4(%di)			/* patch sector count */

	mov %di, %fs:(%bx)
	mov %es, %fs:2(%bx)

	pop %ax
	mov %ax, %fs
	mov %ax, %gs
	
	xor %ah, %ah				/* reset FDC */
	xor %dl, %dl
	int $0x13

/*
 * load the setup-sectors directly after the bootblock.
 * Note that 'es' is already set up.
 */

load_setup:
	xor %dx, %dx				/* drive 0, head 0 */
	mov $0x0002, %cx			/* sector 2, track 0 */
	mov 0x0200, %bx				/* address = 512, in INITSEG */
	mov $0x0200+SETUPLEN, %ax	/* service 2, nr of sectors */
	int $0x13					/* read it */
	jnc ok_load_setup			/* ok - continue */

	push %ax					/* dump error code */
	call print_nl
	mov %sp, %bp
	call print_hex
	pop %ax
	
	xor %dl, %dl				/* reset FDC */
	xor %ah, %ah
	int $0x13
	jmp load_setup

ok_load_setup:

/* Get disk drive parameters, specifically nr of sectors/track */

	xor %dl, %dl
	mov $0x08, %ah				/* AH=8 is get drive parameters */
	int $0x13
	xor %ch, %ch
	mov %cx, %cs:sectors
	mov $INITSEG, %ax
	mov %ax, %es

/* Print some inane message */

	mov $0x03, %ah				/* read cursor pos */
	xor %bh, %bh
	int $0x10
	
	mov $9, %cx
	mov $0x0007, %bx			/* page 0, attribute 7 (normal) */
	mov $msg1, %bp
	mov $0x1301, %ax			/* write string, move cursor */
	int $0x10

/*
 * ok, we've written the message, now
 * we want to load the system (at 0x10000)
 */

	mov $SYSSEG, %ax
	mov %ax, %es				/* segment of 0x010000 */
	call read_it
	call kill_motor
	call print_nl

/*
 * After that we check which root-device to use. If the device is
 * defined (!= 0), nothing is done and the given device is used.
 * Otherwise, either /dev/PS0 (2,28) or /dev/at0 (2,8), depending
 * on the number of sectors that the BIOS reports currently.
 */

    mov %cs:root_dev, %ax
	or %ax, %ax
	jne root_defined
    mov %cs:sectors, %bx
	mov $0x0208, %ax			/* /dev/ps0 - 1.2Mb */
	cmp $15, %bx
	je root_defined
	mov $0x021c, %ax			/* /dev/PS0 - 1.44Mb */
	cmp $18, %bx
	je root_defined
undef_root:
	jmp undef_root
root_defined:
    mov %ax, %cs:root_dev

/*
 * after that (everyting loaded), we jump to
 * the setup-routine loaded directly after
 * the bootblock:
 */

	ljmp $SETUPSEG, $0

/*
 * This routine loads the system at address 0x10000, making sure
 * no 64kB boundaries are crossed. We try to load it as fast as
 * possible, loading whole tracks whenever we can.
 *
 * in:	es - starting address segment (normally 0x1000)
 */

sread:		.word 1+SETUPLEN	/* sectors read of current track */
head:		.word 0				/* current head */
track:		.word 0				/* current track */

read_it:
	mov %es, %ax
	test $0x0fff, %ax
die:
    jne die						/* es must be at 64kB boundary */
	xor %bx, %bx				/* bx is starting address within segment */
rp_read:
	mov %es, %ax
	cmp $ENDSEG, %ax			/* have we loaded all yet? */
	jb ok1_read
	ret
ok1_read:
    mov %cs:sectors, %ax
	sub sread, %ax
	mov %ax, %cx
	shl $9, %cx
	add %bx, %cx
	jnc ok2_read
	je ok2_read
	xor %ax, %ax
	sub %bx, %ax
	shr $9, %ax
ok2_read:
	call read_track
	mov %ax, %cx
	add sread, %ax
    cmp %cs:sectors, %ax
	jne ok3_read
	mov $1, %ax
	sub head, %ax
	jne ok4_read
	incw track
ok4_read:
	mov %ax, head
	xor %ax, %ax
ok3_read:
	mov %ax, sread
	shl $9, %cx
	add %cx, %bx
	jnc rp_read
	mov %es, %ax
	add $0x10, %ah
	mov %ax, %es
	xor %bx, %bx
	jmp rp_read

read_track:
	pusha
	pusha	
	mov $0xe2e, %ax				/* loading... message 2e = . */
	mov $7, %bx
 	int $0x10
	popa		

	mov track, %dx
	mov sread, %cx
	inc %cx
	mov %dl, %ch
	mov head, %dx
	mov %dl, %dh
	and $0x0100, %dx
	mov $2, %ah
	
	push %dx					/* save for error dump */
	push %cx
	push %bx
	push %ax

	int $0x13
	jc bad_rt
	add $8, %sp
	popa
	ret

bad_rt:
    push %ax					/* save error code */
	call print_all				/* ah = error, al = read */
	
	
	xor %ah, %ah
	xor %dl, %dl
	int $0x13
	

	add $10, %sp
	popa	
	jmp read_track

/*
 *	print_all is for debugging purposes.  
 *	It will print out all of the registers.  The assumption is that this is
 *	called from a routine, with a stack frame like
 *
 *	dx 
 *	cx
 *	bx
 *	ax
 *	error
 *	ret <- sp
 *
 */
 
print_all:
	mov $5, %cx					/* error code + 4 registers */
	mov %sp, %bp

print_loop:
	push %cx					/* save count left */
	call print_nl				/* nl for readability */
	jae no_reg					/* see if register name is needed */
	
	mov $0xe05 + 0x41 - 1, %ax
	sub %cl, %al
	int $0x10

	mov $0x58, %al				/* X */
	int $0x10

	mov $0x3a, %al				/* : */
	int $0x10

no_reg:
	add $2, %bp					/* next register */
	call print_hex				/* print it */
	pop %cx
	loop print_loop
	ret

print_nl:
	mov $0xe0d, %ax				/* CR */
	int $0x10
	mov $0xa, %al				/* LF */
	int $0x10
	ret

/*
 *	print_hex is for debugging purposes, and prints the word
 *	pointed to by ss:bp in hexadecmial.
 */

print_hex:
	mov $4, %cx					/* 4 hex digits */
	mov (%bp), %dx				/* load word into dx */
print_digit:
	rol $4, %dx					/* rotate so that lowest 4 bits are used */
	mov $0xe, %ah
    mov %dl, %al				/* mask off so we have only next nibble */
	and $0xf, %al
	add $0x30, %al				/* convert to 0 based digit, '0' */
	cmp $0x39, %al				/* check for overflow */
	jbe good_digit
	add $0x41 - 0x30 - 0xa, %al	/* 'A' - '0' - 0xa */

good_digit:
	int $0x10
	loop print_digit
	ret


/*
 * This procedure turns off the floppy drive motor, so
 * that we enter the kernel in a known state, and
 * don't have to worry about it later.
 */

kill_motor:
	push %dx
	mov $0x3f2, %dx
	xor %al, %al
	outb %al, %dx
	pop %dx
	ret

sectors:	.word 0

msg1:
	.byte 13,10
	.ascii "Loading"

    .section ".DeviceConfigure", "a"
swap_dev:	.word SWAP_DEV
root_dev:	.word ROOT_DEV

    .section ".BootsectFlag", "a"
boot_flag:	.word 0xAA55

