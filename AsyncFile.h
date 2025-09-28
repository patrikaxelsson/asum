#ifndef __ASYNCFILE_H__
#define __ASYNCFILE_H__

#include <exec/types.h>
#include <exec/ports.h>
#include <dos/dosextens.h>
#include <stdbool.h>

struct AsyncFile {
	struct FileHandle *fileHandle;
	struct MsgPort *replyPort;
	struct DosPacket *packet;
	bool waitedFor;
};

bool AsyncFileInit(struct ExecBase *SysBase, struct DosLibrary *DOSBase, struct AsyncFile *asyncFile, const BPTR filePtr);
void AsyncFileStartRead(struct DosLibrary *DOSBase, struct AsyncFile *asyncFile, const void *data, const LONG length);
LONG AsyncFileWaitForCompletion(struct ExecBase *SysBase, struct DosLibrary *DOSBase, struct AsyncFile *asyncFile);
void AsyncFileCleanup(struct ExecBase *SysBase, struct DosLibrary *DOSBase, struct AsyncFile *asyncFile);

#endif
