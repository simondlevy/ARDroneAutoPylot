/*
 * plf_file_stub.c
 *
 *  Created on: Aug 30, 2011
 *      Author: Dmytro Baryskyy
 */

#include "common.h"
#include "../Plf/plf.h"


static char* TAG = {"PLF_FILE_STUB\0"};

static jbyteArray getHeader(JNIEnv* env, jobject obj, jint size)
{
	jclass cls = (*env)->GetObjectClass(env, obj);
	jmethodID mid = (*env)->GetMethodID(env, cls, "getHeader", "(I)[B");

	if (mid == 0) {
		LOGW(TAG, "Method not found");
		return NULL;
	}

	// Getting the file header from java code
	jbyteArray result = (*env)->CallObjectMethod(env, obj, mid, size);

	// Removing reference to the class instance
	(*env)->DeleteLocalRef(env, cls);

	return result;
}


JNIEXPORT jstring JNICALL
Java_com_parrot_plf_PlfFile_getVersionNative(JNIEnv *env, jobject obj)
{
	jbyteArray headerDataArray = getHeader(env, obj, sizeof(plf_phdr));

	if (headerDataArray == NULL) {
		LOGE(TAG, "Can't get plf header");
		return NULL;
	}

	jbyte* const rawHeader = (*env)->GetByteArrayElements( env, headerDataArray , 0);

	plf_phdr plf_header;
	memcpy(&plf_header, rawHeader, sizeof(plf_phdr));

	(*env)->ReleaseByteArrayElements(env, headerDataArray, rawHeader, JNI_ABORT);

	char version[256] = {0};
	sprintf(version, "%d.%d.%d", plf_header.p_ver, plf_header.p_edit, plf_header.p_ext);

	LOGI(TAG, "Version of plf file: %s", version);

	return (*env)->NewStringUTF(env, version);
}
