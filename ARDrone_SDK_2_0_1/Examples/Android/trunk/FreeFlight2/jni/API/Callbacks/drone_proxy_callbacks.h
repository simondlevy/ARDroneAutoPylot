/*
 * drone_proxy_callbacks.h
 *
 *  Created on: May 7, 2011
 *      Author: Dmytro Baryskyy
 */

#ifndef DRONE_PROXY_CALLBACKS_H_
#define DRONE_PROXY_CALLBACKS_H_

// These callbacks are called by the native code and the control will go to the Java
extern void parrot_drone_proxy_onConnected       (JNIEnv* env, jobject /*obj*/);
extern void parrot_drone_proxy_onConnectionFailed(JNIEnv* env, jobject /*obj*/, int /*code*/);
extern void parrot_drone_proxy_onDisconnected    (JNIEnv* env, jobject /*obj*/);
extern void parrot_drone_proxy_onConfigChanged   (JNIEnv* env, jobject /*obj*/);
extern void ardrone_academy_callback_called      (const char* mediaPath, bool_t addToQueue);

#endif /* DRONE_PROXY_CALLBACKS_H_ */
