#include <proto/exec.h>

#include <exec/exec.h>

ULONG __abox__ = 1;

LONG asum(struct ExecBase *SysBase);

LONG Startup() {
	struct ExecBase *SysBase = *(void **) 4;
	return asum(SysBase);
}
