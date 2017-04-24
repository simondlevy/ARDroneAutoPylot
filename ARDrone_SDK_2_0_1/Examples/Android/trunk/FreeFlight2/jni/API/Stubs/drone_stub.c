/*
 * drone_stub.c
 *
 *  Created on: May 10, 2011
 *      Author: Dmytro Baryskyy
 */

// VP_SDK
#include <VP_Os/vp_os_print.h>
#include <VP_Api/vp_api_thread_helper.h>

// ARDroneLib
#include <ardrone_tool/UI/ardrone_input.h>

#include "common.h"
#include <math.h>
#include "../Controller/ardrone_controller.h"
#include "../NavData/nav_data.h"
#include "ControlData.h"
#include "app.h"
#include "../Video/video_stage_renderer.h"
#include "../Callbacks/drone_proxy_callbacks.h"
#include "../Stubs/drone_config_stub.h"

static const char* TAG = "DRONE_STUB";
int errorState;
extern ControlData ctrldata;
navdata_unpacked_t ctrlnavdata;

static jobject configObj = NULL;
static jobject droneProxyObj = NULL;
static gps_info_t   gpsInfo = { 0 };
static CONFIG_STATE gpsState = CONFIG_STATE_IDLE;
static CONFIG_STATE configurationState = CONFIG_STATE_IDLE;
static CONFIG_STATE prevConfigurationState = CONFIG_STATE_IDLE;

bool_t magnetoEnabled;

void ardrone_engine_message_received(JNIEnv* env, jobject obj, ardrone_engine_message_t message)
{
	switch (message) {
	case ARDRONE_MESSAGE_CONNECTED_OK:
			LOGI(TAG, "Sending ARDRONE_MESSAGE_CONNECTED_OK");
			parrot_drone_proxy_onConnected(env, obj);
		break;
	case ARDRONE_MESSAGE_DISCONNECTED:
			LOGI(TAG, "Sending ARDRONE_MESSAGE_DISCONNECTED");
			parrot_drone_proxy_onDisconnected(env, obj);
		break;
	case ARDRONE_MESSAGE_ERR_NO_WIFI:
			LOGI(TAG, "Sending ARDRONE_MESSAGE_ERR_NO_WIFI");
			parrot_drone_proxy_onConnectionFailed(env, obj, ARDRONE_MESSAGE_ERR_NO_WIFI);
		break;
	case ARDRONE_MESSAGE_UNKNOWN_ERR:
			LOGI(TAG, "Sending ARDRONE_MESSAGE_UNKNOWN_ERR");
			parrot_drone_proxy_onConnectionFailed(env, obj, ARDRONE_MESSAGE_UNKNOWN_ERR);
		break;
	default:
			LOGW(TAG, "Unknown ardrone engine message: %d", message);
	}
}


void ardrone_academy_callback_called(const char *mediaPath, bool_t addToQueue)
{
	JNIEnv* env = NULL;

	if (g_vm) {
		(*g_vm)->AttachCurrentThread (g_vm, (JNIEnv **) &env, NULL);
	}

	if (env != NULL && droneProxyObj != NULL) {
		parrot_java_callbacks_call_void_method_string_boolean(env, droneProxyObj, "onAcademyNewMediaReady", mediaPath, addToQueue);
	} else {
		LOGW(TAG, "Academy callback. Can't get env");
	}

	if (g_vm) {
		(*g_vm)->DetachCurrentThread(g_vm);
	}
}


JNIEXPORT void JNICALL
Java_com_parrot_freeflight_drone_DroneProxy_initNavdata(JNIEnv *env, jobject obj)
{
	initControlData();

	navdata_unpacked_t navdata;
	navdata_get(&navdata);
	if (VP_SUCCEEDED(navdata_reset(&navdata)) == FALSE)
	{
		LOGW(TAG, "Nvdata reset [FAILED]");
	} else
	{
		LOGD(TAG, "Navdata reset [OK]");
	}
}


JNIEXPORT void JNICALL
Java_com_parrot_freeflight_drone_DroneProxy_connect(JNIEnv *env, jobject obj,
															jstring appName,
															jstring userName,
															jstring rootDir,
															jstring flightDir,
															jint flightStoringSize,
															jint recordingCapabilities)
{
	LOGI(TAG, "Connect called");

	droneProxyObj = (*env)->NewGlobalRef(env, obj);

	const char *str_app_name = (*env)->GetStringUTFChars(env, appName, NULL);
    const char *str_usr_name = (*env)->GetStringUTFChars(env, userName, NULL);
    const char *str_app_dir = (*env)->GetStringUTFChars(env, rootDir, NULL);
    const char *str_flight_dir = (*env)->GetStringUTFChars(env, flightDir, NULL);

	parrot_ardrone_notify_start(env, obj, ardrone_engine_message_received, str_app_name, str_usr_name, str_app_dir, str_flight_dir, flightStoringSize, ardrone_academy_callback_called, recordingCapabilities);

	(*env)->ReleaseStringUTFChars(env, appName, str_app_name);
	(*env)->ReleaseStringUTFChars(env, userName, str_usr_name);
	(*env)->ReleaseStringUTFChars(env, rootDir, str_app_dir);
	(*env)->ReleaseStringUTFChars(env, flightDir, str_flight_dir);
}


