#include <exec/exec.h>

extern LONG asum(struct ExecBase *SysBase);

LONG Startup() {
	struct ExecBase *SysBase = *(struct ExecBase **) 4;
	return asum(SysBase);
}
