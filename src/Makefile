#
# if you want the ram-disk device, define this to be the
# size in blocks.
#
RAMDISK = #-DRAMDISK=512

AS 			=as --32
LD 			=ld 
LDFLAGS		=-s -x -M --oformat binary -m elf_i386 -Ttext=0x0
CC			=gcc $(RAMDISK)
CFLAGS		=-w -O -fstrength-reduce -fomit-frame-pointer -fno-stack-protector
CPP			=cpp -m32 -nostdinc -Iinclude

#
# ROOT_DEV specifies the default root-device when making the image.
# This can be either FLOPPY, /dev/xxxx or empty, in which case the
# default of /dev/hd6 is used by 'build'.
#
ROOT_DEV 	=/dev/hd6
SWAP_DEV 	=/dev/hd2

ARCHIVES 	=kernel/kernel.o mm/mm.o fs/fs.o
DRIVERS 	=kernel/blk_drv/blk_drv.a kernel/chr_drv/chr_drv.a
MATH 		=kernel/math/math.a
LIBS		=lib/lib.a

.c.s:
	$(CC) $(CFLAGS) -m32 -nostdinc -Iinclude -S -o $*.s $<
.s.o:
	$(AS) -c -o $*.o $<
.c.o:
	$(CC) $(CFLAGS) -m32 -nostdinc -Iinclude -c -o $*.o $<

all:	Image

Image: 	boot/bootsect boot/setup tools/system tools/build
	tools/build boot/bootsect boot/setup tools/system $(ROOT_DEV) $(SWAP_DEV) > Image
	sync

disk: Image
	dd if=/dev/zero of=boot.img bs=1474560 count=1
	dd if=Image of=boot.img bs=512 conv=notrunc

tools/build: 	tools/build.c
	$(CC) $(CFLAGS) -o tools/build tools/build.c

boot/head.o: 	boot/head.s

tools/system:	boot/head.o init/main.o $(ARCHIVES) $(DRIVERS) $(MATH) $(LIBS)
	$(LD) $(LDFLAGS) boot/head.o init/main.o $(ARCHIVES) $(DRIVERS) $(MATH) $(LIBS) -o tools/system > System.map

kernel/math/math.a:
	(cd kernel/math; make)

kernel/blk_drv/blk_drv.a:
	(cd kernel/blk_drv; make)

kernel/chr_drv/chr_drv.a:
	(cd kernel/chr_drv; make)

kernel/kernel.o:
	(cd kernel; make)

mm/mm.o:
	(cd mm; make)

fs/fs.o:
	(cd fs; make)

lib/lib.a:
	(cd lib; make)

boot/setup: 	boot/setup.s
	$(AS) boot/setup.s -o boot/setup.o
	$(LD) boot/setup.o -o boot/setup

boot/bootsect:	boot/bootsect.s
	$(AS) boot/bootsect.s -o boot/bootsect.o
	$(LD) boot/bootsect.o -o boot/bootsect

boot/setup.s:	boot/setup.S include/linux/config.h
	$(CPP) -traditional boot/setup.S -o boot/setup.s

boot/bootsect.s:	boot/bootsect.S include/linux/config.h
	$(CPP) -traditional boot/bootsect.S -o boot/bootsect.s

clean:
	rm -f Image System.map tmp_make core boot/bootsect boot/setup \
		boot/bootsect.s boot/setup.s init/main.s
	rm -f init/*.o tools/system tools/build boot/*.o
	(cd mm;make clean)
	(cd fs;make clean)
	(cd kernel;make clean)
	(cd lib;make clean)

backup: clean
	(cd .. ; tar cf - linux | compress - > backup.Z)
	sync

dep:
	sed '/\#\#\# Dependencies/q' < Makefile > tmp_make
	(for i in init/*.c;do echo -n "init/";$(CPP) -M $$i;done) >> tmp_make
	cp tmp_make Makefile
	(cd fs; make dep)
	(cd kernel; make dep)
	(cd mm; make dep)

### Dependencies:
init/main.o : init/main.c include/unistd.h include/sys/stat.h \
  include/sys/types.h include/sys/time.h include/time.h include/sys/times.h \
  include/sys/utsname.h include/sys/param.h include/sys/resource.h \
  include/utime.h include/linux/tty.h include/termios.h include/linux/sched.h \
  include/linux/head.h include/linux/fs.h include/linux/mm.h \
  include/linux/kernel.h include/signal.h include/asm/system.h \
  include/asm/io.h include/stddef.h include/stdarg.h include/fcntl.h \
  include/string.h 