JNIEXPORT void JNICALL
Java_com_parrot_freeflight_drone_DroneProxy_pause(JNIEnv *env, jobject obj)
{
	LOGI(TAG, "Pause called");
	parrot_ardrone_notify_pause();
}


JNIEXPORT void JNICALL
Java_com_parrot_freeflight_drone_DroneProxy_setDefaultConfigurationNative(JNIEnv *env, jobject obj)
{
	setApplicationDefaultConfig();
}


JNIEXPORT void JNICALL
Java_com_parrot_freeflight_drone_DroneProxy_resume(JNIEnv *env, jobject obj)
{
	LOGI(TAG, "Resume called");
	parrot_ardrone_notify_resume();
}


JNIEXPORT void JNICALL
Java_com_parrot_freeflight_drone_DroneProxy_disconnect(JNIEnv *env, jobject obj)
{
	LOGI(TAG, "Exit called");
	parrot_ardrone_notify_exit();
}


JNIEXPORT void JNICALL
Java_com_parrot_freeflight_drone_DroneProxy_triggerTakeOff(JNIEnv *env, jobject obj)
{
	LOGI(TAG, "Trigger take off called");
	parrot_ardrone_ctrl_take_off();
}


JNIEXPORT void JNICALL
Java_com_parrot_freeflight_drone_DroneProxy_triggerEmergency(JNIEnv *env, jobject obj)
{
	LOGI(TAG, "Trigger emergency called");
	parrot_ardrone_ctrl_emergency();
}


JNIEXPORT void JNICALL
Java_com_parrot_freeflight_drone_DroneProxy_setControlValue(JNIEnv *env, jobject obj, jint command, jfloat value)
{
	switch (command)
	{
	case CONTROL_SET_GAZ:
		parrot_ardrone_ctrl_set_gaz(value);
		break;
	case CONTROL_SET_YAW:
		parrot_ardrone_ctrl_set_yaw(value);
		break;
	case CONTROL_SET_ROLL:
		parrot_ardrone_ctrl_set_roll(value);
		break;
	case CONTROL_SET_PITCH:
		parrot_ardrone_ctrl_set_pitch(value);
		break;
	default:
		LOGW(TAG, "Unknown control command %d", command);
	}
}

JNIEXPORT void JNICALL
Java_com_parrot_freeflight_drone_DroneProxy_setMagnetoEnabled(JNIEnv *env, jobject obj, jboolean enabled)
{
//	setMagnetoEnabled(enabled);
	magnetoEnabled = enabled;
}


JNIEXPORT void JNICALL
Java_com_parrot_freeflight_drone_DroneProxy_setCommandFlag(JNIEnv *env, jobject obj, jint flag, jboolean enable)
{
	set_command_flag(flag, enable);
}


JNIEXPORT void JNICALL
Java_com_parrot_freeflight_drone_DroneProxy_setDeviceOrientation(JNIEnv *env, jobject obj, jint heading, jint accuracy)
{
	ctrldata.iphone_psi = heading;

	if(ctrldata.iphone_psi > 180)
	{
		ctrldata.iphone_psi -= 360;
	}

	ctrldata.iphone_psi /= 180;
	ctrldata.iphone_psi_accuracy = accuracy;

	if (magnetoEnabled && ctrldata.iphone_psi_accuracy >= 0) {
		set_command_flag(ARDRONE_MAGNETO_CMD_ENABLE, TRUE);
	} else {
		set_command_flag(ARDRONE_MAGNETO_CMD_ENABLE, FALSE);
	}
}


void getConfigSuccess(bool_t result)
{
	if(result) {
		configurationState = CONFIG_STATE_IDLE;
	    LOGD(TAG, "CONFIGURATION GET [OK]");
	} else {
	    LOGD(TAG, "CONFIGURATION GET [FAIL]");
	}
}


void gpsConfigSuccess(bool_t result)
{
	if(result)
		gpsState = CONFIG_STATE_IDLE;
}


