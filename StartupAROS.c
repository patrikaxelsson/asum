#include <proto/exec.h>

#include <exec/exec.h>
#include <dos/dosextens.h>

LONG asum(struct ExecBase *SysBase, struct DosLibrary *DOSBase);

__startup AROS_PROCH(Startup, arguments, argumentsLength, SysBase) {
	AROS_PROCFUNC_INIT
	struct DosLibrary *DOSBase = (void *) OpenLibrary("dos.library", 36);
	if (NULL == DOSBase) {
		return RETURN_FAIL;
	}
	LONG retVal = asum(SysBase, DOSBase);
	CloseLibrary((void *) DOSBase);
	return retVal;
	AROS_PROCFUNC_EXIT
}
