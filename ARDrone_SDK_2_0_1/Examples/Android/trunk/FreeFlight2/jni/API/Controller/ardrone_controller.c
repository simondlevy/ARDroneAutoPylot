/*
 * ardrone_controller.c
 *
 *  Created on: Apr 10, 2011
 *      Author: Dmytro Baryskyy
 */

// Ardrone Library
#include <ardrone_api.h>

#include "common.h"
#include "ControlData.h"
#include "../NavData/nav_data.h"
#include "virtual_gamepad.h"
#include "ARDroneGeneratedTypes.h"
#include "ardrone_controller.h"

static const char* TAG = "ARDRONE_CONTROLLER";

// Local helper methods
static bool_t get_state_from_mask(uint32_t state, CTRL_STATES value);
static bool_t is_power_param_valid(float32_t power);
static int channel = ARDRONE_VIDEO_CHANNEL_FIRST;


extern ControlData ctrldata;

void parrot_ardrone_ctrl_take_off()
{
	ardrone_academy_navdata_takeoff();
}

void parrot_ardrone_ctrl_emergency()
{
	ardrone_academy_navdata_emergency();
}


void parrot_ardrone_ctrl_set_command_flag(int32_t control_mode, bool_t enable)
{
	set_command_flag(control_mode, enable);
}


void parrot_ardrone_ctrl_set_yaw(float32_t percent)
{
	inputYaw(percent);
}


void parrot_ardrone_ctrl_set_gaz(float32_t percent)
{
	inputGaz(percent);
}


void parrot_ardrone_ctrl_set_roll(float32_t percent)
{
	inputRoll(percent);
}


void parrot_ardrone_ctrl_set_pitch(float32_t percent)
{
	inputPitch(percent);
}


bool_t parrot_ardrone_ctrl_has_ctrl_status(CTRL_STATES value)
{
	//return get_state_from_mask(instance_navdata.current_control_state, value);
	return FALSE;
}

//
uint32_t parrot_ardrone_ctrl_get_battery_level()
{
//	return instance_navdata.battery_level;
}


uint32_t parrot_ardrone_ctrl_get_altitude()
{
	uint32_t altitude = 0;
//	altitude = instance_navdata.altitude;

	return altitude;
}


void parrot_ardrone_ctrl_set_yaw_max_angle(float32_t max_angle)
{
	ARDRONE_TOOL_CONFIGURATION_ADDEVENT(control_yaw, &max_angle, NULL);
}


void parrot_ardrone_ctrl_set_tilt_max_angle(float32_t max_angle)
{
	ARDRONE_TOOL_CONFIGURATION_ADDEVENT(euler_angle_max, &max_angle, NULL);
}


void parrot_ardrone_ctrl_set_vert_speed_max(float32_t speed)
{
	ARDRONE_TOOL_CONFIGURATION_ADDEVENT(control_vz_max, &speed, NULL);
}


void parrot_ardrone_ctrl_switch_camera(ardrone_tool_configuration_callback callback)
{
	if(channel++ == ARDRONE_VIDEO_CHANNEL_LAST)
				channel = ARDRONE_VIDEO_CHANNEL_FIRST;

	ARDRONE_TOOL_CONFIGURATION_ADDEVENT(video_channel, (int32_t*)&channel, callback);
}


void parrot_ardrone_ctrl_set_flat_trim()
{
	ardrone_at_set_flat_trim();
}


float32_t parrot_ardrone_ctrl_get_yaw_max_angle()
{
	return ardrone_control_config.control_yaw;
}


float32_t parrot_ardrone_ctrl_get_tilt_max_angle()
{
	return ardrone_control_config.euler_angle_max;
}


float32_t parrot_ardrone_ctrl_get_vert_speed_max()
{
	return ardrone_control_config.control_vz_max;;
}


bool_t parrot_ardrone_ctrl_is_outdoor_mode()
{
	return ardrone_control_config.outdoor;
}


void parrot_ardrone_ctrl_set_outdoor_mode(bool_t outdoor, ardrone_tool_configuration_callback callback)
{
	ARDRONE_TOOL_CONFIGURATION_ADDEVENT(outdoor, &outdoor, NULL);
}


bool_t get_state_from_mask(uint32_t state, CTRL_STATES value)
{
	uint32_t major = state >> 16;

	return (major == value?TRUE:FALSE);
}


bool_t is_power_param_valid(float32_t power)
{
	if (power >= 0.0f && power <=1.0f) {
		return TRUE;
	}

	LOGW(TAG, "Invalid power parameter : %f", power);
	return FALSE;
}
