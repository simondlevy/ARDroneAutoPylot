//
//  ESRenderer.m
//  FreeFlight
//
//  Created by Frédéric D'HAEYER on 24/10/11.
//  Copyright Parrot SA 2009. All rights reserved.
//
#import "ESRenderer.h"
#include "opengl_shader.h"

#define GAME_PERSPECTIVE_WIDTH	1.5f
#define GAME_PERSPECTIVE_HEIGHT	1.f
#define GAME_NEAR	1.f
#define GAME_FAR	1000.f

typedef struct _InterleavedVertex_
{
    GLfloat position[3]; // Vertex
    GLfloat texcoord[2];  // Texture Coordinates
} InterleavedVertex;


static CGFloat const matrixOrthoBackRight[] = {-1.0f, 0.0f, 0.0f, 0.0f, 0.0f, -1.0f, 0.0f, 0.0f, 0.0f, 0.0f, 2.f/(GAME_NEAR - GAME_FAR), 0.0f, 0.0f, 0.0f, 0.0f, 1.0f};
static CGFloat const matrixOrthoBackLeft[] = {1.0f, 0.0f, 0.0f, 0.0f, 0.0f, 1.0f, 0.0f, 0.0f, 0.0f, 0.0f, 2.f/(GAME_NEAR - GAME_FAR), 0.0f, 0.0f, 0.0f, 0.0f, 1.0f};
static CGFloat mvp [16];

/*static InterleavedVertex const vertex[] =
 {
 { {480.0f, -270.0f, -1.f }, { 1.0f, 0.0f } },
 { {-480.0f, -270.0f, -1.f }, { 0.0f, 0.0f } },
 { {480.0f,  270.0f, -1.f }, { 1.0f, 1.0f } },
 { {-480.0f,  270.0f, -1.f }, { 0.0f, 1.0f } }
 };*/
/*static InterleavedVertex const vertex[] =
 {
 { {1.0f, -1.0f, 0.f }, { 1.0f, 0.0f } },
 { {-1.0f, -1.0f, 0.f }, { 0.0f, 0.0f } },
 { {1.0f,  1.0f, 0.f }, { 1.0f, 1.0f } },
 { {-1.0f,  1.0f, 0.f }, { 0.0f, 1.0f } }
 };*/
static InterleavedVertex const vertex[] =
{
    { {1.0f, -1.0f, -6.2f }, { 0.0f, 1.0f } },
    { {-1.0f, -1.0f, -6.2f }, { 0.0f, 0.0f } },
    { {1.0f,  1.0f, -6.2f }, { 1.0f, 1.0f } },
    { {-1.0f,  1.0f, -6.2f }, { 1.0f, 0.0f } }
};
static GLushort const indexes[] = { 0, 1, 2, 3 };
enum {
    UNIFORM_MODELVIEWMATRIX,
    NUM_UNIFORMS
};
GLint uniforms[NUM_UNIFORMS];

// attribute index
enum {
    ATTRIB_VERTEX,
    NUM_ATTRIBUTES
};
#ifdef ADD_3D_ITEM
static const GLfloat cubeVertices[] = {
    0.5, 0.5,  -4.0,
    0.5, 1.5,  -4.0,
    -0.5,  1.5,  -4.0,
    -0.5,  0.5,  -4.0,
    0.5, -0.5, -5.0,
    0.5, 0.5, -5.0,
    -0.5,  0.5, -5.0,
    -0.5,  -0.5, -5.0,
};

static const GLushort cubeIndices[] = {
    // Front
    0, 1, 2,
    2, 3, 0,
    // Back
    4, 6, 5,
    4, 7, 6,
    // Left
    2, 7, 3,
    7, 6, 2,
    // Right
    0, 4, 1,
    4, 1, 5,
    // Top
    6, 2, 1, 
    1, 6, 5,
    // Bottom
    0, 3, 7,
    0, 7, 4  
};
#endif
@interface ESRenderer (PrivateMethods)
- (BOOL) loadShaders;
- (void) createVBO;

@end

