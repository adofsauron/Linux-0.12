AS 			=as --32
LD 			=ld 
LDFLAGS		=-s -x -M
CPP			=cpp -m32 -nostdinc -I../include

setup:	setup.s
	$(AS) setup.s -o setup.o
	$(LD) setup.o -Tsetup.lds -o setup

setup.s:	setup.S ../include/linux/config.h
	$(CPP) -traditional setup.S -o setup.s

bootsect:	bootsect.s
	$(AS) bootsect.s -o bootsect.o
	$(LD) bootsect.o -Tbootsect.lds -o bootsect

bootsect.s:	bootsect.S ../include/linux/config.h
	$(CPP) -traditional bootsect.S -o bootsect.s
	
clean:
	rm -f *.s *.o bootsect setup
