/*
 * virtual_gamepad.h
 *
 *  Created on: May 13, 2011
 *      Author: Dmytro Baryskyy
 */

#ifndef VIRTUAL_GAMEPAD_H_
#define VIRTUAL_GAMEPAD_H_


#include <ardrone_tool/UI/ardrone_input.h>

// Setting virtual gamepad callbacks
extern input_device_t virtual_gamepad;

// Gamepad callbacks
static C_RESULT open_gamepad(void);
static C_RESULT update_gamepad(void);
static C_RESULT close_gamepad(void);


#endif /* VIRTUAL_GAMEPAD_H_ */
