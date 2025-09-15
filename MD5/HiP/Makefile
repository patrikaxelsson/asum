all: md5-test

md5-test: md5.s Makefile
	vasmm68k_mot -DTEST -I/opt/sdk/NDK3.2R4/Include_I -Fhunkexe -o $@ $<

clean:
	$(RM) md5-test
