#include <exec/exec.h>
#include <dos/dos.h>
#include <dos/dosextens.h>

#include <proto/exec.h>
#include <proto/dos.h>

#include "AsyncFile.h"

static bool AsyncFileIsOk(const struct AsyncFile *asyncFile) {
	return NULL != asyncFile->fileHandle &&
		NULL != asyncFile->replyPort &&
		NULL != asyncFile->packet;
}

bool AsyncFileInit(struct ExecBase *SysBase, struct DosLibrary *DOSBase, struct AsyncFile *asyncFile, const BPTR filePtr) {
	asyncFile->fileHandle = BADDR(filePtr);
	asyncFile->replyPort = CreateMsgPort();
	asyncFile->packet = AllocDosObject(DOS_STDPKT, NULL);
	asyncFile->waitedFor = true;
	return AsyncFileIsOk(asyncFile);
}

void AsyncFileStartRead(struct DosLibrary *DOSBase, struct AsyncFile *asyncFile, const void *data, const LONG length) {
	if(0 != length) { // Don't do anything for zero length
		asyncFile->packet->dp_Type = ACTION_READ;
		asyncFile->packet->dp_Arg1 = asyncFile->fileHandle->fh_Arg1; // Never changes, but more obvious this way
		asyncFile->packet->dp_Arg2 = (LONG) data;
		asyncFile->packet->dp_Arg3 = length;
		asyncFile->waitedFor = false;

		struct MsgPort *handlerPort = asyncFile->fileHandle->fh_Type;
		if(NULL != handlerPort) { // Only send an actual if the handler isn't NIL:
			SendPkt(asyncFile->packet, handlerPort, asyncFile->replyPort);
		}
	}
}

static struct DosPacket *GetDosPacket(struct ExecBase *SysBase, struct MsgPort *msgPort) {
	struct StandardPacket *standardPacket = (struct StandardPacket *) GetMsg(msgPort);
	return NULL != standardPacket ? &standardPacket->sp_Pkt : NULL;
}

LONG AsyncFileWaitForCompletion(struct ExecBase *SysBase, struct DosLibrary *DOSBase, struct AsyncFile *asyncFile) {
	if(!asyncFile->waitedFor) {
		struct MsgPort *handlerPort = asyncFile->fileHandle->fh_Type;
		if(NULL != handlerPort) { // Only wait and get result if the handler isn't NIL:
			// Try getting the packet without waiting first which is quicker, no context-switch
			struct DosPacket *resultPacket = GetDosPacket(SysBase, asyncFile->replyPort);
			if(NULL == resultPacket) {
				WaitPort(asyncFile->replyPort);
				resultPacket = GetDosPacket(SysBase, asyncFile->replyPort);
			}

			asyncFile->waitedFor = true;

			if(0 != resultPacket->dp_Res2) {
				SetIoErr(resultPacket->dp_Res2);
			}
			return resultPacket->dp_Res1;
		}
		else {
			return 0; // Return zero length if NIL:
		}
	}
	return 0;
}

void AsyncFileCleanup(struct ExecBase *SysBase, struct DosLibrary *DOSBase, struct AsyncFile *asyncFile) {
	if (NULL != asyncFile->fileHandle) {
		const LONG bytesWritten = AsyncFileWaitForCompletion(SysBase, DOSBase, asyncFile);
		if(-1 == bytesWritten) {
			PrintFault(IoErr(), "\nError while waiting for packet");
		}
	}

	DeleteMsgPort(asyncFile->replyPort);
	asyncFile->replyPort = NULL;

	if(NULL != asyncFile->packet) {
		FreeDosObject(DOS_STDPKT, asyncFile->packet);
	}
	asyncFile->packet = NULL;
}
