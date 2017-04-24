//
//  opengl_texture.c
//  ARDroneEngine
//
//  Created by Frédéric D'Haeyer on 10/21/11.
//  Copyright 2011 Parrot SA. All rights reserved.
//
#include "opengl_texture.h"
#include <string.h>
#include <stdio.h>

typedef struct _InterleavedVertex_
{
    GLfloat position[3]; // Vertex
    GLfloat texcoord[2];  // Texture Coordinates
} InterleavedVertex;

static InterleavedVertex const vertex[] =
{
    { {1.0f, -1.0f, -1.2f }, { 0.0f, 1.0f } },
    { {-1.0f, -1.0f, -1.2f }, { 0.0f, 0.0f } },
    { {1.0f,  1.0f, -1.2f }, { 1.0f, 1.0f } },
    { {-1.0f,  1.0f, -1.2f }, { 1.0f, 0.0f } }
};

static GLushort const indexes[] = { 0, 1, 2, 3 };

void opengl_texture_init(ARDroneOpenGLTexture *texture)
{
    // Generated the texture
    // Note: this must NOT be done before the initialization of OpenGL (this is why it can NOT be done in "InitializeTexture")
    memset(texture, 0, sizeof(ARDroneOpenGLTexture));
//    vp_os_memset(texture, 0, sizeof(ARDroneOpenGLTexture));
}

void opengl_texture_scale_compute(ARDroneOpenGLTexture *texture, ARDroneSize screen_size, ARDroneScaling scaling)
{
	printf("%s sizes %f, %f, %f, %f\n", __FUNCTION__, texture->image_size.width, texture->image_size.height, texture->texture_size.width, texture->texture_size.height);
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

void opengl_texture_draw(ARDroneOpenGLTexture* texture, GLuint program)
{
    static int textureId = 0;
    static int prev_num_picture_decoded = 0;
  /*  if(texture->state == OPENGL_STATE_INITIALIZED)
    {
        // Create and bind texture

        GLuint textureUniform = glGetUniformLocation(program, "texture");
        glUniform1i(textureUniform, 0);
        
        glGenTextures(2, texture->textureId);
        printf("Video texture identifier : %d\n", texture->textureId[0]);
        glActiveTexture(GL_TEXTURE0);
        glBindTexture(GL_TEXTURE_2D, texture->textureId[0]);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);

        printf("Video texture identifier : %d\n", texture->textureId[1]);
        glActiveTexture(GL_TEXTURE1);
        glBindTexture(GL_TEXTURE_2D, texture->textureId[1]);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
        // Sets up pointers and enables states needed for using vertex arrays and textures
        // Vertices
        glGenBuffers(1, &texture->vertexBufferId);
        glBindBuffer(GL_ARRAY_BUFFER, texture->vertexBufferId); 
        glBufferData(GL_ARRAY_BUFFER, sizeof(vertex), vertex, GL_STATIC_DRAW);
        glVertexAttribPointer(ARDRONE_ATTRIB_POSITION, 3, GL_FLOAT, GL_FALSE, sizeof(InterleavedVertex), (void*)offsetof(InterleavedVertex, position));
        glEnableVertexAttribArray(ARDRONE_ATTRIB_POSITION);
        glVertexAttribPointer(ARDRONE_ATTRIB_TEXCOORD, 2, GL_FLOAT, GL_FALSE, sizeof(InterleavedVertex), (void*)offsetof(InterleavedVertex, texcoord));
        glEnableVertexAttribArray(ARDRONE_ATTRIB_TEXCOORD);
        printf("Video vertex buffer identifier : %d\n", texture->vertexBufferId);
        
        // Indexes
        glGenBuffers(1, &texture->indexBufferId);
        glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, texture->indexBufferId);
        glBufferData(GL_ELEMENT_ARRAY_BUFFER, sizeof(indexes), indexes, GL_STATIC_DRAW);
        printf("Video index buffer identifier : %d\n", texture->indexBufferId);
        
        texture->state = OPENGL_STATE_GENERATED;
    }*/
    
    if(texture->num_picture_decoded > prev_num_picture_decoded)
    {
        glActiveTexture(GL_TEXTURE0);
//        glActiveTexture(textureId == 0 ? GL_TEXTURE0 : GL_TEXTURE1);
        // Load the texture in the GPUDis
        glTexImage2D(GL_TEXTURE_2D, 0, texture->format, texture->texture_size.width, texture->texture_size.height, 0, texture->format, texture->type, texture->data);
        textureId = (textureId + 1) % 2;
        prev_num_picture_decoded = texture->num_picture_decoded;
    }
    // Draw the background quad
    glDrawElements(GL_TRIANGLE_STRIP, sizeof(indexes)/sizeof(GLushort), GL_UNSIGNED_SHORT, (void*)0);
}

void opengl_texture_destroy(ARDroneOpenGLTexture *texture)
{
/*    if(texture->state != OPENGL_STATE_INITIALIZED)
    {
        glDeleteTextures(1, &texture->textureId[0]);
        glDeleteTextures(1, &texture->textureId[1]);
        glDeleteBuffers(1, &texture->vertexBufferId);
        glDeleteBuffers(1, &texture->indexBufferId);
    }*/
    
}
