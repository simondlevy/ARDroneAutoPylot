/*
matlab_agent.c - C/Matlab communication code for AR.Drone Autopylot agent.

    Copyright (C) 2013 Simon D. Levy

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU Lesser General Public License as 
    published by the Free Software Foundation, either version 3 of the 
    License, or (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

 You should have received a copy of the GNU Lesser General Public License 
 along with this program.  If not, see <http://www.gnu.org/licenses/>.
 You should also have received a copy of the Parrot Parrot AR.Drone 
 Development License and Parrot AR.Drone copyright notice and disclaimer 
 and If not, see 
   <https://projects.ardrone.org/attachments/277/ParrotLicense.txt> 
 and
   <https://projects.ardrone.org/attachments/278/ParrotCopyrightAndDisclaimer.txt>.
*/

#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include "engine.h"

#undef _GNU_SOURCE

#include <navdata_common.h>

#include "autopylot_agent.h"

#define FUNCTION_NAME "autopylot_agent"

static Engine *ep;

static void put_variable(const char * varname, mxArray * array) {

	engPutVariable(ep, varname, array);
}

mxArray * create_numeric_array(mwSize size, mxClassID classid) {

	return mxCreateNumericMatrix(1, size, classid, 0); // 0 = not complex
}

void agent_init() {

	if (!(ep = engOpen("\0"))) {
		fprintf(stderr, "\nCan't start MATLAB engine\n");	
		return;
	}
}

void agent_act(unsigned char * img_bytes, int img_width, int img_height, bool_t img_is_belly,
	            navdata_unpacked_t * navdata, commands_t * commands) {

	// Need engine
	if (!ep) {
		return;
	}

	// Create flat matrix big enough to hold WIDTH X HEIGHT X 3 (RGB) image data
	mxArray * img =  create_numeric_array(img_height*img_width*3, mxUINT8_CLASS);

	// Copy image bytes to matrix in order appropriate for reshaping
	unsigned char * p = (unsigned char *)mxGetChars(img);
	int rgb, row, col;;
	for (rgb=0; rgb<3; ++rgb) {
		for (col=0; col<img_width; ++col) {
			for (row=0; row<img_height; ++row) {
				*p = img_bytes[2-rgb + 3*(row * img_width +  col)]; 
				p++;
			}
		}
	}

	// Put the image variable into the Matlab environment
	put_variable("img", img);

	// Create a variable for passing navigation data to Matlab function
	mxArray * mx_navdata = create_numeric_array(9, mxDOUBLE_CLASS);
	
	// Build command using reshaped IMG variable and constants from navdata structure
	char cmd[200];
	double * np = (double *)mxGetData(mx_navdata);

    navdata_demo_t demo = navdata->navdata_demo;

	*np++ = (double)(img_is_belly?1:0);
	*np++ = (double)demo.ctrl_state; 	     
	*np++ = (double)demo.vbat_flying_percentage;

	*np++ = demo.theta;                
	*np++ = demo.phi;                 
	*np++ = demo.psi;                

    *np++ = (double)navdata->navdata_altitude.altitude_raw;

    navdata_vision_raw_t vision_raw = navdata->navdata_vision_raw;

	*np++ = (double)vision_raw.vision_tx_raw;
	*np++ = (double)vision_raw.vision_ty_raw;

	// Put the navdata variable into the Matlab environment
	put_variable("navdata",   mx_navdata);

	// Build and evaluate command
	sprintf(cmd,"commands = %s(reshape(img, %d, %d, 3), navdata);", FUNCTION_NAME, img_height, img_width);
	if (engEvalString(ep, cmd)) {
		fprintf(stderr, "Error evaluating command: %s\n", cmd);
	}


	// Get output variables
	double *cp = (double *)mxGetData(engGetVariable(ep, "commands"));

	commands->zap     = (int)cp[0];
	commands->phi     = cp[1];
	commands->theta   = cp[2];
	commands->gaz     = cp[3];
	commands->yaw     = cp[4];

	// Deallocate memory
	mxDestroyArray(img);
	mxDestroyArray(mx_navdata);
}


void agent_close() {

	engEvalString(ep, "close;");
	engClose(ep);
}
