/*
 *  mobile_main.c
 *  Test
 *
 *  Created by Karl Leplat on 19/02/10.
 *  Copyright 2010 Parrot SA. All rights reserved.
 *
 */
#include <ardrone_tool/Academy/academy.h>
#include "mobile_main.h"
#include "wifi.h"
#include <VP_Os/vp_os_thread.h>

#ifndef STREAM_WIDTH
#define STREAM_WIDTH (hdtv360P_WIDTH)
#endif
#ifndef STREAM_HEIGHT
#define STREAM_HEIGHT (hdtv360P_HEIGHT)
#endif

//#define DEBUG_THREAD	1

static bool_t bContinue = TRUE;
ardrone_info_t ardrone_info = { 0 };

vp_stages_latency_estimation_config_t vlat;
opengl_video_stage_config_t ovsc;

void display_current_thread_priority(void)
{
    int rc;
    int priority = -1, policy = SCHED_OTHER;
    struct sched_param param;
    
    vp_os_memset(&param, 0, sizeof(param));
    rc = pthread_getschedparam(pthread_self(), &policy, &param);
    priority = param.sched_priority;
    
    printf("%s : current_thread %d, %d\n", __FUNCTION__, priority, policy);
}

BEGIN_THREAD_TABLE
THREAD_TABLE_ENTRY(mobile_main, AT_THREAD_PRIORITY)
THREAD_TABLE_ENTRY(ardrone_control, NAVDATA_THREAD_PRIORITY)
THREAD_TABLE_ENTRY(navdata_update, NAVDATA_THREAD_PRIORITY)
THREAD_TABLE_ENTRY(video_stage, VIDEO_THREAD_PRIORITY)
THREAD_TABLE_ENTRY(video_recorder, VIDEO_RECORDER_THREAD_PRIORITY)
END_THREAD_TABLE

DEFINE_THREAD_ROUTINE(mobile_main, data)
{
	C_RESULT res = C_FAIL;
	vp_com_wifi_config_t *config = NULL;
    
	mobile_main_param_t *param = (mobile_main_param_t *)data;
    video_recorder_thread_param_t video_recorder_param;
    video_recorder_param.priority = VIDEO_RECORDER_THREAD_PRIORITY;
    video_recorder_param.finish_callback = param->academy_download_callback_func;

	ardroneEngineCallback callback = param->callback;
	vp_os_memset(&ardrone_info, 0x0, sizeof(ardrone_info_t));
	
	while(((config = (vp_com_wifi_config_t *)wifi_config()) != NULL) && (strcmp(config->itfName, WIFI_ITFNAME) != 0))
	{
		PRINT("Wait WIFI connection !\n");
		vp_os_delay(250);
	}
	
	// Get drone_address
	vp_os_memcpy(&ardrone_info.drone_address[0], config->server, strlen(config->server));
	PRINT("Drone address %s\n", &ardrone_info.drone_address[0]);

    while (-1 == getDroneVersion (param->root_dir, &ardrone_info.drone_address[0], &ardroneVersion))
    {
        PRINT ("Getting AR.Drone version\n");
        vp_os_delay (250);
    }
    
    sprintf(&ardrone_info.drone_version[0], "%u.%u.%u", ardroneVersion.majorVersion, ardroneVersion.minorVersion, ardroneVersion.revision);
    
    PRINT ("ARDrone Version : %s\n", &ardrone_info.drone_version[0]);

	res = ardrone_tool_setup_com( NULL );
	
	if( FAILED(res) )
	{
		PRINT("Wifi initialization failed. It means either:\n");
		PRINT("\t* you're not root (it's mandatory because you can set up wifi connection only as root)\n");
		PRINT("\t* wifi device is not present (on your pc or on your card)\n");
		PRINT("\t* you set the wrong name for wifi interface (for example rausb0 instead of wlan0) \n");
		PRINT("\t* ap is not up (reboot card or remove wifi usb dongle)\n");
		PRINT("\t* wifi device has no antenna\n");
	}
	else
	{
        
        #define NB_IPHONE_PRE_STAGES 0

        #define NB_IPHONE_POST_STAGES 2
        
        //Alloc structs
        specific_parameters_t * params         = (specific_parameters_t *)vp_os_calloc(1, sizeof(specific_parameters_t));
        specific_stages_t * iphone_pre_stages  = (specific_stages_t*)vp_os_calloc(1, sizeof(specific_stages_t));
        specific_stages_t * iphone_post_stages = (specific_stages_t*)vp_os_calloc(1, sizeof(specific_stages_t));
        vp_api_picture_t  * in_picture         = (vp_api_picture_t*) vp_os_calloc(1, sizeof(vp_api_picture_t));
        vp_api_picture_t  * out_picture        = (vp_api_picture_t*) vp_os_calloc(1, sizeof(vp_api_picture_t));

        
        in_picture->width          = STREAM_WIDTH;
        in_picture->height         = STREAM_HEIGHT;
        
        out_picture->framerate     = 20;
        out_picture->format        = PIX_FMT_RGB565;
        out_picture->width         = STREAM_WIDTH;
        out_picture->height        = STREAM_HEIGHT;

        out_picture->y_buf         = vp_os_malloc( STREAM_WIDTH * STREAM_HEIGHT * 2 );
        out_picture->cr_buf        = NULL;
        out_picture->cb_buf        = NULL;

        out_picture->y_line_size   = STREAM_WIDTH * 2;
        out_picture->cb_line_size  = 0;
        out_picture->cr_line_size  = 0;

        //Define the list of stages size
        iphone_pre_stages->length  = NB_IPHONE_PRE_STAGES;
        iphone_post_stages->length = NB_IPHONE_POST_STAGES;
        
        //Alloc the lists
        iphone_pre_stages->stages_list  = NULL;
        iphone_post_stages->stages_list = (vp_api_io_stage_t*)vp_os_calloc(iphone_post_stages->length,sizeof(vp_api_io_stage_t));
        
        //Fill the POST-stages------------------------------------------------------
        int postStageNumber = 0;
        
        vp_os_memset (&vlat, 0x0, sizeof (vlat));
        vlat.state = 0;
        vlat.last_decoded_frame_info= (void *)&vec;
        iphone_post_stages->stages_list[postStageNumber].type  = VP_API_FILTER_DECODER;
        iphone_post_stages->stages_list[postStageNumber].cfg   = (void *)&vlat;
        iphone_post_stages->stages_list[postStageNumber++].funcs = vp_stages_latency_estimation_funcs;
        
        vp_os_memset (&ovsc, 0x0, sizeof (ovsc));
        ovsc.texture = param->videoTexture;
        ovsc.video_decoder = &vec;
        iphone_post_stages->stages_list[postStageNumber].type  = VP_API_OUTPUT_LCD;
        iphone_post_stages->stages_list[postStageNumber].cfg   = (void *)&ovsc;
        iphone_post_stages->stages_list[postStageNumber++].funcs = opengl_video_stage_funcs;
        
        params->in_pic = in_picture;
        params->out_pic = out_picture;
        params->pre_processing_stages_list = iphone_pre_stages;
        params->post_processing_stages_list = iphone_post_stages;
#if USE_THREAD_PRIORITIES
        params->needSetPriority = 1;
        params->priority = VIDEO_THREAD_PRIORITY;
#else
        params->needSetPriority = 0;
        params->priority = 0;
#endif

		START_THREAD(video_stage, params);

        if (IS_LEAST_ARDRONE2)
        {
            START_THREAD (video_recorder, (void *)&video_recorder_param);
        }

		res = ardrone_tool_init(&ardrone_info.drone_address[0], strlen(&ardrone_info.drone_address[0]), NULL, param->appName, param->usrName, param->root_dir, param->flight_dir, param->flight_storing_size, param->academy_download_callback_func);
		
		callback(ARDRONE_ENGINE_INIT_OK);
		
		ardrone_tool_set_refresh_time(1000 / kAPS);
        
#if USE_THREAD_PRIORITIES
        CHANGE_THREAD_PRIO (mobile_main, AT_THREAD_PRIORITY);
        CHANGE_THREAD_PRIO (navdata_update, NAVDATA_THREAD_PRIORITY);
        CHANGE_THREAD_PRIO (ardrone_control, NAVDATA_THREAD_PRIORITY);
#endif
        
		while( SUCCEED(res) && bContinue == TRUE )
		{
			ardrone_tool_update();
		}
		
		JOIN_THREAD(video_stage);
        if (IS_LEAST_ARDRONE2)
        {
            JOIN_THREAD (video_recorder);
        }

		res = ardrone_tool_shutdown();
	}
	
	vp_os_free (data);
	
	return (THREAD_RET)res;
}

