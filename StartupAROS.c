#include <proto/exec.h>

#include <exec/exec.h>

LONG asum(struct ExecBase *SysBase);

__startup AROS_PROCH(Startup, arguments, argumentsLength, SysBase) {
	AROS_PROCFUNC_INIT
	return asum(SysBase);
	AROS_PROCFUNC_EXIT
}
