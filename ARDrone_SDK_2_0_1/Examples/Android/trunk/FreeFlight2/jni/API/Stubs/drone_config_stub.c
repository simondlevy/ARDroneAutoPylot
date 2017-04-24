/*
 * drone_confg_stub.c
 *
 *  Created on: Jun 10, 2011
 *      Author: Dmytro Baryskyy
 */


#include "common.h"
#include "drone_config_stub.h"

static jobject configObj = NULL;

static const char* TAG = "DRONE_CONFIG_STUB";

JNIEXPORT void JNICALL
Java_com_parrot_freeflight_drone_DroneConfig_updateOutdoorHullNative(JNIEnv *env, jobject obj)
{
	jclass configCls = (*env)->GetObjectClass(env, obj);

	// Outdoor hull
	jfieldID outdoorHullFid = (*env)->GetFieldID(env, configCls, "outdoorHull",  "Z");
	jboolean bOutdoorHull = (*env)->GetBooleanField(env, obj, outdoorHullFid);

	ardrone_control_config.flight_without_shell = bOutdoorHull;
	ARDRONE_TOOL_CONFIGURATION_ADDEVENT(flight_without_shell, &ardrone_control_config.flight_without_shell, NULL);

	// Removing reference to the class instance
	(*env)->DeleteLocalRef(env, configCls);
}


JNIEXPORT void JNICALL
Java_com_parrot_freeflight_drone_DroneConfig_updateAdaptiveVideoNative(JNIEnv *env, jobject obj)
{
	jclass configCls = (*env)->GetObjectClass(env, obj);

	// Adaptive video
	jfieldID adaptiveVideoFid = (*env)->GetFieldID(env, configCls, "adaptiveVideo",  "Z");
	jboolean bAdaptiveVideo = (*env)->GetBooleanField(env, obj, adaptiveVideoFid);

	if (IS_ARDRONE1) {
		ARDRONE_VARIABLE_BITRATE enabled = (bAdaptiveVideo == TRUE) ? ARDRONE_VARIABLE_BITRATE_MODE_DYNAMIC : ARDRONE_VARIABLE_BITRATE_MANUAL;
		uint32_t constantBitrate = (UVLC_CODEC == ardrone_control_config.video_codec) ? 20000 : 15000;
		ardrone_control_config.bitrate_ctrl_mode = enabled;
		ardrone_control_config.bitrate = constantBitrate;

		ARDRONE_TOOL_CONFIGURATION_ADDEVENT(bitrate_ctrl_mode, &ardrone_control_config.bitrate_ctrl_mode, NULL);
		ARDRONE_TOOL_CONFIGURATION_ADDEVENT(bitrate, &ardrone_control_config.bitrate, NULL);
	} else if (IS_ARDRONE2) {
        ARDRONE_VARIABLE_BITRATE enabled = (bAdaptiveVideo) ? ARDRONE_VARIABLE_BITRATE_MODE_DYNAMIC : ARDRONE_VARIABLE_BITRATE_MODE_DISABLED;
        ardrone_control_config.bitrate_ctrl_mode = enabled;
        ARDRONE_TOOL_CONFIGURATION_ADDEVENT(bitrate_ctrl_mode, &ardrone_control_config.bitrate_ctrl_mode, NULL);
	}
	// Removing reference to the class instance
	(*env)->DeleteLocalRef(env, configCls);
}


JNIEXPORT void JNICALL
Java_com_parrot_freeflight_drone_DroneConfig_updateOwnerMacNative(JNIEnv *env, jobject obj)
{
	jclass configCls = (*env)->GetObjectClass(env, obj);

	// Owner Mac
	jfieldID pairingFid  = (*env)->GetFieldID(env, configCls, "ownerMac",  "Ljava/lang/String;");
	jstring strOwnerMac = (*env)->GetObjectField(env, obj, pairingFid);

	const jbyte *owner_mac_arr;
	owner_mac_arr = (*env)->GetStringUTFChars(env, strOwnerMac, NULL);

	if (owner_mac_arr == NULL) {
		return; /* OutOfMemoryError already thrown */
	}

	strcpy(ardrone_control_config.owner_mac, owner_mac_arr);
	ARDRONE_TOOL_CONFIGURATION_ADDEVENT(owner_mac, ardrone_control_config.owner_mac, NULL);
	(*env)->ReleaseStringUTFChars(env, strOwnerMac, owner_mac_arr);

	// Removing reference to the class instance
	(*env)->DeleteLocalRef(env, configCls);
}


