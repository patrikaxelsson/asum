#ifndef __MD5_H__
#define __MD5_H__
#include <exec/types.h>
	
struct MD5Ctx {
        ULONG a;
        ULONG b;
        ULONG c;
        ULONG d;
        UBYTE buffer[64];
        ULONG block[16];
        ULONG lo;
        ULONG hi;
		struct {
			ULONG *blockAddress;
			ULONG constant;
		} stepsGHI[3 * 16];
		APTR ctx_bodyFunc;
};

void MD5_Init(__reg("a0") struct MD5Ctx *ctx);
void MD5_Update(__reg("a0") struct MD5Ctx *ctx, __reg("a1") void *data, __reg("d0") ULONG size);
void MD5_Final(__reg("a0") struct MD5Ctx *ctx, __reg("a1") UBYTE hash[16]);

#endif