void checkErrors(JNIEnv* env, navdata_unpacked_t ctrlnavdata)
{
	input_state_t* input_state = ardrone_tool_input_get_state();

    if(configurationState == CONFIG_STATE_NEEDED)
    {
        configurationState = CONFIG_STATE_IN_PROGRESS;
        ARDRONE_TOOL_CONFIGURATION_GET(getConfigSuccess);
        LOGD(TAG, "CONFIGURATION GET [sent]");
    }

	if (prevConfigurationState != configurationState && configurationState == CONFIG_STATE_IDLE)
	{
		if (configObj != NULL) {
			parrot_drone_proxy_onConfigChanged(env, configObj);
			(*env)->DeleteGlobalRef(env, configObj);
			configObj = NULL;
			LOGD(TAG, "OnConfigChanged sent [OK]");
		}
	}

	prevConfigurationState = configurationState;

    if((gpsState == CONFIG_STATE_NEEDED) && configWasDone)
    {
        float64_t d_value;
        gpsState = CONFIG_STATE_IN_PROGRESS;
        d_value = gpsInfo.latitude;
        LOGD(TAG, "Userbox latitude : %lf", d_value);
        ARDRONE_TOOL_CONFIGURATION_ADDEVENT(latitude, &d_value, NULL);
        d_value = gpsInfo.longitude;
        LOGD(TAG, "Userbox longitude : %lf", d_value);
        ARDRONE_TOOL_CONFIGURATION_ADDEVENT(longitude, &d_value, NULL);
        d_value = gpsInfo.altitude;
        LOGD(TAG, "Userbox altitude : %lf", d_value);
        ARDRONE_TOOL_CONFIGURATION_ADDEVENT(altitude, &d_value, gpsConfigSuccess);
        ardrone_video_set_gps_infos(gpsInfo.latitude, gpsInfo.longitude, gpsInfo.altitude);
        LOGD(TAG, "GPS location sent [OK]");
    }

    errorState = ERROR_STATE_NONE;
    if(ardrone_navdata_client_get_num_retries())
    {
        ctrldata.navdata_connected = FALSE;
        errorState = ERROR_STATE_NAVDATA_CONNECTION;
        resetControlData();
        navdata_reset(&ctrlnavdata);
        LOGD(TAG, "NAVDATA Reset [OK]");
    }
    else
    {
        ctrldata.navdata_connected = TRUE;
        if(ardrone_academy_navdata_get_emergency_state())
        {
            if(ctrlnavdata.ardrone_state & ARDRONE_CUTOUT_MASK)
            {
                errorState = ERROR_STATE_EMERGENCY_CUTOUT;
            }
            else if(ctrlnavdata.ardrone_state & ARDRONE_MOTORS_MASK)
            {
                errorState = ERROR_STATE_EMERGENCY_MOTORS;
            }
            else if(!(ctrlnavdata.ardrone_state & ARDRONE_VIDEO_THREAD_ON))
            {
                errorState = ERROR_STATE_EMERGENCY_CAMERA;
            }
            else if(ctrlnavdata.ardrone_state & ARDRONE_ADC_WATCHDOG_MASK)
            {
                errorState = ERROR_STATE_EMERGENCY_PIC_WATCHDOG;
            }
            else if(!(ctrlnavdata.ardrone_state & ARDRONE_PIC_VERSION_MASK))
            {
                errorState = ERROR_STATE_EMERGENCY_PIC_VERSION;
            }
            else if(ctrlnavdata.ardrone_state & ARDRONE_ANGLES_OUT_OF_RANGE)
            {
                errorState = ERROR_STATE_EMERGENCY_ANGLE_OUT_OF_RANGE;
            }
            else if(ctrlnavdata.ardrone_state & ARDRONE_VBAT_LOW)
            {
                errorState = ERROR_STATE_EMERGENCY_VBAT_LOW;
            }
            else if(ctrlnavdata.ardrone_state & ARDRONE_USER_EL)
            {
                errorState = ERROR_STATE_EMERGENCY_USER_EL;
            }
            else if(ctrlnavdata.ardrone_state & ARDRONE_ULTRASOUND_MASK)
            {
                errorState = ERROR_STATE_EMERGENCY_ULTRASOUND;
            }
            else
            {
                errorState = ERROR_STATE_EMERGENCY_UNKNOWN;
            }

            FLYING_STATE currentFlyingState = ardrone_academy_navdata_get_flying_state (&ctrlnavdata);
            if (FLYING_STATE_LANDED == currentFlyingState)
            {
            	resetControlData();
            	navdata_reset(&ctrlnavdata);
            }
        }
        else
        {
            if(video_stage_get_num_retries() > VIDEO_MAX_RETRIES)
            {
                errorState = ERROR_STATE_ALERT_CAMERA;
            }
            else if(ctrlnavdata.ardrone_state & ARDRONE_VBAT_LOW)
            {
                errorState = ERROR_STATE_ALERT_VBAT_LOW;
            }
            else if(ctrlnavdata.ardrone_state & ARDRONE_ULTRASOUND_MASK)
            {
                errorState = ERROR_STATE_ALERT_ULTRASOUND;
            }
            else if(!(ctrlnavdata.ardrone_state & ARDRONE_VISION_MASK))
            {
                FLYING_STATE tmp_state = ardrone_academy_navdata_get_flying_state(&ctrlnavdata);
                if(tmp_state == FLYING_STATE_FLYING)
                {
                    errorState = ERROR_STATE_ALERT_VISION;
                }
            }

            if((input_state->user_input & (1 << ARDRONE_UI_BIT_START)) && !ardrone_academy_navdata_get_takeoff_state())
                errorState = ERROR_STATE_START_NOT_RECEIVED;
        }
    }
}

