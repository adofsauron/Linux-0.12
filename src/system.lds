/*
 * head.lds
 *
 * Linker script for the head code
 */
OUTPUT_FORMAT("binary", "binary", "binary")
OUTPUT_ARCH(i386)
ENTRY(startup_32)

SECTIONS
{
	.HeaderText		0 : { *(.HeaderText) }
}
