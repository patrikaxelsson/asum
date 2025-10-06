#ifndef __WARPOS_MD5_WRAPPER_H__
#define __WARPOS_MD5_WRAPPER_H__
#include <exec/types.h>

LONG WarpOS_MD5_Init(struct Library *PowerPCBase, void *ctx);
LONG WarpOS_MD5_Update(struct Library *PowerPCBase, void *ctx, void *data, ULONG size);
LONG WarpOS_MD5_Final(struct Library *PowerPCBase, void *ctx, UBYTE hash[16]);

#endif
