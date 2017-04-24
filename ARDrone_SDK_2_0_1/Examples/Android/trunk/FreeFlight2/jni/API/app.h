/*
 * app.h
 *
 *  Created on: May 4, 2011
 *      Author: Dmytro Baryskyy
 */

#ifndef APP_H_
#define APP_H_

#include <VP_Api/vp_api_thread_helper.h>
#include <academy_common.h>
#define STRING_BUFFER_LENGTH 512

// Put 1 if you want to set thread priorities (else put 0)
#define USE_THREAD_PRIORITIES (1)

/**
 * Priorities for each "rt" threads
 * Must be between 15 and 43
 * Higher means more priority
 */
#define AT_THREAD_PRIORITY (47)
#define VIDEO_THREAD_PRIORITY (31)
#define NAVDATA_THREAD_PRIORITY (31)
#define VIDEO_RECORDER_THREAD_PRIORITY (15)


PROTO_THREAD_ROUTINE(app_main, data);

typedef enum {
	ARDRONE_MESSAGE_UNKNOWN_ERR = -1,
	ARDRONE_MESSAGE_CONNECTED_OK,
	ARDRONE_MESSAGE_DISCONNECTED,
	ARDRONE_MESSAGE_ERR_NO_WIFI
} ardrone_engine_message_t;

typedef void (*ardroneEngineCallback)(JNIEnv* /*env*/, jobject /*obj*/, ardrone_engine_message_t /*error*/);

typedef struct {
	ardroneEngineCallback callback;
	jobject obj;
	char app_name[STRING_BUFFER_LENGTH];
	char user_name[STRING_BUFFER_LENGTH];
    char root_dir[STRING_BUFFER_LENGTH];
    char flight_dir[STRING_BUFFER_LENGTH];
    int flight_storing_size;
    academy_download_new_media academy_download_callback_func;
} mobile_main_param_t;

extern ardrone_info_t ardrone_info;

extern void parrot_ardrone_notify_start(JNIEnv* env, jobject obj,
		ardroneEngineCallback callback,
		const char *appName,
		const char *userName,
		const char* rootdir,
		const char* flightdir,
		int flight_storing_size,
		academy_download_new_media academy_download_callback_func,
		VIDEO_RECORDING_CAPABILITY recordingCapability);
extern void parrot_ardrone_notify_pause();
extern void parrot_ardrone_notify_resume();
extern void parrot_ardrone_notify_exit();

PROTO_THREAD_ROUTINE(app_main, data);
PROTO_THREAD_ROUTINE(video_stage_player, data);

#endif /* APP_H_ */