void ardroneEnginePause( void )
{
#ifdef DEBUG_THREAD
	PRINT( "%s\n", __FUNCTION__ );
#endif
	video_stage_suspend_thread();
    if (IS_LEAST_ARDRONE2)
    {
        video_recorder_suspend_thread ();
    }
	ardrone_tool_suspend();
}

void ardroneEngineResume( void )
{
#ifdef DEBUG_THREAD
	PRINT( "%s\n", __FUNCTION__ );
#endif
	video_stage_resume_thread();
    if (IS_LEAST_ARDRONE2)
    {
        video_recorder_resume_thread ();
    }
	ardrone_tool_resume();
}

void ardroneEngineStart ( ardroneEngineCallback callback, const char *appName, const char *usrName, const char *rootdir, const char *flightdir, int flight_storing_size, academy_download_new_media academy_download_callback_func, ARDroneOpenGLTexture *videoTexture)
{
#ifdef DEBUG_THREAD
	PRINT( "%s\n", __FUNCTION__ );
#endif	
	video_stage_init ();
    video_recorder_init ();
    
	mobile_main_param_t *param = vp_os_malloc (sizeof (mobile_main_param_t));
	if (NULL != param)
	{
		param->callback = callback;
		strcpy(param->appName, appName);
		strcpy(param->usrName, usrName);
        strcpy(param->root_dir, rootdir);
        strcpy(param->flight_dir, flightdir);
        param->flight_storing_size = flight_storing_size;
        param->academy_download_callback_func = academy_download_callback_func;
        param->videoTexture = videoTexture;
		START_THREAD(mobile_main, param);
	}
}

void ardroneEngineStop (void)
{
#ifdef DEBUG_THREAD
	PRINT( "%s\n", __FUNCTION__ );
#endif	
	ardroneEnginePause();
	bContinue = FALSE;
    ardrone_tool_shutdown();
}

C_RESULT custom_update_user_input(input_state_t* input_state, uint32_t user_input)
{
#ifdef DEBUG_THREAD
	printf("%s\n", __FUNCTION__);
#endif	
	return C_OK;	
	
}

C_RESULT custom_reset_user_input(input_state_t* input_state, uint32_t user_input)
{
#ifdef DEBUG_THREAD
	printf("%s\n", __FUNCTION__);
#endif	
	return C_OK;
}

C_RESULT ardrone_tool_display_custom()
{
#ifdef DEBUG_THREAD
	printf("%s\n", __FUNCTION__);
#endif	
	return C_OK;
}
