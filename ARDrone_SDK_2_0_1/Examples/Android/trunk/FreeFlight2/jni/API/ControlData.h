/*
 *  ControlData.h
 *  ARDroneEngine
 *
 *  Created by Frederic D'HAEYER on 14/01/10.
 *  Copyright 2010 Parrot SA. All rights reserved.
 *
 */
#ifndef _CONTROLDATA_H_
#define _CONTROLDATA_H_
#include "common.h"

#define SMALL_STRING_SIZE	16
#define MEDIUM_STRING_SIZE	64

typedef enum _CONFIG_STATE_
{
	CONFIG_STATE_IDLE,
	CONFIG_STATE_NEEDED,
	CONFIG_STATE_IN_PROGRESS,
} CONFIG_STATE;	

typedef struct
{
	float64_t latitude;
	float64_t longitude;
	float64_t altitude;
} gps_info_t;

typedef struct 
{
	/**
	 * Progressive commands
	 * And accelerometers values transmitted to drone, FALSE otherwise
	 */
	float yaw, gaz, iphone_phi, iphone_theta, iphone_psi, iphone_psi_accuracy;
	int32_t command_flag;
	
	int framecounter;

	int needVideoSwitch;

	bool_t needAnimation;
	char needAnimationParam[SMALL_STRING_SIZE];
	
	bool_t needLedAnimation;
	char needLedAnimationParam[SMALL_STRING_SIZE];
    
    bool_t navdata_connected;

    VIDEO_RECORDING_CAPABILITY recordingCapability;

} ControlData;

void initControlData(void);
void resetControlData(void);
void setApplicationDefaultConfig(void);
void setMagnetoEnabled(bool_t enabled);
void set_command_flag(int flag, bool_t enabled);
void getConfigSuccess(bool_t result);
void inputYaw(float percent);
void inputGaz(float percent);
void inputPitch(float percent);
void inputRoll(float percent);
void sendControls(void);

#endif // _CONTROLDATA_H_
