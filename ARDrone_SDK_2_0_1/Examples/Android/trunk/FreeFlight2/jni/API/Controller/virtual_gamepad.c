/*
 * virtual_gamepad.c
 *
 *  Created on: May 13, 2011
 *      Author: Dmytro Baryskyy
 */

#include <VP_Os/vp_os_print.h>

#include <ardrone_tool/UI/ardrone_input.h>

#include "common.h"
#include "ControlData.h"
#include "virtual_gamepad.h"

// Defining callbacks for the virtual gamepad
input_device_t virtual_gamepad = {
  "Virtual Gamepad",
  open_gamepad,
  update_gamepad,
  close_gamepad
};

static const char* TAG = "VIRTUAL_GAMEPAD";


// Will be called once
C_RESULT open_gamepad(void)
{
	LOGI (TAG, "GAMEPAD OPEN CALLED");
	return C_OK;
}


// Will be called approx 30 times per second
C_RESULT update_gamepad(void)
{
	sendControls();

	return C_OK;
}


C_RESULT close_gamepad(void)
{
	LOGI (TAG, "GAMEPAD CLOSE CALLED");
	return C_OK;
}