JNIEXPORT void JNICALL
Java_com_parrot_freeflight_drone_DroneConfig_updateAltitudeLimit(JNIEnv *env, jobject obj, jint altitude)
{
	ardrone_control_config.altitude_max = altitude * 1000;
	ARDRONE_TOOL_CONFIGURATION_ADDEVENT(altitude_max, &ardrone_control_config.altitude_max, NULL);
}


JNIEXPORT void JNICALL
Java_com_parrot_freeflight_drone_DroneConfig_updateOutdoorFlightNative(JNIEnv *env, jobject obj)
{
	jclass configCls = (*env)->GetObjectClass(env, obj);

	jfieldID outdoorFlightFid = (*env)->GetFieldID(env, configCls, "outdoorFlight",  "Z");
	ardrone_control_config.outdoor = (*env)->GetBooleanField(env, obj, outdoorFlightFid);;
	ARDRONE_TOOL_CONFIGURATION_ADDEVENT(outdoor, &ardrone_control_config.outdoor, NULL);

	// Removing reference to the class instance
	(*env)->DeleteLocalRef(env, configCls);
}


JNIEXPORT void JNICALL
Java_com_parrot_freeflight_drone_DroneConfig_updateYawSpeedMaxNative(JNIEnv *env, jobject obj)
{
	jclass configCls = (*env)->GetObjectClass(env, obj);

	// Yaw Speed Max
	jfieldID yawSpeedMaxFid = (*env)->GetFieldID(env, configCls, "yawSpeedMax",  "I");
	jint yawSpeedMax = (*env)->GetIntField(env, obj, yawSpeedMaxFid);
	ardrone_control_config.control_yaw = (float)yawSpeedMax * DEG_TO_RAD;
	ARDRONE_TOOL_CONFIGURATION_ADDEVENT(control_yaw, &ardrone_control_config.control_yaw, NULL);

	// Removing reference to the class instance
	(*env)->DeleteLocalRef(env, configCls);
}


JNIEXPORT void JNICALL
Java_com_parrot_freeflight_drone_DroneConfig_updateVertSpeedMaxNative(JNIEnv *env, jobject obj)
{
	jclass configCls = (*env)->GetObjectClass(env, obj);

	// Vertical Speed Max
	jfieldID vertSpeedMaxFid = (*env)->GetFieldID(env, configCls, "vertSpeedMax",  "I");
	jint vertSpeedMax = (*env)->GetIntField(env, obj,vertSpeedMaxFid);
	ardrone_control_config.control_vz_max = vertSpeedMax;
	ARDRONE_TOOL_CONFIGURATION_ADDEVENT(control_vz_max, &ardrone_control_config.control_vz_max, NULL);

	// Removing reference to the class instance
	(*env)->DeleteLocalRef(env, configCls);
}


JNIEXPORT void JNICALL
Java_com_parrot_freeflight_drone_DroneConfig_updateTiltNative(JNIEnv *env, jobject obj)
{
	jclass configCls = (*env)->GetObjectClass(env, obj);

	// Tilt
	jfieldID tiltFid = (*env)->GetFieldID(env, configCls, "tilt",  "I");
	jint tiltMax = (*env)->GetIntField(env, obj, tiltFid);
	ardrone_control_config.euler_angle_max = (float)tiltMax * DEG_TO_RAD;
	ARDRONE_TOOL_CONFIGURATION_ADDEVENT(euler_angle_max, &ardrone_control_config.euler_angle_max, NULL);

	// Removing reference to the class instance
	(*env)->DeleteLocalRef(env, configCls);
}


JNIEXPORT void JNICALL
Java_com_parrot_freeflight_drone_DroneConfig_updateDeviceTiltMax(JNIEnv *env, jobject obj, jint tilt)
{
	ardrone_control_config.control_iphone_tilt = (float)tilt * DEG_TO_RAD;
	ARDRONE_TOOL_CONFIGURATION_ADDEVENT(control_iphone_tilt, &ardrone_control_config.control_iphone_tilt, NULL);
}


