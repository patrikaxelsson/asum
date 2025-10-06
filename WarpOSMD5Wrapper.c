#include <proto/powerpc.h>

#include <powerpc/powerpc.h>

struct MD5Ctx;

extern MD5_Init;
extern MD5_Update;
extern MD5_Final;

LONG WarpOS_MD5_Init(struct Library *PowerPCBase, struct MD5Ctx *ctx) {
	struct PPCArgs args;
	args.PP_Code = (void *) &MD5_Init;
	args.PP_Offset = 0;
	args.PP_Flags = PPF_LINEAR;
	args.PP_Stack = NULL;
	args.PP_StackSize = 0;
	args.PP_Regs[0] = (ULONG) ctx;

	return RunPPC(&args);
}

LONG WarpOS_MD5_Update(struct Library *PowerPCBase, struct MD5Ctx *ctx, void *data, ULONG size) {
	struct PPCArgs args;
	args.PP_Code = (void *) &MD5_Update;
	args.PP_Offset = 0;
	args.PP_Flags = PPF_LINEAR;
	args.PP_Stack = NULL;
	args.PP_StackSize = 0;
	args.PP_Regs[0] = (ULONG) ctx;
	args.PP_Regs[1] = (ULONG) data;
	args.PP_Regs[2] = size;

	return RunPPC(&args);
}

LONG WarpOS_MD5_Final(struct Library *PowerPCBase, struct MD5Ctx *ctx, UBYTE hash[16]) {
	struct PPCArgs args;
	args.PP_Code = (void *) &MD5_Final;
	args.PP_Offset = 0;
	args.PP_Flags = PPF_LINEAR;
	args.PP_Stack = NULL;
	args.PP_StackSize = 0;
	args.PP_Regs[0] = (ULONG) ctx;
	args.PP_Regs[1] = (ULONG) hash;

	return RunPPC(&args);
}
