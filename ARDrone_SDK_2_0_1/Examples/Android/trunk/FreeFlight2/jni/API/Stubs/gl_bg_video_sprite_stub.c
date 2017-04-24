/*
 * gl_bg_video_sprite_stub.c
 *
 *  Created on: Feb 1, 2012
 *      Author: "Dmytro Baryskyy"
 */
#include "common.h"
#include <android/bitmap.h>

#include "gl_bg_video_sprite_stub.h"
#include "../Callbacks/java_callbacks.h"

static char* TAG = "gl_bg_video_sprite";

static opengl_size_t screen_size;
static bool_t recalculate_video_texture = FALSE;
static int32_t current_num_picture_decoded = 0;
static int32_t current_num_frames = 0;

opengl_scaling	 scaling;
static opengl_texture_t texture;
static bool_t texture_initialized = FALSE;

static void init_texture()
{
	vp_os_memset(&texture, 0, sizeof(opengl_texture_t));
}

static void recalculate_video_texture_bounds(JNIEnv *env, jobject obj, opengl_texture_t* texture)
{
	java_set_field_int(env, obj, "imageWidth", texture->image_size.width);
	java_set_field_int(env, obj, "imageHeight",  texture->image_size.height);
	java_set_field_int(env, obj, "textureWidth", texture->texture_size.width);
	java_set_field_int(env, obj, "textureHeight", texture->texture_size.height);
}


void opengl_texture_scale_compute(opengl_texture_t *texture, opengl_size_t screen_size, opengl_scaling scaling)
{
	LOGD(TAG, "%s sizes %f, %f, %f, %f\n", __FUNCTION__, texture->image_size.width, texture->image_size.height, texture->texture_size.width, texture->texture_size.height);
	switch(scaling)
	{
		case NO_SCALING:
			texture->scaleModelX = texture->image_size.height / screen_size.width;
			texture->scaleModelY = texture->image_size.width / screen_size.height;
			break;
		case FIT_X:
			texture->scaleModelX = (screen_size.height * texture->image_size.height) / (screen_size.width * texture->image_size.width);
			texture->scaleModelY = 1.0f;
			break;
		case FIT_Y:
			texture->scaleModelX = 1.0f;
			texture->scaleModelY = (screen_size.width * texture->image_size.width) / (screen_size.height * texture->image_size.height);
			break;
		default:
			texture->scaleModelX = 1.0f;
			texture->scaleModelY = 1.0f;
			break;
	}

	texture->scaleTextureX = texture->image_size.width / (float)texture->texture_size.width;
	texture->scaleTextureY = texture->image_size.height / (float)texture->texture_size.height;
}


JNIEXPORT jboolean JNICALL
Java_com_parrot_freeflight_ui_gl_GLBGVideoSprite_onUpdateVideoTextureNative(JNIEnv *env, jobject obj, jint program, jint textureId)
{
	if (texture_initialized == FALSE) {
		init_texture();
		texture_initialized = TRUE;
	}

	opengl_video_stage_config_t *config = opengl_video_stage_get();

	if ((config != NULL) && (config->data != NULL) && (config->num_picture_decoded > current_num_picture_decoded))
	{
		if (texture.image_size.width != config->widthImage) {
			recalculate_video_texture = TRUE;
		}

		texture.bytesPerPixel       = config->bytesPerPixel;
		texture.image_size.width    = config->widthImage;
		texture.image_size.height   = config->heightImage;
		texture.texture_size.width	= config->widthTexture;
		texture.texture_size.height	= config->heightTexture;
		texture.format              = config->format;
		texture.type                = config->type;
		texture.data                = config->data;
		texture.state = OPENGL_STATE_GENERATED;

        current_num_picture_decoded = config->num_picture_decoded;
		current_num_frames = config->num_frames;
	}

	if (recalculate_video_texture) {
		recalculate_video_texture_bounds(env, obj, &texture);
		recalculate_video_texture = FALSE;
	}

	if(texture.state == OPENGL_STATE_GENERATED)
	{
		// Load the texture in the GPU
		if (texture.data != NULL) {
//			LOGD("GL_BG_VIDEO_SPRITE", "fmt: %d, w: %f, h: %f, type: %d, data: %p", texture.format, texture.texture_size.width, texture.texture_size.height, texture.type, texture.data);
			glTexImage2D(GL_TEXTURE_2D, 0, texture.format, texture.texture_size.width, texture.texture_size.height, 0, texture.format, texture.type, texture.data);
			texture.state = OPENGL_STATE_SEND_TO_GPU;

			return TRUE;
		}
	}

	return FALSE;
}

JNIEXPORT void JNICALL
Java_com_parrot_freeflight_ui_gl_GLBGVideoSprite_onSurfaceChangedNative(JNIEnv *env, jobject obj, jint width, jint height)
{
	screen_size.width = width;
	screen_size.height = height;

	recalculate_video_texture = TRUE;
}


JNIEXPORT jboolean JNICALL
Java_com_parrot_freeflight_ui_gl_GLBGVideoSprite_getVideoFrameNative(JNIEnv *env, jobject obj, jobject bitmap, jfloatArray videoSize)
{
	AndroidBitmapInfo  info;
	void*              pixels;
	int                ret;
	jboolean result = FALSE;

	if (screen_size.width == 0 || screen_size.height == 0)
		return FALSE;

	if ((ret = AndroidBitmap_getInfo(env, bitmap, &info)) < 0) {
		return FALSE;
	}

	if (info.format != ANDROID_BITMAP_FORMAT_RGB_565) {
		return FALSE;
	}

	opengl_video_stage_config_t *config = opengl_video_stage_get();

	if ((config != NULL) && (config->data != NULL) && (config->num_picture_decoded > current_num_picture_decoded))
	{
		if (texture.image_size.width != config->widthImage) {
			recalculate_video_texture = TRUE;
		}

		texture.bytesPerPixel       = config->bytesPerPixel;
		texture.image_size.width    = config->widthImage;
		texture.image_size.height   = config->heightImage;
		texture.texture_size.width	= config->widthTexture;
		texture.texture_size.height	= config->heightTexture;
		texture.format              = config->format;
		texture.type                = config->type;
		texture.data                = config->data;
		texture.state = OPENGL_STATE_GENERATED;

        current_num_picture_decoded = config->num_picture_decoded;
		current_num_frames = config->num_frames;
	}

	if (recalculate_video_texture && screen_size.width != 0 && screen_size.height != 0) {
		opengl_texture_scale_compute(&texture, screen_size, FIT_X);
		LOGD("VIDEO", "Screen Widht: %f", screen_size.width);
		recalculate_video_texture = FALSE;
	}

	if (texture.state == OPENGL_STATE_GENERATED)
	{
		if ((ret = AndroidBitmap_lockPixels(env, bitmap, &pixels)) < 0) {
		}

		result = TRUE;

		memcpy(pixels, texture.data, texture.image_size.width * texture.image_size.height  * texture.bytesPerPixel);

		texture.state = OPENGL_STATE_SEND_TO_GPU;

		jfloat *body = (*env)->GetFloatArrayElements(env, videoSize, 0);
		body[0] = (float)texture.image_size.width;
		body[1] = (float)texture.image_size.height;
		body[2] = (float)texture.scaleModelX;
		body[3] = (float)texture.scaleModelY;

		(*env)->ReleaseFloatArrayElements(env, videoSize, body, 0);

		AndroidBitmap_unlockPixels(env, bitmap);

	}

	return result;
}