JNIEXPORT void JNICALL
Java_com_parrot_freeflight_drone_DroneConfig_updateNetworkNameNative(JNIEnv *env, jobject obj)
{
	jclass configCls = (*env)->GetObjectClass(env, obj);

	// Network name
	jfieldID networkNameFid = (*env)->GetFieldID(env, configCls, "networkName",  "Ljava/lang/String;");
	jstring strNetworkName = (*env)->GetObjectField(env, obj, networkNameFid);
	const jbyte *network_name_str = (*env)->GetStringUTFChars(env, strNetworkName, NULL);

	if (network_name_str == NULL) {
		return; /* OutOfMemoryError already thrown */
	}

	strcpy(ardrone_control_config.ssid_single_player,network_name_str);
	ARDRONE_TOOL_CONFIGURATION_ADDEVENT(ssid_single_player, &ardrone_control_config.ssid_single_player, NULL);

	// Removing reference to the class instance
	(*env)->DeleteLocalRef(env, configCls);
}


JNIEXPORT void JNICALL
Java_com_parrot_freeflight_drone_DroneConfig_updateVideoCodecNative(JNIEnv *env, jobject obj)
{
	jclass configCls = (*env)->GetObjectClass(env, obj);

	// Video codec
	jfieldID videoCodecFid  = (*env)->GetFieldID(env, configCls, "videoCodec",  "I");
	jint videoCodec = (*env)->GetIntField(env, obj, videoCodecFid);

	if (IS_ARDRONE1) {
		if (videoCodec == P264_CODEC || videoCodec == UVLC_CODEC) {
			LOGI(TAG, "Setting %s codec", (videoCodec == P264_CODEC?"P264":"UVLC"));
			ardrone_control_config.video_codec = videoCodec;
			ARDRONE_TOOL_CONFIGURATION_ADDEVENT(video_codec, &ardrone_control_config.video_codec, NULL);
			ardrone_control_config.bitrate = (UVLC_CODEC == ardrone_control_config.video_codec) ? 20000 : 15000;
			ARDRONE_TOOL_CONFIGURATION_ADDEVENT(bitrate, &ardrone_control_config.bitrate, NULL);
		} else {
			LOGW(TAG, "Can't set codec. Unknown codec %d", videoCodec);
		}
	} else if (IS_ARDRONE2) {
		if (videoCodec > UVLC_CODEC && videoCodec <= H264_AUTO_RESIZE_CODEC) {
			ardrone_control_config.video_codec = videoCodec;
			ARDRONE_TOOL_CONFIGURATION_ADDEVENT(video_codec, &ardrone_control_config.video_codec, NULL);
		} else {
			LOGW(TAG, "Can't set codec. Unknown codec %d", videoCodec);
		}
	}

	// Removing reference to the class instance
	(*env)->DeleteLocalRef(env, configCls);
}


JNIEXPORT void JNICALL
Java_com_parrot_freeflight_drone_DroneConfig_updateRecordOnUsb(JNIEnv *env, jobject obj)
{
	if (IS_ARDRONE2) {
        ardrone_control_config.video_on_usb = java_get_bool_field_value(env, obj, "recordOnUsb");
        ARDRONE_TOOL_CONFIGURATION_ADDEVENT(video_on_usb, &ardrone_control_config.video_on_usb, NULL);
        LOGD(TAG, "Settings Video on USB to %d", ardrone_control_config.video_on_usb);
	} else {
		LOGW(TAG, "Can't set video on usb value for AR.Drone 1");
	}
}


JNIEXPORT jint JNICALL
Java_com_parrot_freeflight_drone_DroneConfig_getDroneFamily(JNIEnv *env, jobject obj)
{
	return ARDRONE_VERSION();
}


JNIEXPORT int JNICALL
Java_com_parrot_freeflight_drone_DroneConfig_getFtpPortNative(JNIEnv *env, jclass class)
{
	return FTP_PORT;
}


JNIEXPORT jstring JNICALL
Java_com_parrot_freeflight_drone_DroneConfig_getDroneHostNative(JNIEnv *env, jclass class)
{
	jstring host = (*env)->NewStringUTF(env, WIFI_ARDRONE_IP);
	return host;
}