JNIEXPORT jobject JNICALL
Java_com_parrot_freeflight_drone_DroneProxy_takeNavDataSnapshot(JNIEnv *env, jobject obj, jobject navdataObj)
{
	jclass navdataCls = (*env)->FindClass(env,"com/parrot/freeflight/drone/NavData");

	if (navdataCls == NULL) {
		if ((*env)->ExceptionOccurred(env)) {
				(*env)->ExceptionDescribe(env);
		}
		LOGD(TAG, "Failed to get class com.parrot.freeflight.drone.NavData");
		return navdataObj;
	}

	if (navdataObj != NULL) {
		/*
		 *  Setting the data to the object
		 */

		// Getting current navdata
		navdata_unpacked_t navdata;

		if (VP_SUCCEEDED(navdata_get(&navdata))) {
			checkErrors(env, navdata);

			// Getting field ids
			jfieldID batteryStatusFid  = (*env)->GetFieldID(env, navdataCls, "batteryStatus",  "I"); // "I" stands for "int" type
			jfieldID flyingFid         = (*env)->GetFieldID(env, navdataCls, "flying",         "Z"); // "Z" stands for "boolean" type
			jfieldID emergencyStateFid = (*env)->GetFieldID(env, navdataCls, "emergencyState", "I");
			jfieldID numFramesFid      = (*env)->GetFieldID(env, navdataCls, "numFrames",      "I");
			jfieldID initializedFid    = (*env)->GetFieldID(env, navdataCls, "initialized",    "Z");

			// Filling the data into fields
			(*env)->SetIntField(env, navdataObj, batteryStatusFid,  navdata.navdata_demo.vbat_flying_percentage);
			(*env)->SetIntField(env, navdataObj, emergencyStateFid,  errorState);
			(*env)->SetBooleanField(env, navdataObj, flyingFid,     ardrone_academy_navdata_get_takeoff_state());
			(*env)->SetIntField(env, navdataObj, numFramesFid,		navdata.navdata_demo.num_frames);
			(*env)->SetBooleanField(env, navdataObj, initializedFid, configWasDone);

			java_set_field_bool(env, navdataObj, "recording", ardrone_academy_navdata_get_record_state());
			java_set_field_int(env, navdataObj, "usbRemainingTime", ardrone_academy_navdata_get_remaining_usb_time());
			java_set_field_bool(env, navdataObj, "usbActive", ardrone_academy_navdata_get_usb_state());
			java_set_field_bool(env, navdataObj, "cameraReady", ardrone_academy_navdata_get_camera_state());
			java_set_field_bool(env, navdataObj, "recordReady", !ardrone_academy_navdata_get_record_ready());
		} else {
			LOGW(TAG, "navdata_get [FAILED]");
		}
	} else {
		LOGE(TAG, "takeNavDataSnapshot: Illegal input parameter navdataObj. configObj == NULL");
	}

	// Removing reference to the class instance
	(*env)->DeleteLocalRef(env, navdataCls);

	return navdataObj;
}


