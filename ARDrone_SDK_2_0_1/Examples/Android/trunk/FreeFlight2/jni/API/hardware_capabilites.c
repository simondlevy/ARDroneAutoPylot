//
//  hardware.c
//  ARDroneEngine
//
//  Created by Nicolas BRULEZ on 20/12/11.
//  Copyright (c) 2011 Parrot. All rights reserved.
//

#include "common.h"
#include "hardware_capabilites.h"
#include <sys/utsname.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>

typedef enum {
    _DEV_NOT_INIT = 0,
    _DEV_IPHONE,
    _DEV_IPAD,
    _DEV_IPOD,
    _DEV_SIMULATOR,
    _DEV_OTHER,
} _hw_deviceType;

typedef struct {
    _hw_deviceType device;
    int major;
    int minor;
} _device_hw_t;

// Infos for each vCaps :
const vCapsInfo_t vCapsInfo [VIDEO_CAPABILITIES_NUM] = {
    { 15,  500, H264_360P_CODEC }, // Pre-A4 devices : 15 fps, 0.5Mbps 360p
    { 25, 1500, H264_360P_CODEC }, // A4 devices     : 25 fps, 1.5Mbps 360p
    { 30, 4000, H264_360P_CODEC }, // A5 devices     : 30 fps, 4Mbps   360p
    { 30, 4000, H264_720P_CODEC }  // Future devices : 30 fps, 4Mbps   720p
};

#define HWCAPS_INIT_WITH_FAILURE_RETURN(FAILRET) \
  do                                             \
    {                                            \
      if (0 != _getCurrentDevice())              \
        {                                        \
          return FAILRET;                        \
        }                                        \
    } while (0)

#define HWCAPS_INIT()               \
  do                                \
    {                               \
      if (0 != _getCurrentDevice()) \
        {                           \
          return;                   \
        }                           \
    } while (0)

static _device_hw_t _currentDevice = {_DEV_NOT_INIT, 0, 0};
static int _androidVersion;
static char _gpuVendor[256];

void _parseDeviceString (char *str)
{
    int _maj, _min;
    _hw_deviceType _dev;
    _maj = _min = 0;
    _dev = _DEV_NOT_INIT;
    char *myStr = NULL;
    
    if (0 == strncmp ("iPhone", str, 6))
    {
        _dev = _DEV_IPHONE;
        myStr = str + 6;
    }
    else if (0 == strncmp ("iPad", str, 4))
    {
        _dev = _DEV_IPAD;
        myStr = str + 4;
    }
    else if (0 == strncmp ("iPod", str, 4))
    {
        _dev = _DEV_IPOD;
        myStr = str + 4;
    }
    else if (0 == strncmp ("i386", str, 4))
    {
        _dev = _DEV_SIMULATOR;
    }
    else
    {
        _dev = _DEV_OTHER;
    }
    
    _currentDevice.device = _dev;
    
    if (NULL != myStr)
    {
        int result = sscanf (myStr, "%d,%d", &_maj, &_min);
        if (2 == result)
        {
            _currentDevice.major = _maj;
            _currentDevice.minor = _min;
        }
    }
}

void setEnvironmentInfo(int androidVersion, char* gpuVendor)
{
	_androidVersion = androidVersion;
	strncpy(_gpuVendor, gpuVendor, 256);
}

int _getCurrentDevice (void)
{
    struct utsname platform;
    int rc = 0;
    if (_DEV_NOT_INIT != _currentDevice.device)
    {
        return rc;
    }
    
    rc = uname(&platform);
    if(rc == 0)
    {
    	LOGD("HARDWARE", "Machine: %s, Sysname: %s, Version: %s", platform.machine, platform.sysname, platform.version);
        _parseDeviceString(platform.machine);
    }
    return rc;
}

videoCapabilities getDeviceVideoCapabilites (void)
{
    videoCapabilities retCaps = VIDEO_CAPABILITIES_MIN;
    HWCAPS_INIT_WITH_FAILURE_RETURN (retCaps);
    switch (_currentDevice.device) {
        case _DEV_IPHONE:
            if (3 > _currentDevice.major)
            {
                retCaps = VIDEO_CAPABILITIES_MIN;
            }
            else if (3 == _currentDevice.major)
            {
                retCaps = VIDEO_CAPABILITIES_IP4;
            }
            else
            {
                retCaps = VIDEO_CAPABILITIES_360;
            }
            break;
            
        case _DEV_IPOD:
            if (4 > _currentDevice.major)
            {
                retCaps = VIDEO_CAPABILITIES_MIN;
            }
            else
            {
                retCaps = VIDEO_CAPABILITIES_IP4;
            }
            break;
            
        case _DEV_IPAD:
            if (2 > _currentDevice.major)
            {
                retCaps = VIDEO_CAPABILITIES_IP4;
            }
            else
            {
                retCaps = VIDEO_CAPABILITIES_360;
            }
            break;
            
        default:
            retCaps = VIDEO_CAPABILITIES_360;
            break;
    }
    return retCaps;
}

void printDeviceInfos (void)
{
    HWCAPS_INIT();
    LOGD ("HARDWARE", "Device number : %d | Major : %d | Minor : %d\n", _currentDevice.device, _currentDevice.major, _currentDevice.minor);
}
