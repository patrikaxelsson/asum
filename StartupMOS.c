#include <exec/exec.h>

ULONG __abox__ = 1;

extern LONG asum(struct ExecBase *SysBase);

LONG Startup() {
	struct ExecBase *SysBase = *(struct ExecBase **) 4;
	return asum(SysBase);
}