JNIEXPORT jobject JNICALL
Java_com_parrot_freeflight_drone_DroneProxy_takeConfigSnapshot(JNIEnv *env, jobject obj, jobject configObj)
{
	LOGI(TAG, "takeConfigSnapshot Called");

	jclass configCls = (*env)->FindClass(env,"com/parrot/freeflight/drone/DroneConfig");

	if (configCls == NULL) {
		if ((*env)->ExceptionOccurred(env)) {
				(*env)->ExceptionDescribe(env);
		}

		LOGE(TAG, "Failed to get class com.parrot.freeflight.drone.DroneConfig");
		return configObj;
	}

	if (configObj != NULL) {
		// Ar.Drone Software Version
		jfieldID softVersionFid  = (*env)->GetFieldID(env, configCls, "softwareVersion",          "Ljava/lang/String;");
		jstring strSoftVersion = (*env)->NewStringUTF(env, ardrone_control_config.num_version_soft);
		(*env)->SetObjectField(env, configObj, softVersionFid, strSoftVersion);
		(*env)->DeleteLocalRef(env, strSoftVersion);

		// Ar.Drone Hardware Version
		char droneHardVersion[256] = {0};

		if (-1 == snprintf(droneHardVersion, 256*sizeof(char), "%x.%x", ardrone_control_config.num_version_mb >> 4, ardrone_control_config.num_version_mb & 0x0f)) {
			LOGW(TAG, "Can't set drone hardware version");
		}

		jfieldID droneHardVersionFid  = (*env)->GetFieldID(env, configCls, "hardwareVersion", "Ljava/lang/String;");
		jstring strDroneHardVersion = (*env)->NewStringUTF(env, droneHardVersion);
		(*env)->SetObjectField(env, configObj, droneHardVersionFid, strDroneHardVersion);
		(*env)->DeleteLocalRef(env, strDroneHardVersion);

		char hardVersion[256] = {0};
		char softVersion[256] = {0};

		if(ardrone_control_config.pic_version != 0)
		{
			 uint32_t hard_major = (ardrone_control_config.pic_version >> 27) + 1;
			 uint32_t hard_minor = (ardrone_control_config.pic_version >> 24) & 0x7;

			if (-1 == snprintf(hardVersion, 256*sizeof(char), "%x.%x", hard_major, hard_minor)) {
				LOGW(TAG, "Can't set hard version");
			}

			if (-1 == snprintf(softVersion, 256*sizeof(char), "%d.%d", (int)((ardrone_control_config.pic_version & 0xFFFFFF) >> 16),(int)(ardrone_control_config.pic_version & 0xFFFF)))
			{
				LOGW(TAG, "Can't set soft version");
			}
		}

		// Inertial software version
		jfieldID inertialSoftVerFid = (*env)->GetFieldID(env, configCls, "inertialSoftwareVersion",  "Ljava/lang/String;");
		jstring strInertialSoftVersion = (*env)->NewStringUTF(env, softVersion);
		(*env)->SetObjectField(env, configObj, inertialSoftVerFid, strInertialSoftVersion);
		(*env)->DeleteLocalRef(env, strInertialSoftVersion);

		// Inertial hardware version
		jfieldID inertiaHardVerFid  = (*env)->GetFieldID(env, configCls, "inertialHardwareVersion",  "Ljava/lang/String;");
		jstring strInertialHardVersion = (*env)->NewStringUTF(env, hardVersion);
		(*env)->SetObjectField(env, configObj, inertiaHardVerFid, strInertialHardVersion);
		(*env)->DeleteLocalRef(env, strInertialHardVersion);

		// Motor 1 type
		jfieldID motor1typeFid  = (*env)->GetFieldID(env, configCls, "motor1Vendor",  "Ljava/lang/String;");
		jstring strMotor1Type = (*env)->NewStringUTF(env, ardrone_control_config.motor1_supplier);
		(*env)->SetObjectField(env, configObj, motor1typeFid, strMotor1Type);
		(*env)->DeleteLocalRef(env, strMotor1Type);

		// Motor 2 type
		jfieldID motor2typeFid  = (*env)->GetFieldID(env, configCls, "motor2Vendor",  "Ljava/lang/String;");
		jstring strMotor2Type = (*env)->NewStringUTF(env, ardrone_control_config.motor2_supplier);
		(*env)->SetObjectField(env, configObj, motor2typeFid, strMotor2Type);
		(*env)->DeleteLocalRef(env, strMotor2Type);

		// Motor 3 type
		jfieldID motor3typeFid  = (*env)->GetFieldID(env, configCls, "motor3Vendor",  "Ljava/lang/String;");
		jstring strMotor3Type = (*env)->NewStringUTF(env, ardrone_control_config.motor3_supplier);
		(*env)->SetObjectField(env, configObj, motor3typeFid, strMotor3Type);
		(*env)->DeleteLocalRef(env, strMotor3Type);

		// Motor 4 type
		jfieldID motor4typeFid  = (*env)->GetFieldID(env, configCls, "motor4Vendor",  "Ljava/lang/String;");
		jstring strMotor4Type = (*env)->NewStringUTF(env, ardrone_control_config.motor4_supplier);
		(*env)->SetObjectField(env, configObj, motor4typeFid, strMotor4Type);
		(*env)->DeleteLocalRef(env, strMotor4Type);;

		// Motor 1 hardware version
		jfieldID motor1HardVersionFid  = (*env)->GetFieldID(env, configCls, "motor1HardVersion",  "Ljava/lang/String;");
		jstring strMotor1Hard = (*env)->NewStringUTF(env, ardrone_control_config.motor1_hard);
		(*env)->SetObjectField(env, configObj, motor1HardVersionFid, strMotor1Hard);
		(*env)->DeleteLocalRef(env, strMotor1Hard);

		// Motor 2 hardware version
		jfieldID motor2HardVersionFid  = (*env)->GetFieldID(env, configCls, "motor2HardVersion",  "Ljava/lang/String;");
		jstring strMotor2Hard = (*env)->NewStringUTF(env, ardrone_control_config.motor2_hard);
		(*env)->SetObjectField(env, configObj, motor2HardVersionFid, strMotor2Hard);
		(*env)->DeleteLocalRef(env, strMotor2Hard);

		// Motor 3 hardware version
		jfieldID motor3HardVersionFid  = (*env)->GetFieldID(env, configCls, "motor3HardVersion",  "Ljava/lang/String;");
		jstring strMotor3Hard = (*env)->NewStringUTF(env, ardrone_control_config.motor3_hard);
		(*env)->SetObjectField(env, configObj, motor3HardVersionFid, strMotor3Hard);
		(*env)->DeleteLocalRef(env, strMotor3Hard);

		// Motor 4 hardware version
		jfieldID motor4HardVersionFid  = (*env)->GetFieldID(env, configCls, "motor4HardVersion",  "Ljava/lang/String;");
		jstring strMotor4Hard = (*env)->NewStringUTF(env, ardrone_control_config.motor4_hard);
		(*env)->SetObjectField(env, configObj, motor4HardVersionFid, strMotor4Hard);
		(*env)->DeleteLocalRef(env, strMotor4Hard);

		// Motor 1 software version
		jfieldID motor1SoftVersionFid  = (*env)->GetFieldID(env, configCls, "motor1SoftVersion",  "Ljava/lang/String;");
		jstring strMotor1Soft = (*env)->NewStringUTF(env, ardrone_control_config.motor1_soft);
		(*env)->SetObjectField(env, configObj, motor1SoftVersionFid, strMotor1Soft);
		(*env)->DeleteLocalRef(env, strMotor1Soft);

		// Motor 2 software version
		jfieldID motor2SoftVersionFid  = (*env)->GetFieldID(env, configCls, "motor2SoftVersion",  "Ljava/lang/String;");
		jstring strMotor2Soft = (*env)->NewStringUTF(env, ardrone_control_config.motor2_soft);
		(*env)->SetObjectField(env, configObj, motor2SoftVersionFid, strMotor2Soft);
		(*env)->DeleteLocalRef(env, strMotor2Soft);

		// Motor 3 software version
		jfieldID motor3SoftVersionFid  = (*env)->GetFieldID(env, configCls, "motor3SoftVersion",  "Ljava/lang/String;");
		jstring strMotor3Soft = (*env)->NewStringUTF(env, ardrone_control_config.motor3_soft);
		(*env)->SetObjectField(env, configObj, motor3SoftVersionFid, strMotor3Soft);
		(*env)->DeleteLocalRef(env, strMotor3Soft);

		// Motor 4 software version
		jfieldID motor4SoftVersionFid  = (*env)->GetFieldID(env, configCls, "motor4SoftVersion",  "Ljava/lang/String;");
		jstring strMotor4Soft = (*env)->NewStringUTF(env, ardrone_control_config.motor4_soft);
		(*env)->SetObjectField(env, configObj, motor4SoftVersionFid, strMotor4Soft);
		(*env)->DeleteLocalRef(env, strMotor4Soft);

		// Network name
		jfieldID networkNameFid  = (*env)->GetFieldID(env, configCls, "networkName",  "Ljava/lang/String;");
		jstring strNetworkName = (*env)->NewStringUTF(env, ardrone_control_config.ssid_single_player);
		(*env)->SetObjectField(env, configObj, networkNameFid, strNetworkName);
		(*env)->DeleteLocalRef(env, strNetworkName);

		// Pairing
		jfieldID ownerMacFid  = (*env)->GetFieldID(env, configCls, "ownerMac",  "Ljava/lang/String;");
		jstring strOwnerMac = (*env)->NewStringUTF(env, ardrone_control_config.owner_mac);
		(*env)->SetObjectField(env, configObj, ownerMacFid, strOwnerMac);
		(*env)->DeleteLocalRef(env, strOwnerMac);

		// Altitude Limit
		jfieldID altitudeLimitedFid  = (*env)->GetFieldID(env, configCls, "altitudeLimit",  "I");
		(*env)->SetIntField(env, configObj, altitudeLimitedFid, ardrone_control_config.altitude_max / 1000);

		// Adaptive video
		jfieldID adaptiveVideoFid  = (*env)->GetFieldID(env, configCls, "adaptiveVideo",  "Z");
		(*env)->SetBooleanField(env, configObj, adaptiveVideoFid,
			(ARDRONE_VARIABLE_BITRATE_MODE_DYNAMIC == ardrone_control_config.bitrate_ctrl_mode) ? TRUE : FALSE);

		// Video codec
		jfieldID videoCodecFid  = (*env)->GetFieldID(env, configCls, "videoCodec",  "I");
		(*env)->SetIntField(env, configObj, videoCodecFid, (jint) (ardrone_control_config.video_codec));
		//(*env)->SetIntField(env, configObj, videoCodecFid, (jint) (ardrone_control_config.codec));
		// Outdoor hull
		jfieldID outdoorHullFid  = (*env)->GetFieldID(env, configCls, "outdoorHull",  "Z");
		(*env)->SetBooleanField(env, configObj, outdoorHullFid, ardrone_control_config.flight_without_shell ? TRUE : FALSE);

		// Outdoor flight
		jfieldID outdoorFlightFid  = (*env)->GetFieldID(env, configCls, "outdoorFlight",  "Z");
		(*env)->SetBooleanField(env, configObj, outdoorFlightFid, ardrone_control_config.outdoor ? TRUE : FALSE);

		// Yaw speed max
		jfieldID yawSpeedMaxFid  = (*env)->GetFieldID(env, configCls, "yawSpeedMax",  "I");
		(*env)->SetIntField(env, configObj, yawSpeedMaxFid, (jint)((float)round(ardrone_control_config.control_yaw * RAD_TO_DEG)));

		// Vertical speed max
		jfieldID vertSpeedMaxFid  = (*env)->GetFieldID(env, configCls, "vertSpeedMax",  "I");
		(*env)->SetIntField(env, configObj, vertSpeedMaxFid, (jint)(ardrone_control_config.control_vz_max));

		// Tilt
		jfieldID tiltFid  = (*env)->GetFieldID(env, configCls, "tilt",  "I");
		(*env)->SetIntField(env, configObj, tiltFid, (jint)((float)round(ardrone_control_config.euler_angle_max * RAD_TO_DEG)));

		// Device tilt
		jfieldID devceTiltFid  = (*env)->GetFieldID(env, configCls, "deviceTiltMax",  "I");
		(*env)->SetIntField(env, configObj, devceTiltFid, (jint)((float)round(ardrone_control_config.control_iphone_tilt * RAD_TO_DEG)));

		// Video record on USB
		jfieldID recordOnUsbFid = (*env)->GetFieldID(env, configCls, "recordOnUsb", "Z");
		(*env)->SetBooleanField(env, configObj, recordOnUsbFid, ardrone_control_config.video_on_usb);
	} else {
		LOGE(TAG, "takeConfigSnapshot: Illegal input parameter configObj. configObj == NULL");
	}

	// Removing reference to the class instance
	(*env)->DeleteLocalRef(env, configCls);


	return configObj;
}


