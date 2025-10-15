#include <proto/exec.h>

#include <exec/exec.h>
#include <dos/dosextens.h>
#include <interfaces/exec.h>
#include <interfaces/dos.h>

LONG asum(struct ExecIFace *IExec, struct DOSIFace *IDOS);

int32 _start(STRPTR arguments, int32 argumentsLength, struct ExecBase *SysBase) {
	struct ExecIFace *IExec = (void *) SysBase->MainInterface;
	IExec->Obtain();
	struct DosLibrary *DOSBase = (void *) OpenLibrary("dos.library", 36);
	struct DOSIFace *IDOS = NULL;
	if (NULL != DOSBase) {
		IDOS = (void *) GetInterface((void *) DOSBase, "main", 1, NULL);
	}
	LONG retVal = RETURN_ERROR;
	if (NULL != IDOS) {
		retVal = asum(IExec, IDOS);
	}
	DropInterface((void *) IDOS);
	CloseLibrary((void *) DOSBase);
	IExec->Release();
	return retVal;
}
