//
//  opengl_texture.h
//  ARDroneEngine
//
//  Created by Frédéric D'Haeyer on 10/21/11.
//  Copyright 2011 Parrot SA. All rights reserved.
//
#ifndef _OPENGL_TEXTURE_H_
#define _OPENGL_TEXTURE_H_

#include "ARDroneTypes.h"
#include <OpenGLES/ES2/gl.h>
#include <OpenGLES/ES2/glext.h>

typedef enum
{
	NO_SCALING,
	FIT_X,
	FIT_Y,
	FIT_XY
} ARDroneScaling;

typedef enum
{
    OPENGL_STATE_INITIALIZED = 0,
    OPENGL_STATE_GENERATED,
    OPENGL_STATE_SEND_TO_GPU
} opengl_state;

void opengl_texture_init(ARDroneOpenGLTexture *texture);
void opengl_texture_scale_compute(ARDroneOpenGLTexture *texture, ARDroneSize screen_size, ARDroneScaling scaling);
void opengl_texture_draw(ARDroneOpenGLTexture *texture, GLuint program);
void opengl_texture_destroy(ARDroneOpenGLTexture *texture);

#endif // _OPENGL_CONTEXT_H_