JNIEXPORT void JNICALL
Java_com_parrot_freeflight_drone_DroneProxy_resetConfigToDefaults(JNIEnv *env, jobject obj)
{
		ardrone_control_config.indoor_euler_angle_max = ardrone_application_default_config.indoor_euler_angle_max;
		ARDRONE_TOOL_CONFIGURATION_ADDEVENT(indoor_euler_angle_max, &ardrone_control_config.indoor_euler_angle_max, NULL);

		ardrone_control_config.indoor_control_vz_max = ardrone_application_default_config.indoor_control_vz_max;
		ARDRONE_TOOL_CONFIGURATION_ADDEVENT(indoor_control_vz_max, &ardrone_control_config.indoor_control_vz_max, NULL);

		ardrone_control_config.indoor_control_yaw = ardrone_application_default_config.indoor_control_yaw;
		ARDRONE_TOOL_CONFIGURATION_ADDEVENT(indoor_control_yaw, &ardrone_control_config.indoor_control_yaw, NULL);

		ardrone_control_config.outdoor_euler_angle_max = ardrone_application_default_config.outdoor_euler_angle_max;
		ARDRONE_TOOL_CONFIGURATION_ADDEVENT(outdoor_euler_angle_max, &ardrone_control_config.outdoor_euler_angle_max, NULL);

		ardrone_control_config.outdoor_control_vz_max = ardrone_application_default_config.outdoor_control_vz_max;
		ARDRONE_TOOL_CONFIGURATION_ADDEVENT(outdoor_control_vz_max, &ardrone_control_config.outdoor_control_vz_max, NULL);

		ardrone_control_config.outdoor_control_yaw = ardrone_application_default_config.outdoor_control_yaw;
		ARDRONE_TOOL_CONFIGURATION_ADDEVENT(outdoor_control_yaw, &ardrone_control_config.outdoor_control_yaw, NULL);

		ardrone_control_config.outdoor = ardrone_application_default_config.outdoor;
		ARDRONE_TOOL_CONFIGURATION_ADDEVENT(outdoor, &ardrone_control_config.outdoor, NULL);

		ardrone_control_config.euler_angle_max = ardrone_application_default_config.euler_angle_max;
		ARDRONE_TOOL_CONFIGURATION_ADDEVENT(euler_angle_max, &ardrone_control_config.euler_angle_max, NULL);

		ardrone_control_config.control_vz_max = ardrone_application_default_config.control_vz_max;
		ARDRONE_TOOL_CONFIGURATION_ADDEVENT(control_vz_max, &ardrone_control_config.control_vz_max, NULL);

		ardrone_control_config.control_yaw = ardrone_application_default_config.control_yaw;
		ARDRONE_TOOL_CONFIGURATION_ADDEVENT(control_yaw, &ardrone_control_config.control_yaw, NULL);

		ardrone_control_config.outdoor_euler_angle_max = ardrone_application_default_config.outdoor_euler_angle_max;
		ARDRONE_TOOL_CONFIGURATION_ADDEVENT(euler_angle_max, &ardrone_control_config.euler_angle_max, NULL);

		ardrone_control_config.control_vz_max = ardrone_application_default_config.control_vz_max;
		ARDRONE_TOOL_CONFIGURATION_ADDEVENT(control_vz_max, &ardrone_control_config.control_vz_max, NULL);

		ardrone_control_config.control_yaw = ardrone_application_default_config.control_yaw;
		ARDRONE_TOOL_CONFIGURATION_ADDEVENT(control_yaw, &ardrone_control_config.control_yaw, NULL);

		ardrone_control_config.control_iphone_tilt = ardrone_application_default_config.control_iphone_tilt;
		ARDRONE_TOOL_CONFIGURATION_ADDEVENT(control_iphone_tilt, &ardrone_control_config.control_iphone_tilt, NULL);

		ardrone_control_config.flight_without_shell = ardrone_application_default_config.flight_without_shell;
		ARDRONE_TOOL_CONFIGURATION_ADDEVENT(flight_without_shell, &ardrone_control_config.flight_without_shell, NULL);

		ardrone_control_config.altitude_max = ardrone_application_default_config.altitude_max;
		ARDRONE_TOOL_CONFIGURATION_ADDEVENT(altitude_max, &ardrone_control_config.altitude_max, NULL);

//		ardrone_control_config.bitrate_ctrl_mode = ardrone_application_default_config.bitrate_ctrl_mode;
//		ARDRONE_TOOL_CONFIGURATION_ADDEVENT(bitrate_ctrl_mode, &ardrone_control_config.bitrate_ctrl_mode, NULL);
//
//		ardrone_control_config.video_codec = ardrone_application_default_config.video_codec;
//		ARDRONE_TOOL_CONFIGURATION_ADDEVENT(video_codec, &ardrone_control_config.video_codec, NULL);

		LOGD(TAG, "Reset config to defaults [OK]");
}


