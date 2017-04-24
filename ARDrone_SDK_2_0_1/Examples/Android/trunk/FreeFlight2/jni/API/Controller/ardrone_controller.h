/*
 * ardrone_controller.h
 *
 *  Created on: Apr 10, 2011
 *      Author: Dmytro Baryskyy
 */

#ifndef ARDRONE_CONTROLLER_H_
#define ARDRONE_CONTROLLER_H_

#include <control_states.h>
#include <ardrone_tool/UI/ardrone_input.h>
#include <ardrone_tool/ardrone_tool_configuration.h>

void parrot_ardrone_ctrl_take_off();
void parrot_ardrone_ctrl_land();
void parrot_ardrone_ctrl_emergency();
void parrot_ardrone_ctrl_emergency_clear();

// Functions that used to set the options
void parrot_ardrone_ctrl_set_yaw_max_angle (float32_t /*max_angle*/); //in radians
void parrot_ardrone_ctrl_set_tilt_max_angle(float32_t /*max_angle*/); //in radians
void parrot_ardrone_ctrl_set_vert_speed_max(float32_t /*speed*/); //in mm per second
void parrot_ardrone_ctrl_set_flat_trim();
void parrot_ardrone_ctrl_set_outdoor_mode(bool_t /*outdoor*/, ardrone_tool_configuration_callback /*callback*/);


void parrot_ardrone_ctrl_set_command_flag(int32_t /*control_mode*/, bool_t /*enable*/);
// Functions that controls gaz, yaw, roll and pitch
void parrot_ardrone_ctrl_set_yaw  (float32_t /*yaw*/);
void parrot_ardrone_ctrl_set_gaz  (float32_t /*gaz*/);
void parrot_ardrone_ctrl_set_roll (float32_t /*roll*/);
void parrot_ardrone_ctrl_set_pitch(float32_t /*pitch*/);

// Functions that control video
void parrot_ardrone_ctrl_switch_camera(ardrone_tool_configuration_callback /*callback*/);

bool_t    parrot_ardrone_ctrl_has_ctrl_status(CTRL_STATES /*state*/);
uint32_t  parrot_ardrone_ctrl_get_battery_level();
uint32_t  parrot_ardrone_ctrl_get_altitude();
float32_t parrot_ardrone_ctrl_get_yaw_max_angle();
float32_t parrot_ardrone_ctrl_get_tilt_max_angle();
float32_t parrot_ardrone_ctrl_get_vert_speed_max();
bool_t    parrot_ardrone_ctrl_is_outdoor_mode();

#endif /* ARDRONE_CONTROLLER_H_ */
