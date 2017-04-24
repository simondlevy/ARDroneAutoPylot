/*
 *  mobile_main.h
 *  Test
 *
 *  Created by Karl Leplat on 19/02/10.
 *  Copyright 2010 Parrot SA. All rights reserved.
 *
 */
#ifndef _MOBILE_MAIN_H_
#define _MOBILE_MAIN_H_
#include "ConstantsAndMacros.h"
#include "ARDroneTypes.h"

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

typedef enum
{
	ARDRONE_ENGINE_INIT_OK,
	ARDRONE_ENGINE_MAX
} ARDRONE_ENGINE_MESSAGE;

typedef void (*ardroneEngineCallback)(ARDRONE_ENGINE_MESSAGE msg);

typedef struct {
	ardroneEngineCallback callback;
	char appName[APPLI_NAME_SIZE];
	char usrName[USER_NAME_SIZE];
    char root_dir[ROOT_NAME_SIZE];
    char flight_dir[ROOT_NAME_SIZE];
    int flight_storing_size;
    academy_download_new_media academy_download_callback_func;
    ARDroneOpenGLTexture *videoTexture;

} mobile_main_param_t;

extern ardrone_info_t ardrone_info;

void ardroneEnginePause( void );
void ardroneEngineResume( void );
void ardroneEngineStart( ardroneEngineCallback callback, const char *appName, const char *usrName, const char *rootdir, const char *flightdir, int flight_storing_size, academy_download_new_media academy_download_callback_func, ARDroneOpenGLTexture *videoTextur);
void ardroneEngineStop( void );

PROTO_THREAD_ROUTINE(mobile_main, data);
PROTO_THREAD_ROUTINE(video_stage_player, data);

#endif