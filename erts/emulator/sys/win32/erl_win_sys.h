/* ``The contents of this file are subject to the Erlang Public License,
 * Version 1.1, (the "License"); you may not use this file except in
 * compliance with the License. You should have received a copy of the
 * Erlang Public License along with this software. If not, it can be
 * retrieved via the world wide web at http://www.erlang.org/.
 * 
 * Software distributed under the License is distributed on an "AS IS"
 * basis, WITHOUT WARRANTY OF ANY KIND, either express or implied. See
 * the License for the specific language governing rights and limitations
 * under the License.
 * 
 * The Initial Developer of the Original Code is Ericsson Utvecklings AB.
 * Portions created by Ericsson are Copyright 1999, Ericsson Utvecklings
 * AB. All Rights Reserved.''
 * 
 *     $Id$
 */
/*
 * This file handles differences between operating systems.
 * This should be the only place with conditional compilation
 * depending on the type of OS.
 */

#ifndef _ERL_WIN_SYS_H
#define _ERL_WIN_SYS_H

#define HAS_STDARG

#include <stdio.h>
#include <math.h>
#include <stdlib.h>
#include <string.h>
#include <stdarg.h>
#include <limits.h>
#include <process.h>
#include <malloc.h>
#include <direct.h>
#include <errno.h>
#include <io.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <time.h>
#include <sys/timeb.h>

#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#undef WIN32_LEAN_AND_MEAN

#ifdef PURIFY
#  include "pure.h"
#  define purify_is_running PurifyIsRunning
#  define purify_printf PurifyPrintf
#  define purify_new_leaks PurifyNewLeaks
#  define purify_new_fds_inuse PurifyNewHandlesInuse
#  define purify_set_pool_id 
#endif

/*
 * Define MAXPATHLEN in terms of MAXPATH if available.
 */

#ifndef MAXPATH
#define MAXPATH MAX_PATH
#endif /* MAXPATH */

#ifndef MAXPATHLEN
#define MAXPATHLEN MAXPATH
#endif /* MAXPATHLEN */

/*
 * Various configuration options, used to be in the Makefile.
 */

#define asinh undef_math_func_1
#define acosh undef_math_func_1
#define atanh undef_math_func_1
#define erf   undef_math_func_1
#define erfc  undef_math_func_1
#define lgamma undef_math_func_1

#define	ELIB_HEAP_SBRK
#define ELIB_ALLOC_IS_CLIB
#define NO_SYSLOG
#define NO_SYSCONF
#define NO_DAEMON
#define NO_PWD
#define HAVE_MEMMOVE

/*
 * Make sure that ENOTSUP is defined.
 */

#ifndef ENOTSUP
#define	ENOTSUP		-1738659
#endif

/*
 * Practial Windows specific macros.
 */

#define CreateAutoEvent(state) CreateEvent(NULL, FALSE, state, NULL)
#define CreateManualEvent(state) CreateEvent(NULL, TRUE, state, NULL)

/*
 * API to console window.
 */

void ConInit(void);
int ConPutChar(int c);
void ConPrintf(char *format, ...);
void ConVprintf(char *format, va_list va);
void ConSetCursor(int from, int to);
void ConSetCtrlHandler(BOOL (WINAPI *handler)(DWORD CtrlType));
int ConGetKey(void);
void ConBeep(void);
int ConReadInput(unsigned char *data, int n);

/*
 * For erl_time_sup
 */
#define HAVE_GETHRTIME

#define sys_init_hrtime() /* Nothing */

#define SYS_CLK_TCK 100
#define SYS_CLOCK_RESOLUTION 1

typedef struct {
    long tv_sec;
    long tv_usec;
} SysTimeval;

typedef struct {
    clock_t tms_utime;
    clock_t tms_stime;
    clock_t tms_cutime;
    clock_t tms_cstime;
} SysTimes;

#if defined (__GNUC__)
typedef long long SysHrTime; /* Not actually needed... */
#else
typedef LONGLONG SysHrTime;
#endif

extern int sys_init_time(void);
extern void sys_gettimeofday(SysTimeval *tv);
extern SysHrTime sys_gethrtime(void);
extern clock_t sys_times(SysTimes *buffer);

/*
** These are to avoid irritating warnings
*/
#pragma warning(disable : 4244)
#pragma warning(disable : 4018)

#include <float.h>
#if defined (__GNUC__)
int _finite(double x);
#endif
#endif