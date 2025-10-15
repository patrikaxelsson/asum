#include <proto/exec.h>

#include <exec/exec.h>
#include <dos/dosextens.h>

ULONG __abox__ = 1;

LONG asum(struct ExecBase *SysBase, struct DosLibrary *DOSBase);

LONG Startup() {
	struct ExecBase *SysBase = *(void **) 4;
	struct DosLibrary *DOSBase = (void *) OpenLibrary("dos.library", 36);
	if (NULL == DOSBase) {
		return RETURN_FAIL;
	}
	LONG retVal = asum(SysBase, DOSBase);
	CloseLibrary((void *) DOSBase);
	return retVal;
}
