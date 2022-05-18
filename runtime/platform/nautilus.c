#define _GNU_SOURCE

#include "platform.h"

#include "platform/diskBack.unix.c"
#include "platform/displayMem.proc.c"
#include "platform/mmap-protect.c"
#include "platform/nonwin.c"
#include "platform/use-mmap.c"
#include "platform/sysconf.c"
#include "platform/mremap.c"

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

