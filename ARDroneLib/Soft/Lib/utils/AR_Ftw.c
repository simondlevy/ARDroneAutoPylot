#include <utils/AR_Ftw.h>
#include <stdio.h>
#include <string.h>
#include <sys/types.h>
#include <unistd.h>
#include <dirent.h>
#include <stdlib.h>
#include <VP_Os/vp_os_print.h>

/**
 * Debug config
 */
#define AR_FTW_FORCE_DEBUG (0)
#define AR_FTW_ENABLE_DEBUG_WITH_DEBUG_MACRO (1)


/**
 * Debug print function (DO NOT EDIT)
 */
#if AR_FTW_FORCE_DEBUG
# define AR_FTW_USE_DEBUG (1)
#elif AR_FTW_ENABLE_DEBUG_WITH_DEBUG_MACRO && defined (DEBUG)
# define AR_FTW_USE_DEBUG (1)
#else
# define AR_FTW_USE_DEBUG (0)
#endif

#if AR_FTW_USE_DEBUG
#define AR_FTW_PRINT(...)                                      \
    do                                                         \
    {                                                          \
        PRINT ("%s @ %d : ", __FUNCTION__, __LINE__);          \
        PRINT (__VA_ARGS__);                                   \
        PRINT ("\n");                                          \
    } while (0)
#else
#define AR_FTW_PRINT(...) do {} while (0)
#endif
// END OF AUTO AR_FTW_PRINT FUNCTION

/**
 * Internal result values
 */
enum {
    AR_FTW_FAIL = 0,
    AR_FTW_OK,
};

/**
 * Internal define
 */
#define FTW_NOFLAGS (0)

/**
 * Internal functions declarations
 */
int AR_Ftw_internal (const char *dirPath, __ftw_func_t cb, int nopenfd);

int AR_Nftw_internal (const char *dirPath, __nftw_func_t cb, int nopenfd, int flags, int currentLevel, int currentBase);

/**
 * External entry points
 */
int ftw (const char *path, __ftw_func_t callback, int maxFileDesc)
{
    return AR_Ftw_internal (path, callback, maxFileDesc-3);
}

int nftw (const char *path, __nftw_func_t callback, int maxFileDesc, int flags)
{
    return AR_Nftw_internal (path, callback, maxFileDesc-3, flags, 0, 0);
}

/**
 * Implementation
 */

int typeFlagGet (struct stat *sb)
{
    if (S_ISDIR (sb->st_mode))
    {
        return FTW_D;
    }
    return FTW_F;
}

int
AR_Ftw_internal (const char *dirPath, __ftw_func_t cb, int nopenfd)
{
    int retVal = 0;
    if (0 >= nopenfd)
    {
        AR_FTW_PRINT ("Not enough FD");
        retVal = -1;
        return retVal;
    }
    // Call stat and the callback
    struct stat sb;
    lstat (dirPath, &sb);
    int typeFlag = typeFlagGet(&sb);
    retVal = cb (dirPath, &sb, typeFlag);
    if (0 != retVal)
    {
        AR_FTW_PRINT ("Callback said stop");
        return retVal;
    }

    // If we're searching a directory, call this on all this directory entries
    if (FTW_D == typeFlag)
    {
        AR_FTW_PRINT ("%s is a directory !", dirPath);
        // List the directory
        DIR *dir;
        struct dirent *ent;
        char *newName = NULL;
        int rootSize = strlen (dirPath);
        int nameSize = rootSize + 2;
        newName = malloc (nameSize);
        if (NULL == newName)
        {
            retVal = -1;
            AR_FTW_PRINT ("Unable to alloc buffer for filename");
            return retVal;
        }
        strncpy (newName, dirPath, nameSize);
        newName[rootSize] = '/';
        if (NULL == (dir = opendir (dirPath)))
        {
            retVal=-1;
            AR_FTW_PRINT ("Unable to open dir");
            return retVal;
        }

        while (NULL != (ent = readdir (dir)))
        {
            AR_FTW_PRINT ("Working on file %s for dir %s", ent->d_name, dirPath);
            if ('.' == ent->d_name[0] && // first char is .
                (('.' == ent->d_name[1] && '\0' == ent->d_name[2]) // second char is . (".."), or a null char (".")
                 || '\0' == ent->d_name[1])) // Third char is null ("..")
            {
                AR_FTW_PRINT ("Skipping");
                // Skip "." and ".."
                continue;
            }
            int l_nameSize = rootSize + strlen (ent->d_name) + 2;
            if (nameSize < l_nameSize)
            {
                nameSize = l_nameSize;
                newName = realloc (newName, nameSize);
                if (NULL == newName)
                {
                    retVal = -1;
                    closedir (dir);
                    AR_FTW_PRINT ("Unable to realloc buffer");
                    return retVal;
                }
            }
            strncpy (&newName[rootSize+1], ent->d_name, strlen (ent->d_name)+1);
            retVal = AR_Ftw_internal (newName, cb, nopenfd-1);
            if (0 != retVal)
            {
                closedir (dir);
                free (newName);
                AR_FTW_PRINT ("Callback said stop");
                return retVal;
            }
        }
        free (newName);
        closedir (dir);
    }
    return retVal;
}

