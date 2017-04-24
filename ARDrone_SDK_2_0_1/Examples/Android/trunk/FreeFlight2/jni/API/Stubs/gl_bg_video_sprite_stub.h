/*
 * gl_bg_video_sprite_stub.h
 *
 *  Created on: Jul 27, 2012
 *      Author: "Dmytro Baryskyy"
 */

#ifndef GL_BG_VIDEO_SPRITE_STUB_H_
#define GL_BG_VIDEO_SPRITE_STUB_H_

typedef enum
{
	NO_SCALING,
	FIT_X,
	FIT_Y,
	FIT_XY
} opengl_scaling;


typedef enum
{
    OPENGL_STATE_INITIALIZED = 0,
    OPENGL_STATE_GENERATED,
    OPENGL_STATE_SEND_TO_GPU
} opengl_state;


typedef struct
{
    GLfloat width;
    GLfloat height;
} opengl_size_t;


typedef struct
{
	opengl_size_t image_size;
	opengl_size_t texture_size;
	GLfloat scaleModelX;
	GLfloat scaleModelY;
	GLfloat scaleTextureX;
	GLfloat scaleTextureY;
	GLuint bytesPerPixel;
	GLenum format;
	GLenum type;
	void* data;
	GLuint textureId[2];
	GLuint vertexBufferId;
	GLuint indexBufferId;

	opengl_state state;
} opengl_texture_t;


#endif /* GL_BG_VIDEO_SPRITE_STUB_H_ */
