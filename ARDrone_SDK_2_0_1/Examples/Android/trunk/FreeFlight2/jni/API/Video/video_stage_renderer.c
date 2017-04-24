/*
 * video_stage_renderer.c
 *
 *  Created on: May 18, 2011
 *      Author: "Dmytro Baryskyy"
 */
#include <android/bitmap.h>

#include "common.h"
#include "frame_rate.h"
#include "video_stage_renderer.h"
#include "../Callbacks/java_callbacks.h"

static const char* TAG = "video_stage_renderer";

static opengl_size_t screen_size;
int video_width = 0;
int video_height = 0;
static bool_t recalculate_video_texture = FALSE;

// Holds video data
static uint8_t *pixbuff = NULL;

opengl_scaling	 scaling;
opengl_texture_t texture;

//GLuint           program;
static int32_t current_num_picture_decoded = 0;
static int32_t current_num_frames = 0;

opengl_size_t oldsize;


static void printGLString(const char *name, GLenum s)
{
    const char *v = (const char *) glGetString(s);
    LOGI(TAG, "GL %s = %s\n", name, v);
}


void parrot_video_stage_renderer_invalidate()
{
	recalculate_video_texture = TRUE;
}


void parrot_video_stage_init()
{
   // Left empty as OpenGL drawing is performed on java side
}


void parrot_video_stage_deinit()
{
   // Left empty as OpenGL drawing is performed on java side
}


JNIEXPORT jboolean JNICALL
Java_com_parrot_freeflight_video_VideoStageRenderer_getVideoFrameNative(JNIEnv *env, jobject obj, jobject bitmap, jintArray videoSize)
{
	return FALSE;
}



