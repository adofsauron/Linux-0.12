/*
 * bootsect.lds
 *
 * Linker script for the bootsect code
 */
OUTPUT_FORMAT("binary", "binary", "binary")
OUTPUT_ARCH(i386)
ENTRY(_start)

SECTIONS
{
	.BootsectText		0 : { *(.BootsectText) }
	.DeviceConfigure	506 : { *(.DeviceConfigure) }
    .BootsectFlag		510 : {*(.BootsectFlag)}
}