JNIEXPORT void JNICALL
Java_com_parrot_freeflight_drone_DroneProxy_triggerConfigUpdateNative(JNIEnv *env, jobject obj)
{
	LOGI(TAG, "requestConfigNative called");
	configurationState = CONFIG_STATE_NEEDED;

	if (configObj != NULL) {
		(*env)->DeleteGlobalRef(env, configObj);
		configObj = NULL;
	}

	configObj = (*env)->NewGlobalRef(env, obj);
}


JNIEXPORT jobject JNICALL
Java_com_parrot_freeflight_drone_DroneProxy_switchCamera(JNIEnv *env, jobject obj)
{
	parrot_ardrone_ctrl_switch_camera(NULL);
}

JNIEXPORT void JNICALL
Java_com_parrot_freeflight_drone_DroneProxy_flatTrimNative(JNIEnv *env, jobject obj)
{
	parrot_ardrone_ctrl_set_flat_trim();
}

JNIEXPORT jobject JNICALL
Java_com_parrot_freeflight_drone_DroneProxy_takePhoto(JNIEnv *env, jobject obj)
{
	if (ardrone_academy_navdata_get_camera_state() == TRUE) {
		if (ardrone_academy_navdata_screenshot()) {
			LOGD(TAG, "Screen Shot Request [OK]");
		} else {
			LOGW(TAG, "Screen Shot Request [FAILED]");
		}
	} else {
		LOGW(TAG, "Camera is not ready!");
	}
}

