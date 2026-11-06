#include "self.h"
#include <libproc.h>
#include <mach/mach_time.h>
#include <unistd.h>

/* out[0] = CPU time used so far in ns (user + system), out[1] = resident bytes now. */
int32_t clqSelf(double *out, int64_t room) {
	struct proc_taskinfo info;
	mach_timebase_info_data_t base;
	if (out == NULL || room < 2) return -1;
	if (proc_pidinfo(getpid(), PROC_PIDTASKINFO, 0, &info, (int)sizeof info) != (int)sizeof info) return -1;
	if (mach_timebase_info(&base) != KERN_SUCCESS || base.denom == 0) return -2;
	double units = (double)info.pti_total_user + (double)info.pti_total_system;
	out[0] = units * (double)base.numer / (double)base.denom;
	out[1] = (double)info.pti_resident_size;
	return 0;
}
