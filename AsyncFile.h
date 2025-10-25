#ifndef __ASYNCFILE_H__
#define __ASYNCFILE_H__

#include <exec/types.h>
#include <exec/ports.h>
#include <dos/dosextens.h>
#include <stdbool.h>

#include "OS4Compatibility.h"

struct AsyncCtx {
	struct ExecBase *sysBase;
	struct DosLibrary *dosBase;
	struct MsgPort *replyPort;
	struct DosPacket *packet;
	bool waitedFor;
};

struct AsyncCtx *AsyncFileInit(struct ExecBase *SysBase, struct DosLibrary *DOSBase, struct AsyncCtx *asyncCtxStore);
void AsyncFileStartRead(struct AsyncCtx *asyncCtx, BPTR file, const void *data, const LONG length);
LONG AsyncFileWaitForCompletion(struct AsyncCtx *asyncCtx, BPTR file);
void AsyncFileCleanup(struct AsyncCtx *asyncCtx);

#endif
