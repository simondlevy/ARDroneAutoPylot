#ifndef _HARDWARE_H_
#define _HARDWARE_H_

#include <VLIB/video_codec.h>


typedef enum
{
    VIDEO_CAPABILITIES_MIN = 0,
    VIDEO_CAPABILITIES_IP4,
    VIDEO_CAPABILITIES_360,
    VIDEO_CAPABILITIES_720,
    VIDEO_CAPABILITIES_NUM,
} videoCapabilities;

typedef struct _vcaps {
    int supportedFps;
    int supportedBitrate;
    codec_type_t defaultCodec;
} vCapsInfo_t;

extern const vCapsInfo_t vCapsInfo [VIDEO_CAPABILITIES_NUM];

void setEnvironmentInfo(int androidVersion, char* gpuVendor);
videoCapabilities getDeviceVideoCapabilites (void);
void printDeviceInfos (void);

#endif
