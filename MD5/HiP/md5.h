#ifndef __MD5_H__
#define __MD5_H__
#include <exec/types.h>
	
struct MD5Ctx {
        ULONG a;
        ULONG b;
        ULONG c;
        ULONG d;
        ULONG block[16];
        UBYTE buffer[64];
        ULONG lo;
        ULONG hi;
		struct {
			ULONG *blockAddress;
			ULONG constant;
		} stepsGHI[3 * 16];
		APTR ctx_bodyFunc;
};

__regargs void MD5_Init(struct MD5Ctx *ctx);
__regargs void MD5_Update(struct MD5Ctx *ctx, void *data, ULONG size);
__regargs void MD5_Final(struct MD5Ctx *ctx, UBYTE hash[16]);

#endif
