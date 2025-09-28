all: HiPSum

HiPSum: HiPSum.c AsyncFile.c AsyncFile.h MD5/HiP/md5.s MD5/HiP/md5.h Makefile
	vc +aos68k -nostdlib -O2 -sc -fastcall -D__NOLIBBASE__ -IMD5/HiP -lvc -o $@ $< AsyncFile.c MD5/HiP/md5.s

clean:
	$(RM) HiPSum
