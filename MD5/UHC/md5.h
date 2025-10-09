#ifndef __MD5_H__
#define __MD5_H__
#include <stdint.h>
#include <stddef.h>

struct MD5Ctx {
	uint32_t a;
	uint32_t b;
	uint32_t c;
	uint32_t d;
	uint32_t block[16];
	uint8_t buffer[64];
	uint32_t lo;
	uint32_t hi;
};

extern void MD5_Init(struct MD5Ctx *ctx);
extern void MD5_Update(struct MD5Ctx *ctx, const void *data, size_t size);
extern void MD5_Final(struct MD5Ctx *ctx, uint8_t *result);

#endif
