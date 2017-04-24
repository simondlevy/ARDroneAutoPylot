//
// ConstantsAndMacros.h
//  Constants and macros for opengl view.
//
//  Created by Frédéric D'HAEYER on 09/10/30.
//  Copyright 2009 Parrot SA. All rights reserved.
//
// Macros
#ifndef _CONSTANTS_AND_MACROS_H_
#define _CONSTANTS_AND_MACROS_H_
#include <ardrone_api.h>
#include <control_states.h>
#include <ardrone_tool/ardrone_version.h>
#include <ardrone_tool/ardrone_tool.h>
#include <ardrone_tool/ardrone_tool_configuration.h>
#include <ardrone_tool/Academy/academy.h>
#include <ardrone_tool/Academy/academy_download.h>
#include <ardrone_tool/Control/ardrone_control.h>
#include <ardrone_tool/Control/ardrone_control_ack.h>
#include <ardrone_tool/Control/ardrone_control_configuration.h>
#include <ardrone_tool/Navdata/ardrone_navdata_client.h>
#include <ardrone_tool/UI/ardrone_input.h>
#include <ardrone_tool/Com/config_com.h>
#include <ardrone_tool/Video/video_stage.h>
#include <ardrone_tool/Video/video_stage_latency_estimation.h>
#include <ardrone_tool/Video/video_recorder_pipeline.h>
#include <ardrone_tool/Video/video_navdata_handler.h>

#include <utils/ardrone_time.h>
#include <utils/ardrone_date.h>

#include <Maths/time.h>

#include <VP_Os/vp_os.h>
#include <VP_Os/vp_os_print.h>
#include <VP_Os/vp_os_types.h>
#include <VP_Os/vp_os_signal.h>
#include <VP_Os/vp_os_malloc.h>
#include <VP_Os/vp_os_delay.h>

#include <VP_Api/vp_api.h>
#include <VP_Api/vp_api_error.h>
#include <VP_Api/vp_api_stage.h>
#include <VP_Api/vp_api_picture.h>
#include <VP_Api/vp_api_thread_helper.h>

#include <VLIB/Stages/vlib_stage_decode.h>

#include <VLIB/video_codec.h>

#include <iniparser3.0b/src/iniparser.h>

#include <time.h>
#include <sys/time.h>
#include <unistd.h>
#include <sys/socket.h>
#include <sys/sysctl.h>
#include <net/if.h>
#include <net/if_dl.h>

#include <TargetConditionals.h>
#include <OpenGLES/ES2/gl.h>
#include <OpenGLES/ES2/glext.h>
#include "opengl_stage.h"
#include "video_stage_io_file.h"
#include "mobile_main.h"
#include "wifi.h"
#include "navdata.h"
#include "ControlData.h"
#include "hardware_capabilites.h"

#ifdef __OBJC__
#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import <AVFoundation/AVFoundation.h>
#import <MediaPlayer/MediaPlayer.h>
#import <UIKit/UIKit.h>
#import <OpenGLES/EAGL.h>
#import <CoreMotion/CoreMotion.h>
#import <CoreLocation/CoreLocation.h>
#import <SystemConfiguration/SystemConfiguration.h>
#import "quicktime_encoder_stage.h"
#import <QuartzCore/QuartzCore.h>
#endif

#if TARGET_CPU_X86 == 1 // We are on iPhone simulator
#define WIFI_ITFNAME "en1"
#endif // TARGET_CPU_X86

#if TARGET_CPU_ARM == 1 // We are on real iPhone
#define WIFI_ITFNAME "en0"
#endif // TARGET_CPU_ARM

// How many times a second to refresh the screen
#define kFPS 30		// Frame per second
#define kAPS 40		// Number of accelerometer() function calls by second 

// Pilot Academy define
#define GPS_TIMEOUT             3.0f
#define VIDEO_FILENAME_SIZE     256

//#define CHECK_OPENGL_ERROR() ({ GLenum __error = glGetError(); if(__error) NSLog(@"OpenGLES error 0x%04X in %s\n", __error, __FUNCTION__); (__error ? NO : YES); })

#define ARDroneEngineLocalizeString(str) ([[NSBundle mainBundle] localizedStringForKey :str value:@"" table:@"languages"])
#define ARDroneEngineLocalizeStringUpperCase(str) ([[[NSBundle mainBundle] localizedStringForKey :str value:@"" table:@"languages"] uppercaseString])

//#define WRITE_DEBUG_ACCELERO
//#define ENABLE_AUTO_TVOUT
//#define INTERFACE_WITH_DEBUG

#endif // _CONSTANTS_AND_MACROS_H_
