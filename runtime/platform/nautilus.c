#define _GNU_SOURCE

#include "platform.h"

#include "platform/nonwin.c"
#include "platform/sysconf.c"

//int MLton_recv(int s, void *buf, int len, int flags) {
//	return 0;
//}
//
//int MLton_recvfrom(int s, void *buf, int len, int flags, void *from, socklen_t *fromlen) {
//	return 0;
//}

/* #include "platform/diskBack.unix.c" */

void GC_diskBack_close (void *data) {
	printf("GC_diskBack_close\n");
	return;
}
void GC_diskBack_read (void *data, pointer buf, size_t size) {
	printf("GC_disBack_read\n");
	return;
}
void *GC_diskBack_write (pointer buf, size_t size) {
	printf("GC_diskBack_write\n");
	return 0;
}

//#include "platform/displayMem.proc.c"
/* GC_displayMem displays the virtual memory mapping to stdout.
 * It is used to diagnose memory problems.
 */
void GC_displayMem (void) {
	printf("GC)displayMem\n");
	return;
}

//#include "platform/mmap-protect.c"
void *GC_mmapAnonFlags_safe_protect (void *start, size_t length,
                                     int prot, int flags,
                                     size_t dead_low,
                                     size_t dead_high) {
	printf("GC_mmapAnonFlags_saf_protect\n");
	return 0;
}

void *GC_mmapAnon_safe_protect (void *start, size_t length, int prot,
                                size_t dead_low, size_t dead_high) {
	return GC_mmapAnonFlags_safe_protect (start, length,
	                                      prot, 0,
	                                      dead_low, dead_high);
}


//#include "platform/mmap.c"
//#include "platform/use-mmap.c"
//
void GC_release (void *base, size_t length) {
	printf("GC_release\n");
	return;
}

void *GC_mmapFileReadable (int fd, size_t size) {
	printf("GC_mmapFileReadable\n");
	return 0;
}

void *GC_mmapAnon (void *start, size_t length) {
        return 0;
}

void *GC_mmapAnonFlags (void *start, size_t length, int flags) {
	return 0;
}

void *GC_mmapAnonStack (void *start, size_t length, int prot,
                        size_t dead_low, size_t dead_high) {
	return GC_mmapAnonFlags_safe_protect (start, length, prot, 0,
	                                      dead_low, dead_high);
}

void GC_setSigProfHandler (struct sigaction *sa) {
	printf("GC_setSigProfHandler\n");
}

//#include "platform/mremap.c"

void *GC_mremap (void *start, size_t oldLength, size_t newLength) {
	printf("GC_mremap\n");
	return 0;
}

void* GC_extendHead (void *base, size_t length) {
	base = base;
	length = length;
	printf("extendHead\n");
        return 0;
}

void* GC_extendTail (void *base, size_t length) {
	base = base;
	length = length;
	printf("extendTail\n");
        return 0;
}

