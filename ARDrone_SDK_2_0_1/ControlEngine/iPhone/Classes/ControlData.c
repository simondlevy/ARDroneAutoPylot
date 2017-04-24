/*
 *  ControlData.m
 *  ARDroneEngine
 *
 *  Created by Frederic D'HAEYER on 14/01/10.
 *  Copyright 2010 Parrot SA. All rights reserved.
 *
 */
#include "ConstantsAndMacros.h"

//#define DEBUG_CONTROL

ControlData ctrldata;

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
        ardrone_academy_navdata_set_wifi_record_codec (vCapsInfo[vCaps].recordCodec);
        printf ("Device support : %d fps @ %d kbps - codec value : 0x%02x - Wifi record codec = 0x%02x\n", vCapsInfo[vCaps].supportedFps, vCapsInfo[vCaps].supportedBitrate, vCapsInfo[vCaps].defaultCodec, vCapsInfo[vCaps].recordCodec);
        ardrone_application_default_config.bitrate_ctrl_mode = ARDRONE_VARIABLE_BITRATE_MODE_DYNAMIC;
    } else {
        ardrone_application_default_config.video_codec = P264_CODEC;
        ardrone_application_default_config.bitrate_ctrl_mode = ARDRONE_VARIABLE_BITRATE_MODE_DYNAMIC;        
    }
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
	
	navdata_write_to_file(FALSE);
    
    ctrldata.navdata_connected = FALSE;
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
	PRINT("%s : %f\n", __FUNCTION__, percent);
#endif
	if(-1.0 <= percent && percent <= 1.0)
		ctrldata.yaw = percent;
	else if(-1.0 < percent)
		ctrldata.yaw = -1.0;
	else
		ctrldata.yaw = 1.0;
}

void inputGaz(float percent)
{
#ifdef DEBUG_CONTROL
	PRINT("%s : %f\n", __FUNCTION__, percent);
#endif
	if(-1.0 <= percent && percent <= 1.0)
		ctrldata.gaz = percent;
	else if(-1.0 < percent)
		ctrldata.gaz = -1.0;
	else
		ctrldata.gaz = 1.0;
}

void inputPitch(float percent)
{
#ifdef DEBUG_CONTROL
	PRINT("%s : %f, accelero_enable : %d\n", __FUNCTION__, percent, (ctrldata.accelero_flag >> ARDRONE_PROGRESSIVE_CMD_ENABLE) & 0x1 );
#endif
	if(-1.0 <= percent && percent <= 1.0)
		ctrldata.iphone_theta = -percent;
	else if(-1.0 < percent)
		ctrldata.iphone_theta = 1.0;
	else
		ctrldata.iphone_theta = -1.0;
}

void inputRoll(float percent)
{
#ifdef DEBUG_CONTROL
	PRINT("%s : %f, accelero_enable : %d\n", __FUNCTION__, percent, (ctrldata.accelero_flag >> ARDRONE_PROGRESSIVE_CMD_ENABLE) & 0x1);
#endif
	if(-1.0 <= percent && percent <= 1.0)
		ctrldata.iphone_phi = percent;
	else if(-1.0 < percent)
		ctrldata.iphone_phi = -1.0;
	else
		ctrldata.iphone_phi = 1.0;
}

void sendControls(void)
{
    ardrone_tool_set_progressive_cmd(ctrldata.command_flag, ctrldata.iphone_phi, ctrldata.iphone_theta, ctrldata.gaz, ctrldata.yaw, ctrldata.iphone_psi, ctrldata.iphone_psi_accuracy);
}

