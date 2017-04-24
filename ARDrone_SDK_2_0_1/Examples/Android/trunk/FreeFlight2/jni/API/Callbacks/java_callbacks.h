/*
 * java_callbacks.h
 *
 *  Created on: Jan 31, 2012
 *      Author: "Dmytro Baryskyy"
 */

#ifndef JAVA_CALLBACKS_H_
#define JAVA_CALLBACKS_H_

extern void parrot_java_callbacks_call_void_method(JNIEnv *env, jobject obj, const char* methodName);
extern void parrot_java_callbacks_call_void_method_int_int(jobject obj, const char* methodName, int param1, int param2);
extern void parrot_java_callbacks_call_void_method_string(JNIEnv* env, jobject obj, const char*methodName, const char* param);
extern void java_set_field_int(JNIEnv *env, jobject obj, const char* fieldName, jint value);
extern void java_set_field_bool(JNIEnv *env, jobject obj, const char* fieldName, jboolean value);
extern jboolean java_get_bool_field_value(JNIEnv *env, jobject obj, const char* fieldName);
#endif /* JAVA_CALLBACKS_H_ */
