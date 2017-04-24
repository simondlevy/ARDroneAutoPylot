/*
 * java_callbacks.c
 *
 *  Created on: Jan 31, 2012
 *      Author: "Dmytro Baryskyy"
 */

#include "common.h"
#include "java_callbacks.h"

static const char* TAG = "JAVA_CALLBACKS";

void parrot_java_callbacks_call_void_method(JNIEnv *env, jobject obj, const char* methodName)
{
	if (env == NULL || obj == NULL) {
		LOGW(TAG, "env or obj is null");
		return;
	}

	jclass cls = (*env)->GetObjectClass(env, obj);
	jmethodID mid = (*env)->GetMethodID(env, cls, methodName, "()V");

	if (mid == 0) {
		LOGW(TAG, "Method not found");
		return;
	}

	(*env)->CallVoidMethod(env, obj, mid);

	(*env)->DeleteLocalRef(env, cls);
}


void parrot_java_callbacks_call_void_method_int_int(jobject obj, const char* methodName, int param1, int param2)
{
	JNIEnv* env = NULL;

	if (g_vm != NULL)
	{
		(*g_vm)->GetEnv(g_vm, (void **)&env, JNI_VERSION_1_6);
	}

	if (env == NULL || obj == NULL) {
		LOGW(TAG, "env or obj is null");
		return;
	}

	jclass cls = (*env)->GetObjectClass(env, obj);
	jmethodID mid = (*env)->GetMethodID(env, cls, methodName, "(II)V");

	if (mid == 0) {
		LOGW(TAG, "Method not found");
		return;
	}

	(*env)->CallVoidMethod(env, obj, mid, param1, param2);

	(*env)->DeleteLocalRef(env, cls);
}


void parrot_java_callbacks_call_void_method_string(JNIEnv *env, jobject obj, const char*methodName, const char* param)
{
	if (env == NULL || obj == NULL) {
		LOGW(TAG, "env or obj is null");
		return;
	}

	jclass cls = (*env)->GetObjectClass(env, obj);
	jmethodID mid = (*env)->GetMethodID(env, cls, methodName, "(Ljava/lang/String;)V");

	if (mid == 0) {
		LOGW(TAG, "Method not found");
		return;
	}

	jstring paramUrf8 = (*env)->NewStringUTF(env, param);

	(*env)->CallVoidMethod(env, obj, mid, paramUrf8);
	(*env)->DeleteLocalRef(env, cls);
}

void parrot_java_callbacks_call_void_method_string_boolean(JNIEnv *env, jobject obj, const char*methodName, const char* param, bool_t param2)
{
	if (env == NULL || obj == NULL) {
		LOGW(TAG, "env or obj is null");
		return;
	}

	jclass cls = (*env)->GetObjectClass(env, obj);
	jmethodID mid = (*env)->GetMethodID(env, cls, methodName, "(Ljava/lang/String;Z)V");

	if (mid == 0) {
		LOGW(TAG, "Method not found");
		return;
	}

	jstring paramUrf8 = (*env)->NewStringUTF(env, param);

    jboolean boolJava = param2;

	(*env)->CallVoidMethod(env, obj, mid, paramUrf8, boolJava);
	(*env)->DeleteLocalRef(env, cls);
}

void java_set_field_int(JNIEnv *env, jobject obj, const char* fieldName, jint value)
{
	jclass class = (*env)->GetObjectClass(env, obj);

	jfieldID fieldId  = (*env)->GetFieldID(env, class, fieldName,  "I");
	(*env)->SetIntField(env, obj, fieldId, value);

	// Removing reference to the class instance
	(*env)->DeleteLocalRef(env, class);
}


void java_set_field_bool(JNIEnv *env, jobject obj, const char* fieldName, jboolean value)
{
	jclass class = (*env)->GetObjectClass(env, obj);

	jfieldID fieldId  = (*env)->GetFieldID(env, class, fieldName,  "Z");
	(*env)->SetBooleanField(env, obj, fieldId, value);

	// Removing reference to the class instance
	(*env)->DeleteLocalRef(env, class);
}


jboolean java_get_bool_field_value(JNIEnv *env, jobject obj, const char* fieldName)
{
	jclass class = (*env)->GetObjectClass(env, obj);

	jfieldID fieldId = (*env)->GetFieldID(env, class, fieldName, "Z");
	jboolean value = (*env)->GetBooleanField(env, obj, fieldId);

	(*env)->DeleteLocalRef(env, class);

	return value;
}

