/*
 *  ControlData.m
 *  ARDroneEngine
 *
 *  Created by Frederic D'HAEYER on 14/01/10.
 *  Copyright 2010 Parrot SA. All rights reserved.
 *
 */
#include "common.h"
#include <ardrone_tool/Navdata/ardrone_academy_navdata.h>
#include <VLIB/video_codec.h>
#include "ControlData.h"

//#define DEBUG_CONTROL

ControlData ctrldata;

static const char* TAG = "ControlData";

void setApplicationDefaultConfig()
{
    videoCapabilities vCaps = getDeviceVideoCapabilites ();
#ifdef DEBUG_CONTROL
    printDeviceInfos();
#endif
	ardrone_application_default_config.navdata_demo = TRUE;
    ardrone_application_default_config.navdata_options = (NAVDATA_OPTION_MASK(NAVDATA_DEMO_TAG) | NAVDATA_OPTION_MASK(NAVDATA_VISION_DETECT_TAG) | NAVDATA_OPTION_MASK(NAVDATA_GAMES_TAG) | NAVDATA_OPTION_MASK(NAVDATA_MAGNETO_TAG) | NAVDATA_OPTION_MASK(NAVDATA_HDVIDEO_STREAM_TAG) | NAVDATA_OPTION_MASK(NAVDATA_WIFI_TAG));

    if (IS_ARDRONE2)
    {
        ardrone_application_default_config.codec_fps = vCapsInfo[vCaps].supportedFps;
        ardrone_application_default_config.max_bitrate = vCapsInfo[vCaps].supportedBitrate;
        ardrone_application_default_config.video_codec = vCapsInfo[vCaps].defaultCodec;
#ifdef DEBUG_CONTROL
        LOGD ("CONTROL_DATA", "Device support : %d fps @ %d kbps - codec value : 0x%02x\n", vCapsInfo[vCaps].supportedFps, vCapsInfo[vCaps].supportedBitrate, vCapsInfo[vCaps].defaultCodec);
#endif
        ardrone_application_default_config.bitrate_ctrl_mode = ARDRONE_VARIABLE_BITRATE_MODE_DYNAMIC;
    } else {
        ardrone_application_default_config.video_codec = P264_CODEC;
        ardrone_application_default_config.bitrate_ctrl_mode = ARDRONE_VARIABLE_BITRATE_MODE_DYNAMIC;        
    }

    switch (ctrldata.recordingCapability) {
    case VIDEO_RECORDING_NOT_SUPPORTED:
    	ardrone_academy_navdata_set_wifi_record_codec(NULL_CODEC);
    	break;
    case VIDEO_RECORDING_360P:
        ardrone_academy_navdata_set_wifi_record_codec(MP4_360P_H264_360P_CODEC);
    	break;
    case VIDEO_CAPABILITIES_720:
    	ardrone_academy_navdata_set_wifi_record_codec(MP4_360P_H264_720P_CODEC);
    	break;
    }

    LOGD(TAG, "setApplicationDefaultConfig [OK]");
}


void initControlData(void)
{
	ctrldata.framecounter = 0;
	
	ctrldata.needAnimation = FALSE;
	vp_os_memset(ctrldata.needAnimationParam, 0, sizeof(ctrldata.needAnimationParam));
	
	ctrldata.needVideoSwitch = -1;
	
	ctrldata.needLedAnimation = FALSE;
	vp_os_memset(ctrldata.needLedAnimationParam, 0, sizeof(ctrldata.needLedAnimationParam));
	
	resetControlData();
	ardrone_tool_input_start_reset();
	
//	navdata_write_to_file(FALSE);
    
    ctrldata.navdata_connected = FALSE;

    LOGD(TAG, "initControlData [OK]");
}

