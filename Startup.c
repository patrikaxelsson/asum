#include <proto/exec.h>

#include <exec/exec.h>

LONG asum(struct ExecBase *SysBase);

LONG Startup() {
	struct ExecBase *SysBase = *(void **) 4;
	return asum(SysBase);
}