@implementation ESRenderer
// Create an ES 2.0 context
- (id) initWithFrame:(CGRect)frame andDrone:(ARDrone*)drone
{
    self = [super init];
	if (self)
	{
        defaultFramebuffer = 0;
        colorRenderbuffer = 0;

		context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
        if (!context || ![EAGLContext setCurrentContext:context])
		{
            NSLog(@"Could not create context");
            [self release];
            return nil;
        }
		
        [EAGLContext setCurrentContext:context];
        [self loadShaders];
        [[UIScreen mainScreen] scale];
        glUseProgram(programId);
        video = [[OpenGLSprite alloc] initWithFrame:frame withScaling:FIT_X withProgram:programId withDrone:drone withDelegate:self];
    }
	
	return self;
}

- (BOOL) resizeFromLayer:(CAEAGLLayer *)layer
{    
    GLsizei backingWidth, backingHeight;
    glGenFramebuffers(1, &defaultFramebuffer);
    glGenRenderbuffers(1, &colorRenderbuffer);
    glGenRenderbuffers(1, &defaultDepthbuffer);
    
    // Create default framebuffer object. The backing will be allocated for the current layer in -resizeFromLayer
    [EAGLContext setCurrentContext:context];
    glBindRenderbuffer(GL_RENDERBUFFER, defaultDepthbuffer);
    glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH_COMPONENT16, [layer bounds].size.width , [layer bounds].size.height);   
    glBindFramebuffer(GL_FRAMEBUFFER, defaultFramebuffer);
    glBindRenderbuffer(GL_RENDERBUFFER, colorRenderbuffer);
    [context renderbufferStorage:GL_RENDERBUFFER fromDrawable:layer];
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, colorRenderbuffer);
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_RENDERBUFFER, defaultDepthbuffer);
    
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_WIDTH, &backingWidth);
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_HEIGHT, &backingHeight);
    
    if (glCheckFramebufferStatus(GL_FRAMEBUFFER) != GL_FRAMEBUFFER_COMPLETE)
	{
        NSLog(@"Failed to make complete framebuffer object %x", glCheckFramebufferStatus(GL_FRAMEBUFFER));
        return NO;
    }
    
    glClearColor(0.0f, 0.0f, 0.0f, 0.0f);
    glViewport(0, 0, backingWidth, backingHeight);
    [self createVBO];
    
    return YES;
}

- (void) dealloc
{
	// tear down GL
    if(defaultFramebuffer)
    {
        glDeleteFramebuffers(1, &defaultFramebuffer);
        defaultFramebuffer = 0;
    }
    
    if(colorRenderbuffer)
    {
        glDeleteRenderbuffers(1, &colorRenderbuffer);
        colorRenderbuffer = 0;
    }
    
	// tear down context
	if ([EAGLContext currentContext] != nil)
        [EAGLContext setCurrentContext:nil];
	
	[context release];
	context = nil;
	
	[super dealloc];
}
- (void)setScreenOrientationRight:(BOOL)_screenOrientationRight
{
    orientationRight = _screenOrientationRight;
    [self updateScaleMatrix];
}

- (void)updateScaleMatrix
{
    if (orientationRight)
    {
        memcpy(mvp, matrixOrthoBackRight, 16 * sizeof (CGFloat));
    }
    else
    {
        memcpy(mvp, matrixOrthoBackLeft, 16 * sizeof (CGFloat));
    }
    
    ARDroneOpenGLTexture *texture = [video getTexture];
    if (nil != texture)
    {
        if (texture->texture_size.height > 1.0 &&
            texture->texture_size.width > 1.0)
        {
            mvp[0] *= texture->scaleModelX;
            mvp[5] *= texture->scaleModelY;
        }
    }
}

