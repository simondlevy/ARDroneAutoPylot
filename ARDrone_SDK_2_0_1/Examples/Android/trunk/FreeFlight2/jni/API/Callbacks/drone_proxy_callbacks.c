/*
 * drone_proxy_callback.c
 *
 *  Created on: May 10, 2011
 *      Author: Dmytro Baryskyy
 */

#include "../common.h"
#include "java_callbacks.h"
#include "drone_proxy_callbacks.h"

static const char* TAG = "DRONE_PROXY_CALLBACK";

void parrot_drone_proxy_onConnected(JNIEnv* env, jobject obj)
{
	parrot_java_callbacks_call_void_method(env, obj, "onConnected");
}


void parrot_drone_proxy_onDisconnected(JNIEnv* env, jobject obj)
{
	parrot_java_callbacks_call_void_method(env, obj, "onDisconnected");
}


void parrot_drone_proxy_onConnectionFailed(JNIEnv* env, jobject obj, int code)
{
	if (env == NULL) {
		return;
	}

	jclass cls = (*env)->GetObjectClass(env, obj);
	jmethodID mid = (*env)->GetMethodID(env, cls, "onConnectionFailed", "(I)V");
	jint jcode = code;

	if (mid == 0) {
		LOGW(TAG, "Method not found");
		return;
	}

	(*env)->CallVoidMethod(env, obj, mid, jcode);

	(*env)->DeleteLocalRef(env, cls);
}


void parrot_drone_proxy_onConfigChanged(JNIEnv* env, jobject obj)
{
	parrot_java_callbacks_call_void_method(env, obj, "onConfigChanged");
}


