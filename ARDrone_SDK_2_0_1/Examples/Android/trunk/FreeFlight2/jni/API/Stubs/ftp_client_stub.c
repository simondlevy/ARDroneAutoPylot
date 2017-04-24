/*
 * ftp_client_stub.c
 *
 *  Created on: Jul 26, 2011
 *      Author: "Dmytro Baryskyy"
 */

#include "common.h"
#include <utils/ardrone_ftp.h>

static char* TAG = "ftp_client_stub";

static _ftp_status get_ftp_status(JNIEnv *env, jobject obj)
{
	jclass ftpClientClass = (*env)->GetObjectClass(env, obj);

	jfieldID ftpStatusFid  = (*env)->GetFieldID(env, ftpClientClass, "ftpStatus",  "I");
	jlong ftpStatus = (*env)->GetIntField(env, obj, ftpStatusFid);

	// Removing reference to the class instance
	(*env)->DeleteLocalRef(env, ftpClientClass);

	return (_ftp_status) ftpStatus;
}


static _ftp_t* get_ftp_handle(JNIEnv *env, jobject obj)
{
	jclass ftpClientClass = (*env)->GetObjectClass(env, obj);

	jfieldID connectionHandleFid  = (*env)->GetFieldID(env, ftpClientClass, "connectionHandle",  "I");
	jint connectionHandle = (*env)->GetIntField(env, obj, connectionHandleFid);

	// Removing reference to the class instance
	(*env)->DeleteLocalRef(env, ftpClientClass);

	_ftp_t* ftp_handle = (_ftp_t*) connectionHandle;

	if (ftp_handle != NULL)
	{
		if (ftp_handle->tag != NULL)
		{
			// Deleting old reference to java ftpclient object
			jobject caller = ftp_handle->tag;
			(*env)->DeleteGlobalRef(env, caller);
			ftp_handle->tag = NULL;
		}

		// we need to save the object that is calling this method in order to call callback of this object
		ftp_handle->tag = (*env)->NewGlobalRef(env, obj);
	}

	return ftp_handle;
}


static void update_ftp_status_field(JNIEnv *env, jobject obj, _ftp_status status)
{
	jclass ftpClientClass = (*env)->GetObjectClass(env, obj);

	jfieldID ftpStatusFid  = (*env)->GetFieldID(env, ftpClientClass, "ftpStatus",  "I");
	(*env)->SetIntField(env, obj, ftpStatusFid, (jint)status);

	// Removing reference to the class instance
	(*env)->DeleteLocalRef(env, ftpClientClass);
}


static void update_conn_handler_field(JNIEnv *env, jobject obj, _ftp_t* handle)
{
	jclass ftpClientClass = (*env)->GetObjectClass(env, obj);

	jfieldID connectionHandleFid  = (*env)->GetFieldID(env, ftpClientClass, "connectionHandle",  "I");
	(*env)->SetIntField(env, obj, connectionHandleFid, (jint)handle);

	// Removing reference to the class instance
	(*env)->DeleteLocalRef(env, ftpClientClass);
}


static void wrapperCallback (_ftp_status status, void *arg, _ftp_t *ftp)
{
	JNIEnv* jniEnv = NULL;
	jobject obj = ftp->tag;

	if (obj == NULL) {
		LOGW(TAG, "wrapperCallback(). Can't call callback. Env or object is null");
		return;
	}

	if (g_vm)
	{
		(*g_vm)->AttachCurrentThread (g_vm, (JNIEnv **) &jniEnv, NULL);
	}
	else
	{
		LOGW(TAG, "g_vm is not available!");
	}

	jclass cls = (*jniEnv)->GetObjectClass(jniEnv, obj);
	jmethodID mid = (*jniEnv)->GetMethodID(jniEnv, cls, "callback", "(IFLjava/lang/String;)V");

	  if (mid == 0) {
		  LOGE(TAG, "Can't find method callback");
		  return;
	  }

	jint locStatus = (jint)status;
	jfloat progress = 0.0f;
	jstring fileList = NULL;
	jint operation = 0;


	if (FTP_PROGRESS == locStatus && NULL != arg)
	{
		progress = *(jfloat *)arg;
		fileList = NULL;
	}

	(*jniEnv)->CallVoidMethod(jniEnv, obj, mid, locStatus, progress, fileList);

	// Removing reference to the class instance
	(*jniEnv)->DeleteLocalRef(jniEnv, cls);

	if (g_vm)
	{
		(*g_vm)->DetachCurrentThread (g_vm);
	}
}


JNIEXPORT jboolean JNICALL
Java_com_parrot_ftp_FTPClient_ftpConnect(JNIEnv *env, jobject obj, jstring ip, jint port, jstring username, jstring password)
{
	 _ftp_status initResult = FTP_FAIL;

	 const char *ipAddressASCII = (*env)->GetStringUTFChars(env, ip, NULL);
	 const char *usernameASCII = (*env)->GetStringUTFChars(env, username, NULL);
	 const char *passwordASCII = (*env)->GetStringUTFChars(env, password, NULL);

	 if (ipAddressASCII == NULL || usernameASCII == NULL) {
		 return FALSE; /* OutOfMemoryError already thrown */
	 }

	 _ftp_t* ftp = ftpConnect (ipAddressASCII,
	                           port,
	                           usernameASCII,
	                           passwordASCII,
	                           &initResult);

 	(*env)->ReleaseStringUTFChars(env, ip, ipAddressASCII);
 	(*env)->ReleaseStringUTFChars(env, username, usernameASCII);
	(*env)->ReleaseStringUTFChars(env, password, passwordASCII);

	update_ftp_status_field(env, obj, initResult);
	update_conn_handler_field(env, obj, ftp);

	return FTP_SUCCEDED(initResult)?TRUE:FALSE;
}


