/*
autopylot_video.c - video-display thread for AR.Drone autopilot agent.

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
 
// Video data structure
#include "autopylot_video.h"

// Agent methods
#include "autopylot_agent.h"

// Globals
#include "ardrone_autopylot.h"

// For talking to SDK
#include <ardrone_tool/ardrone_tool_configuration.h>
#include <ardrone_tool/ardrone_version.h>
#include <ardrone_tool/UI/ardrone_input.h>

// Funcs pointer definition
const vp_api_stage_funcs_t video_funcs = {
    NULL,
    (vp_api_stage_open_t) video_open,
    (vp_api_stage_transform_t) video_transform,
    (vp_api_stage_close_t) video_close
};

C_RESULT video_open (video_cfg_t *cfg)
{

	// Initialize the Python (or Matlab or C) agent
	agent_init();
    
    return C_OK;
}

C_RESULT video_transform (video_cfg_t *cfg, vp_api_io_data_t *in, vp_api_io_data_t *out)
{
    // Realloc frameBuffer if needed
    if (in->size != cfg->fbSize)
    {
        cfg->frameBuffer = vp_os_realloc (cfg->frameBuffer, in->size);
        cfg->fbSize = in->size;
    }
    
    // Copy last frame to frameBuffer
    vp_os_memcpy (cfg->frameBuffer, in->buffers[in->indexBuffer], cfg->fbSize);
            	
	// Convert BRG to RGB
	int k;
	for (k=0; k<cfg->fbSize; k+=3) {
		uint8_t tmp = cfg->frameBuffer[k];
		cfg->frameBuffer[k] = cfg->frameBuffer[k+2];
		cfg->frameBuffer[k+2] = tmp;
	}
	
	// Grab image width from data structure
	int img_width = cfg->width;
	int img_height = cfg->height;

	// If belly camera indicated on AR.Drone 1.0, move camera data to beginning 
	// of buffer
	if (!IS_ARDRONE2 && g_is_bellycam) {
		int j;
		for (j=0; j<QCIF_HEIGHT; ++j) {
			memcpy(&cfg->frameBuffer[j*QCIF_WIDTH*3], 
			       &cfg->frameBuffer[j*QVGA_WIDTH*3], 
			       QCIF_WIDTH*3);
		}
		img_width  = QCIF_WIDTH;
		img_height = QCIF_HEIGHT;
	}

	// normalize navdata angles to (-1,+1)
	g_navdata.navdata_demo.phi /= 100000;
	g_navdata.navdata_demo.theta /= 100000;
	g_navdata.navdata_demo.psi /= 180000;

	// Init new commands
	commands_t commands;

	// Call the Python (or Matlab or C) agent's action routine
	agent_act(cfg->frameBuffer, img_width, img_height, g_is_bellycam, &g_navdata, &commands);

	if (g_autopilot) {

	        set(commands.phi, commands.theta, commands.gaz, commands.yaw);

		if (commands.zap) {
			zap();
		}
	}	
	
    // Tell the pipeline that we don't have any output
    out->size = 0;

    return C_OK;
}

C_RESULT video_close (video_cfg_t *cfg)
{

	// Shut down the Python (or Matlab or C) agent
	agent_close();
    
    return C_OK;
}