- (BOOL) loadShaders
{
    GLuint vertShader, fragShader;
    NSString *vertShaderPathname, *fragShaderPathname;
    
    NSLog(@"%s:%d", __FUNCTION__, __LINE__);
    // Create shader program.
    programId = glCreateProgram();
    
    // Create and compile vertex shader.
    vertShaderPathname = [[NSBundle mainBundle] pathForResource:@"Shader" ofType:@"vsh"];
    if (!opengl_shader_compile(&vertShader, GL_VERTEX_SHADER, 1, [[NSString stringWithContentsOfFile:vertShaderPathname encoding:NSUTF8StringEncoding error:nil] UTF8String]))
    {
        NSLog(@"Failed to compile vertex shader 2");
        return FALSE;
    }
    
    // Create and compile fragment shader.
    fragShaderPathname = [[NSBundle mainBundle] pathForResource:@"Shader" ofType:@"fsh"];
    if (!opengl_shader_compile(&fragShader, GL_FRAGMENT_SHADER, 1, [[NSString stringWithContentsOfFile:fragShaderPathname encoding:NSUTF8StringEncoding error:nil] UTF8String]))
    {
        NSLog(@"Failed to compile fragment shader 2");
        return FALSE;
    }
    
    // Attach vertex shader to program.
    glAttachShader(programId, vertShader);
    
    // Attach fragment shader to program.
    glAttachShader(programId, fragShader);
    
    // Bind attribute locations.
    // This needs to be done prior to linking.
    glBindAttribLocation(programId, ATTRIB_VERTEX, "position");
    
    // Link program.
    if (!opengl_shader_link(programId))
    {
        NSLog(@"Failed to link program: %d", programId);
		opengl_shader_destroy(vertShader, fragShader, programId);
        return FALSE;
    }
    
    uniforms[UNIFORM_MODELVIEWMATRIX] = glGetUniformLocation(programId, "mvp");

    // Release vertex and fragment shaders.
    opengl_shader_destroy(vertShader, fragShader, 0);
    
    return TRUE;
}

- (void)render:(ARDrone *)instance
{	
    [EAGLContext setCurrentContext:context];
    //    glClear(GL_COLOR_BUFFER_BIT);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    glFlush();
    glDisable(GL_DEPTH_TEST);
    
    //    static CGFloat const matrixOrthoBackRight[] = {-1.0f, 0.0f, 0.0f, 0.0f, 0.0f, -1.0f, 0.0f, 0.0f, 0.0f, 0.0f, 1.0f, 0.0f, 0.0f, 0.0f, 1.0f, 1.0f};
    
    if(instance != nil)
    {
        glBindBuffer(GL_ARRAY_BUFFER, vertexBufferId); 
        glVertexAttribPointer(ARDRONE_ATTRIB_POSITION, 3, GL_FLOAT, GL_FALSE, sizeof(InterleavedVertex), (void*)offsetof(InterleavedVertex, position));
        glEnableVertexAttribArray(ARDRONE_ATTRIB_POSITION);
        glVertexAttribPointer(ARDRONE_ATTRIB_TEXCOORD, 2, GL_FLOAT, GL_FALSE, sizeof(InterleavedVertex), (void*)offsetof(InterleavedVertex, texcoord));
        glActiveTexture(GL_TEXTURE0);
        glBindTexture(GL_TEXTURE_2D, textureId[0]);
        GLuint useTexture = glGetUniformLocation(programId, "UseTexture");
        glUniform1f(useTexture, 1);
        
        glUniformMatrix4fv(uniforms[UNIFORM_MODELVIEWMATRIX], 1, 0, mvp);
        
        glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, indexBufferId);
        
        [video drawSelf];
    }
