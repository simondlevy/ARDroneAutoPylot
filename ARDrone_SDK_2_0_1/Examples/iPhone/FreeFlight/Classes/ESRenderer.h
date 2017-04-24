//
//  ESRenderer.h
//  FreeFlight
//
//  Created by Frédéric D'HAEYER on 24/10/11.
//  Copyright Parrot SA 2009. All rights reserved.
//
#import <QuartzCore/QuartzCore.h>
#import <OpenGLES/ES2/gl.h>
#import <OpenGLES/ES2/glext.h>
#import "ARDroneProtocols.h"
#import "ARDrone.h"
#import "OpenGLSprite.h"

@interface ESRenderer : NSObject <OpenGLSpriteDelegate>
{
@private
	EAGLContext *context;

	// The OpenGL names for the framebuffer and renderbuffer used to render to this view
	GLuint defaultFramebuffer, colorRenderbuffer;
    GLuint defaultDepthbuffer;
	GLuint textureId[2];
	GLuint vertexBufferId;
	GLuint indexBufferId;
    GLuint programId;
    OpenGLSprite* video;

#ifdef ADD_3D_ITEM 
    GLuint vertexBufferId2, indexBufferId2;
#endif
    
    BOOL orientationRight;
}
- (id) initWithFrame:(CGRect)frame andDrone:(ARDrone*)drone;
- (void) render:(ARDrone *)instance;
- (BOOL) resizeFromLayer:(CAEAGLLayer *)layer;
- (void)setScreenOrientationRight:(BOOL)_screenOrientationRight;
@end

