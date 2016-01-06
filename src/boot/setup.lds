/*
 * setup.lds
 *
 * Linker script for the setup code
 */
OUTPUT_FORMAT("binary", "binary", "binary")
OUTPUT_ARCH(i386)
ENTRY(_start)

SECTIONS
{
	.SetupText			0 : { *(.SetupText) }
}