#ifdef ADD_3D_ITEM 
    glEnable(GL_DEPTH_TEST);
    static GLfloat currentModelViewMatrix[16] = {   0, -2.f*GAME_NEAR/GAME_PERSPECTIVE_WIDTH, 0., 0.,
        -2.f*GAME_NEAR/GAME_PERSPECTIVE_HEIGHT, 0, 0., 0.,
        0., 0., (GAME_NEAR + GAME_FAR)/(GAME_NEAR - GAME_FAR), -1.f,
        0., 0., 2.f*GAME_NEAR*GAME_FAR/(GAME_NEAR - GAME_FAR), 0. };
        
    static BOOL isInit = NO;
    
    if(!isInit)
    {
        [self loadShaders];
        
        // Use shader program
        glUseProgram(programId);	
        
        // Sets up pointers and enables states needed for using vertex arrays and textures
        // Vertices
        glGenBuffers(1, &vertexBufferId2);
        glBindBuffer(GL_ARRAY_BUFFER, vertexBufferId2); 
        glBufferData(GL_ARRAY_BUFFER, sizeof(cubeVertices), cubeVertices, GL_STATIC_DRAW);
        glVertexAttribPointer(ATTRIB_VERTEX, 3, GL_FLOAT, GL_FALSE, 0, 0);
        glEnableVertexAttribArray(ATTRIB_VERTEX);
        
        // Indexes
        glGenBuffers(1, &indexBufferId2);
        glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, indexBufferId2);
        glBufferData(GL_ELEMENT_ARRAY_BUFFER, sizeof(cubeIndices), cubeIndices, GL_STATIC_DRAW);
        
        isInit = YES;
    }
    glEnable(GL_DEPTH_TEST);
    
    // Update uniform value
    glUniformMatrix4fv(uniforms[UNIFORM_MODELVIEWMATRIX], 1, 0, currentModelViewMatrix);
    
    // Validate program before drawing. This is a good check, but only really necessary in a debug build.
    // DEBUG macro must be defined in your debug configurations if that's not already the case.
    // Draw
    glBindBuffer(GL_ARRAY_BUFFER, vertexBufferId2); 
    glVertexAttribPointer(ARDRONE_ATTRIB_POSITION, 3, GL_FLOAT, GL_FALSE, 0, 0);
    glEnableVertexAttribArray(ARDRONE_ATTRIB_POSITION);
    
    GLuint useTexture = glGetUniformLocation(programId, "UseTexture");
    glUniform1f(useTexture, 0);
    GLuint colorUniform = glGetUniformLocation(programId, "SourceColor");
    glUniform4f(colorUniform, 0, 0, 1, 1);
    
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, indexBufferId2);
    glDrawElements(GL_TRIANGLES, sizeof(cubeIndices)/sizeof(GLushort), GL_UNSIGNED_SHORT, (void*)0);
#endif
    [context presentRenderbuffer:GL_RENDERBUFFER];
}
- (void) createVBO
{
    GLuint textureUniform = glGetUniformLocation(programId, "texture");
    glUniform1i(textureUniform, 0);
    
    //    glGenTextures(2, textureId);
    glGenTextures(1, textureId);
    printf("Video texture identifier : %d\n", textureId[0]);
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D,textureId[0]);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    
    /*    printf("Video texture identifier : %d\n", textureId[1]);
    glActiveTexture(GL_TEXTURE1);
    glBindTexture(GL_TEXTURE_2D, textureId[1]);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
     glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);*/
        // Sets up pointers and enables states needed for using vertex arrays and textures
        // Vertices
        glGenBuffers(1, &vertexBufferId);
        glBindBuffer(GL_ARRAY_BUFFER, vertexBufferId); 
    glBufferData(GL_ARRAY_BUFFER, sizeof(vertex), vertex, GL_STATIC_DRAW);
    glVertexAttribPointer(ARDRONE_ATTRIB_POSITION, 3, GL_FLOAT, GL_FALSE, sizeof(InterleavedVertex), (void*)offsetof(InterleavedVertex, position));
    glEnableVertexAttribArray(ARDRONE_ATTRIB_POSITION);
    glVertexAttribPointer(ARDRONE_ATTRIB_TEXCOORD, 2, GL_FLOAT, GL_FALSE, sizeof(InterleavedVertex), (void*)offsetof(InterleavedVertex, texcoord));
    glEnableVertexAttribArray(ARDRONE_ATTRIB_TEXCOORD);
    printf("Video vertex buffer identifier : %d\n", vertexBufferId);

        // Indexes
        glGenBuffers(1, &indexBufferId);
        glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, indexBufferId);
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, sizeof(indexes), indexes, GL_STATIC_DRAW);
    printf("Video index buffer identifier : %d\n", indexBufferId);
    }

@end