int
AR_Nftw_retValTest (int retVal, int flags, int isDir)
{
    int testVal = AR_FTW_FAIL;
    if (FTW_ACTIONRETVAL == flags)
    {
        switch(retVal)
        {
        case FTW_CONTINUE:
            testVal = AR_FTW_OK;
            break;
        case FTW_SKIP_SUBTREE:
            testVal = (1 == isDir) ? AR_FTW_FAIL : AR_FTW_OK;
            break;
        case FTW_STOP:
            testVal = AR_FTW_FAIL;
            break;
        default:
            testVal = AR_FTW_FAIL;
            break;
        }
    }
    else
    {
        testVal = (0 == retVal) ? AR_FTW_OK : AR_FTW_FAIL;
    }
    return testVal;
}

int
AR_Nftw_internal (const char *dirPath, __nftw_func_t cb, int nopenfd, int flags, int currentLevel, int currentBase)
{
    int retVal = 0;
    if (FTW_NOFLAGS != flags &&
        FTW_ACTIONRETVAL != flags)
    {
        retVal = -1;
        return retVal;
    }
    struct FTW cbStruct = {currentBase, currentLevel};
    if (0 >= nopenfd)
    {
        AR_FTW_PRINT ("Not enough FD");
        retVal = -1;
        return retVal;
    }
    // Call stat and the callback
    struct stat sb;
    lstat (dirPath, &sb);
    int typeFlag = typeFlagGet(&sb);
    retVal = cb (dirPath, &sb, typeFlag, &cbStruct);
    if (AR_FTW_FAIL == AR_Nftw_retValTest(retVal, flags, FTW_D == typeFlag))
    {
        AR_FTW_PRINT ("Callback said stop");
        return retVal;
    }

    // If we're searching a directory, call this on all this directory entries
    if (FTW_D == typeFlag)
    {
        AR_FTW_PRINT ("%s is a directory !", dirPath);
        // List the directory
        DIR *dir;
        struct dirent *ent;
        char *newName = NULL;
        int rootSize = strlen (dirPath);
        int nameSize = rootSize + 2;
        newName = malloc (nameSize);
        if (NULL == newName)
        {
            retVal = -1;
            AR_FTW_PRINT ("Unable to alloc buffer for filename");
            return retVal;
        }
        strncpy (newName, dirPath, nameSize);
        newName[rootSize] = '/';
        if (NULL == (dir = opendir (dirPath)))
        {
            retVal=-1;
            AR_FTW_PRINT ("Unable to open dir");
            return retVal;
        }

        while (NULL != (ent = readdir (dir)))
        {
            AR_FTW_PRINT ("Working on file %s for dir %s", ent->d_name, dirPath);
            if ('.' == ent->d_name[0] && // first char is .
                (('.' == ent->d_name[1] && '\0' == ent->d_name[2]) // second char is . (".."), or a null char (".")
                 || '\0' == ent->d_name[1])) // Third char is null ("..")
            {
                AR_FTW_PRINT ("Skipping");
                // Skip "." and ".."
                continue;
            }
            int l_nameSize = rootSize + strlen (ent->d_name) + 2;
            if (nameSize < l_nameSize)
            {
                nameSize = l_nameSize;
                newName = realloc (newName, nameSize);
                if (NULL == newName)
                {
                    retVal = -1;
                    closedir (dir);
                    AR_FTW_PRINT ("Unable to realloc buffer");
                    return retVal;
                }
            }
            strncpy (&newName[rootSize+1], ent->d_name, strlen (ent->d_name)+1);
            retVal = AR_Nftw_internal (newName, cb, nopenfd-1, flags, currentLevel+1, strlen (dirPath) + 1);
            if (AR_FTW_FAIL == AR_Nftw_retValTest (retVal, flags, 0))
            {
                closedir (dir);
                free (newName);
                AR_FTW_PRINT ("Callback said stop");
                return retVal;
            }
        }
        free (newName);
        closedir (dir);
    }
    return retVal;
}
