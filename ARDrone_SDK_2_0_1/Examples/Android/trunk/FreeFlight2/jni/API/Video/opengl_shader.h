//
//  Shaders.h
//  FreeFlight
//
//  Created by Frédéric D'HAEYER on 24/10/11.
//  Copyright 2011 PARROT. All rights reserved.
//
#ifndef _OPENGL_SHADER_H_
#define _OPENGL_SHADER_H_
#include <GLES2/gl2.h>
#include <GLES2/gl2ext.h>

// #define DEBUG_SHADER

/* Shader Utilities */
GLint opengl_shader_compile(GLuint *shader, GLenum type, GLsizei count, const char *content_file);
GLint opengl_shader_link(GLuint prog);
GLint opengl_shader_validate(GLuint prog);
void  opengl_shader_destroy(GLuint vertShader, GLuint fragShader, GLuint prog);

#endif // _OPENGL_SHADER_H_
