all: md5-test

md5-test: md5-test.c md5.c md5.h Makefile
	$(CC) -O2 -I. -o $@ $< md5.c

clean:
	$(RM) md5-test