JNIEXPORT jobject JNICALL
Java_com_parrot_freeflight_drone_DroneProxy_record(JNIEnv *env, jobject obj)
{
    bool_t record_state = ardrone_academy_navdata_get_record_ready();

    if (TRUE == ardrone_academy_navdata_record())
    {
    	if (record_state)
    	{
    		video_stage_encoded_recorder_enable (0, 0);
      	}
    }
}

JNIEXPORT jobject JNICALL
Java_com_parrot_freeflight_drone_DroneProxy_calibrateMagneto(JNIEnv *env, jobject obj)
{
	ardrone_at_set_calibration (ARDRONE_CALIBRATION_DEVICE_MAGNETOMETER);
}

JNIEXPORT jobject JNICALL
Java_com_parrot_freeflight_drone_DroneProxy_doFlip(JNIEnv *env, jobject obj)
{
	 string_t anim = "18,15";
	 ARDRONE_TOOL_CONFIGURATION_ADDEVENT(flight_anim, anim, NULL);
}

JNIEXPORT jobject JNICALL
Java_com_parrot_freeflight_drone_DroneProxy_setLocation(JNIEnv *env, jobject obj, jdouble lat, jdouble lon, jdouble alt)
{
	 if(gpsState == CONFIG_STATE_IDLE)
	 {
	       gpsInfo.latitude = lat;
	       gpsInfo.longitude = lon;
	       gpsInfo.altitude = alt;

	       gpsState = CONFIG_STATE_NEEDED;

	       LOGD(TAG, "GPS Config Message Received");
	 }
}

