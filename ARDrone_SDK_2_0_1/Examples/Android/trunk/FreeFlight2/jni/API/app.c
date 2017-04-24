/*
 * app.c
 *
 *  Created on: May 4, 2011
 *      Author: Dmytro Baryskyy
 */

#include <ardrone_tool/Academy/academy.h>
#include <VP_Os/vp_os_thread.h>
#include "common.h"
#include "ControlData.h"
#include "Controller/virtual_gamepad.h"
#include "app.h"

#ifndef STREAM_WIDTH
#define STREAM_WIDTH (hdtv360P_WIDTH)
#endif
#ifndef STREAM_HEIGHT
#define STREAM_HEIGHT (hdtv360P_HEIGHT)
#endif

extern ControlData ctrldata;
//#define DEBUG_THREAD	1

static bool_t bContinue = TRUE;
ardrone_info_t ardrone_info = { 0 };

vp_stages_latency_estimation_config_t vlat;
opengl_video_stage_config_t ovsc;


static const char* TAG = "APP";
char drone_address[16];

JavaVM* g_vm = NULL;

BEGIN_THREAD_TABLE
THREAD_TABLE_ENTRY(app_main, AT_THREAD_PRIORITY)
THREAD_TABLE_ENTRY(ardrone_control, NAVDATA_THREAD_PRIORITY)
THREAD_TABLE_ENTRY(navdata_update, NAVDATA_THREAD_PRIORITY)
THREAD_TABLE_ENTRY(video_stage, VIDEO_THREAD_PRIORITY)
THREAD_TABLE_ENTRY(video_recorder, VIDEO_RECORDER_THREAD_PRIORITY)
END_THREAD_TABLE


JNIEXPORT jint JNICALL
JNI_OnLoad(JavaVM *vm, void *reserved)
{
	LOGI(TAG, "Library has been loaded");

	// Saving the reference to the java virtual machine
	g_vm = vm;

	// Return the JNI version
	return JNI_VERSION_1_6;
}

DEFINE_THREAD_ROUTINE(app_main, data)
{
	LOGI(TAG, "app_main thread started [OK]" );
	C_RESULT res = C_FAIL;
	vp_com_wifi_config_t* config = NULL;

	JNIEnv* env = NULL;

	if (g_vm) {
		(*g_vm)->AttachCurrentThread (g_vm, (JNIEnv **) &env, NULL);
	}

	bContinue = TRUE;
	mobile_main_param_t *param = data;

    video_recorder_thread_param_t video_recorder_param;
    video_recorder_param.priority = VIDEO_RECORDER_THREAD_PRIORITY;
    video_recorder_param.finish_callback = param->academy_download_callback_func;

	vp_os_memset(&ardrone_info, 0x0, sizeof(ardrone_info_t));

	while ((config = (vp_com_wifi_config_t *)wifi_config()) != NULL && strlen(config->itfName) == 0)
	{
		//Waiting for wifi initialization
		vp_os_delay(250);

		if (ardrone_tool_exit() == TRUE) {
			if (param != NULL && param->callback != NULL) {
				param->callback(env, param->obj, ARDRONE_MESSAGE_DISCONNECTED);
			}
			return 0;
		}
	}

	LOGD(TAG, "WIFI is available. Trying to get AR.Drone IP address..." );

	vp_os_memcpy(&ardrone_info.drone_address[0], config->server, strlen(config->server));
	LOGI(TAG, "AR.Drone IP address: %s", ardrone_info.drone_address);

    while (-1 == getDroneVersion (param->root_dir, &ardrone_info.drone_address[0], &ardroneVersion))
    {
        LOGD (TAG, "Getting AR.Drone version");
        vp_os_delay (250);
    }

    sprintf(&ardrone_info.drone_version[0], "%u.%u.%u", ardroneVersion.majorVersion, ardroneVersion.minorVersion, ardroneVersion.revision);

    LOGD (TAG, "ARDrone Version : %s\n", &ardrone_info.drone_version[0]);
	LOGI(TAG, "Drone Family: %d", ARDRONE_VERSION());

	res = ardrone_tool_setup_com( NULL );

	if( FAILED(res) )
	{
		LOGW(TAG, "Setup com failed");
		LOGW(TAG, "Wifi initialization failed. It means either:");
		LOGW(TAG, "\t* you're not root (it's mandatory because you can set up wifi connection only as root)\n");
		LOGW(TAG, "\t* wifi device is not present (on your pc or on your card)\n");
		LOGW(TAG, "\t* you set the wrong name for wifi interface (for example rausb0 instead of wlan0) \n");
		LOGW(TAG, "\t* ap is not up (reboot card or remove wifi usb dongle)\n");
		LOGW(TAG, "\t* wifi device has no antenna\n");

		if (param != NULL && param->callback != NULL) {
			param->callback(env, param->obj, ARDRONE_MESSAGE_ERR_NO_WIFI);
		}
	}
	else
	{
		LOGD(TAG, "ardrone_tool_setup_com [OK]");
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
            LOGD(TAG, "Video recorder thread start [OK]");
        }

		LOGI(TAG, "Processing ardrone_tool_init. App name: %s, UserName: %s", param->app_name, param->user_name);
		LOGI(TAG, "Root Dir: %s",  param->root_dir);
		LOGI(TAG, "Flight Dir: %s, Flight size: %d", param->flight_dir, param->flight_storing_size);

		res = ardrone_tool_init(&ardrone_info.drone_address[0], strlen(&ardrone_info.drone_address[0]), NULL, param->app_name, param->user_name, param->root_dir, param->flight_dir, param->flight_storing_size, param->academy_download_callback_func);

		if(SUCCEED(res))
		{
			LOGD(TAG, "AR.Drone tool initialization [OK]");

			ardrone_tool_input_add(&virtual_gamepad);
			LOGD(TAG, "Virtual gamepad has been added");

			if (param != NULL && param->callback != NULL) {
				param->callback(env, param->obj, ARDRONE_MESSAGE_CONNECTED_OK);
			}
		} else {
			if (param != NULL && param->callback != NULL) {
				param->callback(env, param->obj, ARDRONE_MESSAGE_UNKNOWN_ERR);
			}

			LOGE(TAG, "AR.Drone tool initialization [FAILED]");
			bContinue = FALSE;
		}

		res = ardrone_tool_set_refresh_time(1000 / kAPS);

#if USE_THREAD_PRIORITIES
        CHANGE_THREAD_PRIO (app_main, AT_THREAD_PRIORITY);
        CHANGE_THREAD_PRIO (navdata_update, NAVDATA_THREAD_PRIORITY);
        CHANGE_THREAD_PRIO (ardrone_control, NAVDATA_THREAD_PRIORITY);
#endif

		while( SUCCEED(res) && bContinue == TRUE )
		{
			ardrone_tool_update();
		}

		JOIN_THREAD(video_stage);
		LOGD(TAG, "Video stage thread stopped [OK]");

        if (IS_LEAST_ARDRONE2)
        {
            JOIN_THREAD (video_recorder);
            LOGD(TAG, "Video recorder thread stopped [OK]");
        }

	    /* Unregistering for the current device */
	    ardrone_tool_input_remove( &virtual_gamepad );

		res = ardrone_tool_shutdown();
		LOGD(TAG, "AR.Drone tool shutdown [OK]");

		if (param != NULL && param->callback != NULL) {
			param->callback(env, param->obj, ARDRONE_MESSAGE_DISCONNECTED);
		}
	}

	vp_os_free (data);
	data = NULL;

	(*env)->DeleteGlobalRef(env, param->obj);

	if (g_vm) {
		(*g_vm)->DetachCurrentThread (g_vm);
	}

	LOGI(TAG, "app_main thread has been stopped.");

	return (THREAD_RET) res;
}


