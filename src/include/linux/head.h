#ifndef _HEAD_H
#define _HEAD_H

typedef struct desc_struct
{
	unsigned int a, b;
} desc_table[256];

extern unsigned int pg_dir[1024];
extern desc_table idt, gdt;

#define GDT_NUL		0
#define GDT_CODE	1
#define GDT_DATA	2
#define GDT_TMP		3

#define LDT_NUL		0
#define LDT_CODE	1
#define LDT_DATA	2

#endif
