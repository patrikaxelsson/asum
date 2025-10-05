#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include <stdlib.h>

#include <md5.h>

#define BUFFER_SIZE (64 * 1024)

int main(int argc, const char **argv) {
	struct MD5Ctx ctx;
	void *buffer = malloc(BUFFER_SIZE);
	if (NULL == buffer) {
		return 2;
	}

	if (argc < 2) {
		printf("Usage: %s file [file] ..\n", argv[0]);
		return 2;
	}

	for (int arg = 1; arg < argc; arg++) {
		const char *fileName = argv[arg];
		FILE *file = fopen(fileName, "r");
		if (NULL == file) {
			perror(fileName);
			return 2;
		}
		MD5_Init(&ctx);
		while(1) {
			size_t readBytes = fread(buffer, 1, BUFFER_SIZE, file);
			if (0 == readBytes) {
				if (ferror(file)) {
					perror(fileName);
					return 2;
				}
				else if (feof(file)) {
					uint8_t hash[16];
					MD5_Final(&ctx, hash);
					for (unsigned i = 0; i < sizeof(hash); i++) {
						printf("%02x", hash[i]);
					}
					printf("  %s\n", fileName);
					break;
				}
			}
			MD5_Update(&ctx, buffer, readBytes); 
		}
		fclose(file);
	}
	return 0;
}
