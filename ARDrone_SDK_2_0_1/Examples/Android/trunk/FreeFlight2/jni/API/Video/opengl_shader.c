//
//  Shaders.m
//  FreeFlight
//
//  Created by Frédéric D'HAEYER on 24/10/11.
//  Copyright 2011 PARROT. All rights reserved.
//
#include "opengl_shader.h"
#include "common.h"

/* Create and compile a shader from the provided source(s) */
GLint opengl_shader_compile(GLuint *shader, GLenum type, GLsizei count, const char* content_file)
{
#if defined(DEBUG_SHADER)
    printf("%s : %d\n", __FUNCTION__, __LINE__);
#endif
	GLint status;
	const GLchar *sources = (const GLchar *)content_file;

	// get source code
	if (!sources)
	{
		printf("Failed to load vertex shader\n");
		return 0;
	}
	
    *shader = glCreateShader(type);				// create shader
    glShaderSource(*shader, 1, &sources, NULL);	// set source code in the shader
    glCompileShader(*shader);					// compile shader
	
#if defined(DEBUG_SHADER)
	GLint logLength;
    glGetShaderiv(*shader, GL_INFO_LOG_LENGTH, &logLength);
    if (logLength > 0)
    {
        GLchar *log = (GLchar *)vp_os_malloc(logLength);
        glGetShaderInfoLog(*shader, logLength, &logLength, log);
        printf("Shader compile log:\n%s\n", log);
        vp_os_free(log);
    }
#endif
    
    glGetShaderiv(*shader, GL_COMPILE_STATUS, &status);
    if (status == GL_FALSE)
	{
		printf("Failed to compile shader:\n");
		printf("%s\n", sources);
	}
	
	return status;
}


/* Link a program with all currently attached shaders */
GLint opengl_shader_link(GLuint prog)
{
#if defined(DEBUG_SHADER)
    printf("%s : %d\n", __FUNCTION__, __LINE__);
#endif
	GLint status;
	
	glLinkProgram(prog);
	
#if defined(DEBUG_SHADER)
	GLint logLength;
    glGetProgramiv(prog, GL_INFO_LOG_LENGTH, &logLength);
    if (logLength > 0)
    {
        GLchar *log = (GLchar *)vp_os_malloc(logLength);
        glGetProgramInfoLog(prog, logLength, &logLength, log);
        printf("Program link log:\n%s\n", log);
        vp_os_free(log);
    }
#endif
    
    glGetProgramiv(prog, GL_LINK_STATUS, &status);
    if (status == GL_FALSE)
		printf("Failed to link program %d\n", prog);
	
	return status;
}


/* Validate a program (for i.e. inconsistent samplers) */
GLint opengl_shader_validate(GLuint prog)
{
#if defined(DEBUG_SHADER)
    printf("%s : %d\n", __FUNCTION__, __LINE__);
#endif
	GLint logLength, status;
	
	glValidateProgram(prog);
    glGetProgramiv(prog, GL_INFO_LOG_LENGTH, &logLength);
    if (logLength > 0)
    {
        GLchar *log = (GLchar *)vp_os_malloc(logLength);
        glGetProgramInfoLog(prog, logLength, &logLength, log);
        printf("Program validate log:\n%s\n", log);
        vp_os_free(log);
    }
    
    glGetProgramiv(prog, GL_VALIDATE_STATUS, &status);
    if (status == GL_FALSE)
		printf("Failed to validate program %d\n", prog);
	
	return status;
}

/* delete shader resources */
void opengl_shader_destroy(GLuint vertShader, GLuint fragShader, GLuint prog)
{	
#if defined(DEBUG_SHADER)
    printf("%s : %d\n", __FUNCTION__, __LINE__);
#endif
	if (vertShader) {
		glDeleteShader(vertShader);
		vertShader = 0;
	}
	if (fragShader) {
		glDeleteShader(fragShader);
		fragShader = 0;
	}
	if (prog) {
		glDeleteProgram(prog);
		prog = 0;
	}
}
