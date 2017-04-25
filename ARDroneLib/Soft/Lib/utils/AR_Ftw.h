#ifndef _AR_FTW_H_
#define _AR_FTW_H_

/**
 * Custom incomplete ftw/nftw implementation for system without support
 * (Android as of ndk r7)
 */

/**
 * Ensure that we didn't encounter the original <ftw.h> header before
 */
#ifndef _FTW_H

#include <sys/stat.h>

/************************************
 * STRUCTURES / ENUMS
 ************************************/

/**
 * NFTW callback arg
 */
struct FTW {
    int base;
    int level;
};

/**
 * (N)FTW typeflags
 * This implementation does NOT support other file types
 */
enum {
    FTW_F = 0,
    FTW_D,
};

/**
 * NFTW flags
 * This implementation only supports ACTIONRETVAL flag
 */
enum {
    FTW_ACTIONRETVAL = 16,
};

/**
 * NFTW ACTIONRETVAL Values
 * Not all POSIX values are supported
 */
enum {
    FTW_CONTINUE = 0,
    FTW_STOP = 1,
    FTW_SKIP_SUBTREE = 2,
};

/**
 * FTW Callback type
 */
typedef int (*__ftw_func_t) (const char *fpath, const struct stat *sb, int typeflag);

/**
 * NFTW Callback type
 */
typedef int (*__nftw_func_t) (const char *fpath, const struct stat *sb, int typeflag, struct FTW *AR_ftwbuf);


/************************************
 * ENTRY POINTS
 ************************************/

/**
 * FTW-like function
 */
int ftw (const char *path, __ftw_func_t callback, int maxFileDesc);

/**
 * NFTW-like function
 */
int nftw (const char *path, __nftw_func_t callback, int maxFileDesc, int flags);

#endif

#endif
