all: asum asum.aros-i386 asum.mos asum.os4

asum: asum.c Startup.c AsyncFile.c AsyncFile.h MD5/HiP/md5.s MD5/HiP/md5.h WarpOSMD5Wrapper-prelinked.o WarpOSMD5Wrapper.h Makefile
	vc +aos68k -nostdlib -O2 -sc -fastcall -D__NOLIBBASE__ -IMD5/HiP -lvc -o $@ Startup.c $< AsyncFile.c MD5/HiP/md5.s WarpOSMD5Wrapper-prelinked.o

# This separate step is required before linking with 68k code, to avoid PPC
# code referencing say the _memcpy symbol, being linked to the 68k _memcpy
# code.
WarpOSMD5Wrapper-prelinked.o: WarpOSMD5Wrapper.o MD5/UHC/md5-ppc-hunk.o Makefile
	vlink -bamigaehf -r -o $@ $< MD5/UHC/md5-ppc-hunk.o -L$(VBCC)/targets/ppc-warpos/lib -lamiga -lvc

# This step is to not have to redefine the function names in the MD5
# implementation used for the PPC, and allow them to co-exist with the 68k
# implementation.
WarpOSMD5Wrapper.o: WarpOSMD5Wrapper.c Makefile
	vc +aos68k -nostdlib -O2 -sc -fastcall -D__NOLIBBASE__ -D__ONLY_MD5_UPDATE__ -c -o $@ $<

MD5/UHC/md5-ppc-hunk.o: MD5/UHC/md5-ppc.s MD5/UHC/md5.h Makefile
	vasmppc_std -quiet -Fhunk -opt-branch -D__ONLY_MD5_UPDATE__ -o $@ $<

MD5/UHC/md5-ppc-elf.o: MD5/UHC/md5-ppc.s MD5/UHC/md5.h Makefile
	vasmppc_std -quiet -Felf -opt-branch -D__ELF__ -o $@ $<

asum-solar: asum.c Startup.c AsyncFile.c AsyncFile.h MD5/solar/md5.c MD5/solar/md5.h Makefile
	vc +aos68k -nostdlib -O2 -sc -fastcall -D__NOLIBBASE__ -IMD5/solar -lvc -o $@ Startup.c $< AsyncFile.c MD5/solar/md5.c

asum.aros-i386: asum.c StartupAROS.c AsyncFile.c AsyncFile.h MD5/solar/md5.c MD5/solar/md5.h Makefile
	i386-aros-gcc -nostartfiles -std=gnu99 -O2 -s -D__NOLIBBASE__ -IMD5/solar -static -o $@ StartupAROS.c $< AsyncFile.c MD5/solar/md5.c

asum.mos: asum.c StartupMOS.c AsyncFile.c AsyncFile.h MD5/UHC/md5-ppc-elf.o MD5/UHC/md5.h Makefile
	vc +morphos -nostdlib -O2 -use-lmw -D__NOLIBBASE__ -IMD5/UHC -lvc -o $@ StartupMOS.c $< AsyncFile.c MD5/UHC/md5-ppc-elf.o

asum.os4: asum.c StartupOS4.c AsyncFile.c AsyncFile.h MD5/UHC/md5-ppc-elf.o MD5/UHC/md5.h Makefile
	vc +aosppc -nostdlib -O2 -use-lmw -D__NOLIBBASE__ -D__USE_INLINE__ -DUSE_OLD_ANCHORPATH -IMD5/UHC -lvc -o $@ StartupOS4.c $< AsyncFile.c MD5/UHC/md5-ppc-elf.o

clean:
	$(RM) asum asum.aros-i386 asum.mos asum.os4 WarpOSMD5Wrapper.o WarpOSMD5Wrapper-prelinked.o MD5/UHC/md5-ppc-hunk.o MD5/UHC/md5-ppc-elf.o