void resetControlData(void)
{
	//printf("reset control data\n");
	ctrldata.command_flag = 0;
	inputPitch(0.0);
	inputRoll(0.0);
	inputYaw(0.0);
	inputGaz(0.0);
    ctrldata.iphone_psi = 0;
    ctrldata.iphone_psi_accuracy = 0;
}

void inputYaw(float percent)
{
#ifdef DEBUG_CONTROL
	LOGD ("CONTROL_DATA", "%s : %f\n", __FUNCTION__, percent);
#endif
	if(-1.0f <= percent && percent <= 1.0f)
		ctrldata.yaw = percent;
	else if(-1.0f > percent)
		ctrldata.yaw = -1.0f;
	else
		ctrldata.yaw = 1.0f;
}

void inputGaz(float percent)
{
#ifdef DEBUG_CONTROL
	LOGD ("CONTROL_DATA", "%s : %f\n", __FUNCTION__, percent);
#endif
	if(-1.0f <= percent && percent <= 1.0f)
		ctrldata.gaz = percent;
	else if(-1.0f > percent)
		ctrldata.gaz = -1.0f;
	else
		ctrldata.gaz = 1.0f;
}

void inputPitch(float percent)
{
#ifdef DEBUG_CONTROL
	LOGD ("CONTROL_DATA", "%s : %f, accelero_enable : %d\n", __FUNCTION__, percent, (ctrldata.command_flag >> ARDRONE_PROGRESSIVE_CMD_ENABLE) & 0x1 );
#endif
	if(-1.0f <= percent && percent <= 1.0f)
		ctrldata.iphone_theta = percent;
	else if(-1.0f > percent)
		ctrldata.iphone_theta = -1.0f;
	else
		ctrldata.iphone_theta = 1.0f;

#ifdef DEBUG_CONTROL
	LOGD ("CONTROL_DATA", "%s : %f, accelero_enable : %d\n", __FUNCTION__, ctrldata.iphone_theta, (ctrldata.command_flag >> ARDRONE_PROGRESSIVE_CMD_ENABLE) & 0x1 );
#endif
}

void inputRoll(float percent)
{
#ifdef DEBUG_CONTROL
	LOGD ("CONTROL_DATA", "%s : %f, accelero_enable : %d\n", __FUNCTION__, percent, (ctrldata.command_flag >> ARDRONE_PROGRESSIVE_CMD_ENABLE) & 0x1);
#endif
	if(-1.0f <= percent && percent <= 1.0f)
		ctrldata.iphone_phi = percent;
	else if(-1.0f > percent)
		ctrldata.iphone_phi = -1.0f;
	else
		ctrldata.iphone_phi = 1.0f;

#ifdef DEBUG_CONTROL
	LOGD ("CONTROL_DATA", "%s : %f, accelero_enable : %d\n", __FUNCTION__, ctrldata.iphone_phi, (ctrldata.command_flag >> ARDRONE_PROGRESSIVE_CMD_ENABLE) & 0x1 );
	LOGD ("CONTROL_DATA", "ARDRONE_PROGRESSIVE_CMD_ENABLE: %d ARDRONE_PROGRESSIVE_CMD_COMBINED_YAW_ACTIVE : %d\ ",  (ctrldata.command_flag >> ARDRONE_PROGRESSIVE_CMD_ENABLE) & 0x1 , (ctrldata.command_flag >> ARDRONE_PROGRESSIVE_CMD_COMBINED_YAW_ACTIVE) & 0x1 );
#endif
}

void set_command_flag(int flag, bool_t enabled)
{
	if (enabled == TRUE) {
		ctrldata.command_flag |= (1 << flag);
	} else {
		ctrldata.command_flag &= ~(1 << flag);
	}
}

void sendControls(void)
{
    ardrone_tool_set_progressive_cmd(ctrldata.command_flag, ctrldata.iphone_phi, ctrldata.iphone_theta, ctrldata.gaz, ctrldata.yaw, ctrldata.iphone_psi, ctrldata.iphone_psi_accuracy);
}