JNIEXPORT jboolean JNICALL
Java_com_parrot_ftp_FTPClient_ftpDisconnect(JNIEnv *env, jobject obj)
{
	_ftp_t* ftp = get_ftp_handle(env, obj);

	if (ftp == NULL) {
		LOGW(TAG, "ftpDisconnect: Connection is null");
		return FALSE;
	}

	if (ftp->tag != NULL) {
		jobject tag = ftp->tag;
		(*env)->DeleteGlobalRef(env, tag);
		ftp->tag = NULL;
	}

	_ftp_status status = ftpClose(&ftp);

	update_ftp_status_field(env, obj, status);
	update_conn_handler_field(env, obj, ftp);


	return FTP_SUCCEDED(status)?TRUE:FALSE;
}


static jboolean
ftp_ftpGet(JNIEnv *env, jobject obj, ftp_callback callback, jstring remoteName, jstring localName, jboolean useResume)
{
	if (localName == NULL || remoteName == NULL) {
			LOGW(TAG, "ftpGet() failed. Invalid parameters.");
			return FALSE;
		}

		const char *localNameASCII = (*env)->GetStringUTFChars(env, localName, NULL);
		_ftp_t* ftp = get_ftp_handle(env, obj);
		const char *remoteNameASCII = (*env)->GetStringUTFChars(env, remoteName, NULL);

		if (ftp == NULL) {
			LOGW(TAG, "ftpGet: Connection is null");
			return FALSE;
		}

		_ftp_status status = ftpGet(ftp, remoteNameASCII, localNameASCII, useResume == TRUE ? 1 : 0, callback);

		update_ftp_status_field(env, obj, status);
		update_conn_handler_field(env, obj, ftp);

		return (FTP_SUCCEDED(status)?TRUE:FALSE);
}


static jboolean
ftp_ftpPut(JNIEnv *env, jobject obj, ftp_callback callback, jstring localName, jstring remoteName, jboolean useResume)
{
	if (localName == NULL || remoteName == NULL) {
		LOGW(TAG, "ftpPut() failed. Invalid parameters.");
		return FALSE;
	}

	_ftp_t* ftp = get_ftp_handle(env, obj);

	if (ftp == NULL) {
		LOGW(TAG, "ftpPut: Connection is null");
		return FALSE;
	}

	 const char *localNameASCII = (*env)->GetStringUTFChars(env, localName, NULL);
	 const char *remoteNameASCII = (*env)->GetStringUTFChars(env, remoteName, NULL);

	_ftp_status status = ftpPut(ftp, localNameASCII, remoteNameASCII, useResume==TRUE?1:0, callback);

 	(*env)->ReleaseStringUTFChars(env, localName, localNameASCII);
 	(*env)->ReleaseStringUTFChars(env, remoteName, remoteNameASCII);

 	update_ftp_status_field(env, obj, status);
 	update_conn_handler_field(env, obj, ftp);

 	return (FTP_SUCCEDED(status)?TRUE:FALSE);
}


JNIEXPORT jboolean JNICALL
Java_com_parrot_ftp_FTPClient_ftpIsConnected(JNIEnv *env, jobject obj)
{
	_ftp_t* ftp = get_ftp_handle(env, obj);

	if (ftp != NULL) {
		return (ftp->connected>0?TRUE:FALSE);
	}

	return FALSE;
}


JNIEXPORT jboolean JNICALL
Java_com_parrot_ftp_FTPClient_ftpAbort(JNIEnv *env, jobject obj)
{
	_ftp_t* ftp = get_ftp_handle(env, obj);

	if (ftp == NULL) {
		LOGW(TAG, "ftpAbort: Connection is null");
		return FALSE;
	}

	if (ftp->tag != NULL) {
		jobject tag = ftp->tag;
		(*env)->DeleteGlobalRef(env, tag);
		ftp->tag = NULL;
	}

	_ftp_status status = ftpAbort(ftp);

	update_ftp_status_field(env, obj, status);
	update_conn_handler_field(env, obj, ftp);

	return (FTP_SUCCEDED(status)?TRUE:FALSE);
}


JNIEXPORT jboolean JNICALL
Java_com_parrot_ftp_FTPClient_ftpPut(JNIEnv *env, jobject obj, jstring localName, jstring remoteName, jboolean useResume)
{
	return ftp_ftpPut(env, obj, wrapperCallback, localName, remoteName, useResume);
}


JNIEXPORT jboolean JNICALL
Java_com_parrot_ftp_FTPClient_ftpPutSync(JNIEnv *env, jobject obj, jstring localName, jstring remoteName, jboolean useResume)
{
	return ftp_ftpPut(env, obj, NULL, localName, remoteName, useResume);
}


JNIEXPORT jboolean JNICALL
Java_com_parrot_ftp_FTPClient_ftpGet(JNIEnv *env, jobject obj, jstring remoteName, jstring localName, jboolean useResume)
{
	return ftp_ftpGet(env, obj, wrapperCallback, remoteName, localName, useResume);
}


JNIEXPORT jboolean JNICALL
Java_com_parrot_ftp_FTPClient_ftpGetSync(JNIEnv *env, jobject obj, jstring remoteName, jstring localName, jboolean useResume)
{
	return ftp_ftpGet(env, obj, NULL, remoteName, localName, useResume);
}

