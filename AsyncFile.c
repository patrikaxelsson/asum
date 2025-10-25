#include <exec/exec.h>
#include <dos/dos.h>
#include <dos/dosextens.h>

#include <proto/exec.h>
#include <proto/dos.h>

#include "AsyncFile.h"

struct AsyncCtx *AsyncFileInit(struct ExecBase *SysBase, struct DosLibrary *DOSBase, struct AsyncCtx *asyncCtxStore) {
	if (NULL == asyncCtxStore) {
		return NULL;
	}
	asyncCtxStore->sysBase = SysBase;
	asyncCtxStore->dosBase = DOSBase;

	asyncCtxStore->replyPort = CreateMsgPort();
	if (NULL == asyncCtxStore->replyPort) {
		return NULL;
	}
	asyncCtxStore->packet = AllocDosObject(DOS_STDPKT, NULL);
	if (NULL == asyncCtxStore->packet) {
		DeleteMsgPort(asyncCtxStore->replyPort);
		return NULL;
	}
	asyncCtxStore->waitedFor = true;

	return asyncCtxStore;
}

void AsyncFileStartRead(struct AsyncCtx *asyncCtx, const BPTR file, const void *data, const LONG length) {
	if (0 == length) {
		return;
	}
	struct FileHandle *fileHandle = BADDR(file);
	struct MsgPort *handlerPort = fileHandle->fh_Type;
	// If NIL:, don't do anything
	if (NULL == handlerPort) {
		return;
	}
	struct DosLibrary *DOSBase = asyncCtx->dosBase;

	asyncCtx->packet->dp_Type = ACTION_READ;
	asyncCtx->packet->dp_Arg1 = fileHandle->fh_Arg1;
	asyncCtx->packet->dp_Arg2 = (LONG) data;
	asyncCtx->packet->dp_Arg3 = length;
	asyncCtx->waitedFor = false;

	SendPkt(asyncCtx->packet, handlerPort, asyncCtx->replyPort);
}

LONG AsyncFileWaitForCompletion(struct AsyncCtx *asyncCtx, BPTR file) {
	if (NULL == asyncCtx) {
		return 0;
	}
	if (asyncCtx->waitedFor) {
		return 0;
	}
	struct FileHandle *fileHandle = BADDR(file);
	struct MsgPort *handlerPort = fileHandle->fh_Type;
	// If NIL:, don't do anything
	if (NULL == handlerPort) {
		return 0;
	}
	struct ExecBase *SysBase = asyncCtx->sysBase;
	struct DosLibrary *DOSBase = asyncCtx->dosBase;

	// See if the resulting is already available first, to avoid unnecessary
	// context switch
	struct Message *resultMessage = GetMsg(asyncCtx->replyPort);
	if (NULL == resultMessage) {
		WaitPort(asyncCtx->replyPort);
		resultMessage = GetMsg(asyncCtx->replyPort);
	}
	struct DosPacket *resultPacket = (void *) resultMessage->mn_Node.ln_Name;
	asyncCtx->waitedFor = true;

	SetIoErr(resultPacket->dp_Res2);
	return resultPacket->dp_Res1;
}

// AsyncFileWaitForCompletion() must have been called before
void AsyncFileCleanup(struct AsyncCtx *asyncCtx) {
	if (NULL == asyncCtx) {
		return;
	}
	struct ExecBase *SysBase = asyncCtx->sysBase;
	struct DosLibrary *DOSBase = asyncCtx->dosBase;

	FreeDosObject(DOS_STDPKT, asyncCtx->packet);
	DeleteMsgPort(asyncCtx->replyPort);
	return;
}
