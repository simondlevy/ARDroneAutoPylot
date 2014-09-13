/*
ardrone_autopylot.c - entry point for AR.Drone Autopylot agent.

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

History:

04-SEP-2012 Created by nicolas.brulez@parrot.com as ardrone_testing_tool.c

04-JUN-2013 SDL: Modified to work with AR.Drone Autopylot                            
*/

// Generic includes
#include <ardrone_api.h>
#include <signal.h>
#include <strings.h>

// ARDrone Tool includes
#include <ardrone_tool/UI/ardrone_input.h>
#include <ardrone_tool/ardrone_tool_configuration.h>
#include <ardrone_tool/ardrone_version.h>
#include <ardrone_tool/Navdata/ardrone_navdata_client.h>

// Video data structure
#include "autopylot_video.h"

// Globals
#define _MAIN
#include "ardrone_autopylot.h"

// This must be global to ardrone_tool_init_custom()
static video_cfg_t dispCfg;

void controlCHandler (int signal)
{
    // Flush all streams before terminating
    fflush (NULL);
    usleep (200000); // Wait 200 msec to be sure that flush occured
    printf ("\nAll files were flushed\n");
    exit (0);
}

extern input_device_t gamepad;

int main (int argc, char *argv[])
{
    signal (SIGABRT, &controlCHandler);
    signal (SIGTERM, &controlCHandler);
    signal (SIGINT, &controlCHandler);
    
    return ardrone_tool_main (argc, argv);
}

C_RESULT ardrone_tool_init_custom (void)
{
    // Reset global data
    bzero(&g_navdata, sizeof(g_navdata));
    g_autopilot = FALSE;
    
    // Register a new game controller
    ardrone_tool_input_add( &gamepad );
    
    ardrone_application_default_config.navdata_demo = TRUE;
    
     ardrone_application_default_config.navdata_options = 
    (NAVDATA_OPTION_MASK(NAVDATA_DEMO_TAG) | 
        NAVDATA_OPTION_FULL_MASK |
        NAVDATA_OPTION_MASK(NAVDATA_VISION_DETECT_TAG) | 
        NAVDATA_OPTION_MASK(NAVDATA_GAMES_TAG) | 
        NAVDATA_OPTION_MASK(NAVDATA_MAGNETO_TAG) | 
        NAVDATA_OPTION_MASK(NAVDATA_HDVIDEO_STREAM_TAG) | 
        NAVDATA_OPTION_MASK(NAVDATA_WIFI_TAG));

    vp_api_picture_t *in_picture = (vp_api_picture_t *)vp_os_calloc (1, sizeof (vp_api_picture_t));
    vp_api_picture_t *out_picture = (vp_api_picture_t *)vp_os_calloc (1, sizeof (vp_api_picture_t));
    
    if (IS_ARDRONE2)
    {
        ardrone_application_default_config.video_codec = H264_360P_CODEC;
        in_picture->width = 640;  
        in_picture->height = 360;
    }
    else
    {
        ardrone_application_default_config.video_codec = P264_CODEC;
        in_picture->width = 320;  
        in_picture->height = 240;
    }
    
    ardrone_application_default_config.video_channel = ZAP_CHANNEL_HORI;
    ardrone_application_default_config.bitrate_ctrl_mode = 1;
    
    
    /**
    * Allocate useful structures :
    * - index counter
    * - thread param structure and its substructures
    */
    uint8_t stages_index = 0;
    
    specific_parameters_t *params = (specific_parameters_t *)vp_os_calloc (1, sizeof (specific_parameters_t));
    specific_stages_t *example_pre_stages = (specific_stages_t *)vp_os_calloc (1, sizeof (specific_stages_t));
    specific_stages_t *example_post_stages = (specific_stages_t *)vp_os_calloc (1, sizeof (specific_stages_t));
    
    out_picture->framerate = 20; // Drone 1 only, must be equal to drone target FPS
    out_picture->format = PIX_FMT_RGB24; 
    out_picture->width = in_picture->width;
    out_picture->height = in_picture->height;
    
    // One buffer, three bytes per pixel
    out_picture->y_buf = vp_os_malloc ( out_picture->width * out_picture->height * 3 );
    out_picture->cr_buf = NULL;
    out_picture->cb_buf = NULL;
    out_picture->y_line_size = out_picture->width * 3;
    out_picture->cb_line_size = 0;
    out_picture->cr_line_size = 0;
    
    example_pre_stages->stages_list = (vp_api_io_stage_t *)vp_os_calloc (1, sizeof (vp_api_io_stage_t));
    example_post_stages->stages_list = (vp_api_io_stage_t *)vp_os_calloc (1, sizeof (vp_api_io_stage_t));
    
    /**
    * Fill the POST stage list
    * - name and type are debug infos only
    * - cfg is the pointer passed as "cfg" in all the stages calls
    * - funcs is the pointer to the stage functions
    */
    
    stages_index = 0;
    
    vp_os_memset (&dispCfg, 0, sizeof (video_cfg_t));
    
    dispCfg.width = in_picture->width;
    dispCfg.height = in_picture->height;
    
    example_post_stages->stages_list[stages_index].name = "Decoded display"; // Debug info
    example_post_stages->stages_list[stages_index].type = VP_API_OUTPUT_SDL; // Debug info
    example_post_stages->stages_list[stages_index].cfg  = &dispCfg;
    example_post_stages->stages_list[stages_index++].funcs  = video_funcs;
    
    example_post_stages->length = stages_index;
    
    
    /**
    * Fill thread params for the ardrone_tool video thread
    *  - in_pic / out_pic are reference to our in_picture / out_picture
    *  - pre/post stages lists are references to our stages lists
    *  - needSetPriority and priority are used to control the video thread priority
    *   -> if needSetPriority is set to 1, the thread will try to set its priority to "priority"
    *   -> if needSetPriority is set to 0, the thread will keep its default priority (best on PC)
    */
    params->in_pic = in_picture;
    params->out_pic = out_picture;
    params->pre_processing_stages_list  = example_pre_stages;
    params->post_processing_stages_list = example_post_stages;
    params->needSetPriority = 0;
    params->priority = 0;
    
    /**
    * Start the video thread (and the video recorder thread for AR.Drone 2)
    */
    START_THREAD(video_stage, params);
    video_stage_init();
    
    video_stage_resume_thread ();
    
    return C_OK;
}

C_RESULT ardrone_tool_shutdown_custom ()
{
    // Unregister the game controller
    ardrone_tool_input_remove( &gamepad );
    
    video_stage_resume_thread(); //Resume thread to kill it !
    JOIN_THREAD(video_stage);
    
    return C_OK;
}


/**
* Declare Thread / Navdata tables
*/


BEGIN_THREAD_TABLE
THREAD_TABLE_ENTRY(video_stage, 20)
THREAD_TABLE_ENTRY(navdata_update, 20)
THREAD_TABLE_ENTRY(ardrone_control, 20)
END_THREAD_TABLE