JNIEXPORT void JNICALL
JNI_OnUnload(JavaVM *vm, void *reserved)
{
	g_vm = NULL;

	LOGI(TAG, "Library has been unloaded");
}


void parrot_ardrone_notify_start(JNIEnv* env,
										jobject obj,
										ardroneEngineCallback callback,
										const char *appName,
										const char *userName,
										const char* rootdir,
										const char* flightdir,
										int flight_storing_size,
										academy_download_new_media academy_download_callback_func,
										VIDEO_RECORDING_CAPABILITY recordingCapability)
{
	video_stage_init();
	video_recorder_init();

	mobile_main_param_t *param = vp_os_malloc(sizeof(mobile_main_param_t));

	if (NULL != param) {
		param->obj = (*env)->NewGlobalRef(env, obj);
		param->callback = callback;

		vp_os_memset(&param->app_name, 0, STRING_BUFFER_LENGTH);
		vp_os_memset(&param->user_name, 0, STRING_BUFFER_LENGTH);
		vp_os_memset(&param->root_dir, 0, STRING_BUFFER_LENGTH);
		vp_os_memset(&param->flight_dir, 0, STRING_BUFFER_LENGTH);

		strncpy(param->app_name, appName, STRING_BUFFER_LENGTH);
		strncpy(param->user_name, userName, STRING_BUFFER_LENGTH);
		strncpy(param->root_dir, rootdir, STRING_BUFFER_LENGTH);
		strncpy(param->flight_dir, flightdir, STRING_BUFFER_LENGTH);
		param->flight_storing_size = flight_storing_size;
		param->academy_download_callback_func = academy_download_callback_func;

		ctrldata.recordingCapability = recordingCapability;

		START_THREAD(app_main, param);
	}
}


void parrot_ardrone_notify_exit()
{
	parrot_ardrone_notify_pause();
	bContinue = FALSE;

	ardrone_tool_shutdown();

	LOGD(TAG, "AR.Drone Tool Stop [OK]");
}


void parrot_ardrone_notify_pause()
{
	video_stage_suspend_thread();

	if (IS_LEAST_ARDRONE2)
	{
		video_recorder_suspend_thread();
	}

	ardrone_tool_suspend();

	LOGD(TAG, "AR.Drone Tool Pause [OK]");
}


void parrot_ardrone_notify_resume()
{
	video_stage_resume_thread();

	if (IS_LEAST_ARDRONE2)
	{
		video_recorder_resume_thread();
	}

	ardrone_tool_resume();

	LOGD(TAG, "AR.Drone Tool Resume [OK]");
}


C_RESULT custom_update_user_input(input_state_t* input_state, uint32_t user_input)
{
	return C_OK;
}


C_RESULT custom_reset_user_input(input_state_t* input_state, uint32_t user_input)
{
	return C_OK;
}


/* The event loop calls this method for the exit condition */
bool_t ardrone_tool_exit()
{
  return bContinue == FALSE ? TRUE : FALSE;
}


C_RESULT ardrone_tool_display_custom()
{
	return C_OK;
}

