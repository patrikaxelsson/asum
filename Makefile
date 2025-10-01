all: asum asum.aros-i386

asum: asum.c Startup.c AsyncFile.c AsyncFile.h MD5/HiP/md5.s MD5/HiP/md5.h Makefile
	vc +aos68k -nostdlib -O2 -sc -fastcall -D__NOLIBBASE__ -IMD5/HiP -lvc -o $@ Startup.c $< AsyncFile.c MD5/HiP/md5.s

asum.aros-i386: asum.c StartupAROS.c AsyncFile.c AsyncFile.h MD5/solar/md5.c MD5/solar/md5.h Makefile
	i386-aros-gcc -nostartfiles -std=gnu99 -O2 -s -D__NOLIBBASE__ -IMD5/solar -static -o $@ StartupAROS.c $< AsyncFile.c MD5/solar/md5.c

clean:
	$(RM) asum asum.aros-i386
