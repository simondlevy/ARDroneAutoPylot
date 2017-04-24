//
//  EAGLView.m
//  FreeFlight
//
//  Created by Frédéric D'HAEYER on 16/10/09.
//  Copyright Parrot SA 2009. All rights reserved.
//
#import "EAGLView.h"
#import "ESRenderer.h"

@interface EAGLView (private)
- (void)startAnimation;
- (void)stopAnimation;
@end

@implementation EAGLView
@synthesize animating;
@synthesize displayLink;
@dynamic animationFrameInterval;

// You must implement this method
+ (Class) layerClass
{
    return [CAEAGLLayer class];
}

- (id)initWithFrame:(CGRect)frame andDrone:(ARDrone *)drone
{
	if ((self = [super initWithFrame:frame]))
	{
        // Get the layer
        CAEAGLLayer *eaglLayer = (CAEAGLLayer *)self.layer;

        eaglLayer.opaque = NO;
        eaglLayer.drawableProperties = [NSDictionary dictionaryWithObjectsAndKeys:
                                        [NSNumber numberWithBool:FALSE], kEAGLDrawablePropertyRetainedBacking, kEAGLColorFormatRGBA8, kEAGLDrawablePropertyColorFormat, nil];
		
		instance = nil;
		renderer = [[ESRenderer alloc] initWithFrame:frame andDrone:drone];
		
		if (!renderer)
		{
            [self release];
            return nil;
		}
        
		displayLinkSupported = FALSE;
		animating = FALSE;
		animationFrameInterval = 1;
        self.displayLink = nil;
        
        // A system version of 3.1 or greater is required to use CADisplayLink. The NSTimer
		// class is used as fallback when it isn't available.
		NSString *reqSysVer = @"3.1";
		NSString *currSysVer = [[UIDevice currentDevice] systemVersion];
		if ([currSysVer compare:reqSysVer options:NSNumericSearch] != NSOrderedAscending)
			displayLinkSupported = TRUE;
	}

    return self;
}
- (void)setScreenOrientationRight:(BOOL)_screenOrientationRight
{
    [renderer setScreenOrientationRight:_screenOrientationRight];
}

- (void) setRenderer:(id)_instance
{
	instance = _instance;
}

- (void) drawView
{
	[renderer render:instance];
}

- (void) layoutSubviews
{
	[renderer resizeFromLayer:(CAEAGLLayer*)self.layer];
    [self drawView];
}

- (void) startAnimation
{
	if (!animating)
	{
		if (displayLinkSupported)
		{
			// CADisplayLink is API new to iPhone SDK 3.1. Compiling against earlier versions will result in a warning, but can be dismissed
			// if the system version runtime check for CADisplayLink exists in -initWithCoder:. The runtime check ensures this code will
			// not be called in system versions earlier than 3.1.
			
			displayLink = [NSClassFromString(@"CADisplayLink") displayLinkWithTarget:self selector:@selector(drawView)];
			[displayLink setFrameInterval:animationFrameInterval];
			[displayLink addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
		}
		else
        {
			animationTimer = [NSTimer scheduledTimerWithTimeInterval:(NSTimeInterval)((1.0 / 60.0) * animationFrameInterval) target:self selector:@selector(drawView) userInfo:nil repeats:TRUE];
		}
        
		animating = TRUE;
	}
}

- (void)stopAnimation
{
	if (animating)
	{
		if (displayLinkSupported)
		{
			[displayLink invalidate];
			displayLink = nil;
		}
		else
		{
			[animationTimer invalidate];
			animationTimer = nil;
		}
		
		animating = FALSE;
	}
}

- (NSInteger) animationFrameInterval
{
	return animationFrameInterval;
}

- (void)setAnimationFrameInterval:(NSInteger)frameInterval
{
    /*
	 Frame interval defines how many display frames must pass between each time the display link fires.
	 The display link will only fire 30 times a second when the frame internal is two on a display that refreshes 60 times a second. The default frame interval setting of one will fire 60 times a second when the display refreshes at 60 times a second. A frame interval setting of less than one results in undefined behavior.
	 */
    if (frameInterval >= 1) {
        animationFrameInterval = frameInterval;
        
        if (animating) {
            [self stopAnimation];
            [self startAnimation];
        }
    }
}

- (void)changeState:(BOOL)inGame
{
    printf("%s %d\n", __FUNCTION__, inGame);
	if(inGame)
	{
		self.hidden = NO;
        [self startAnimation];
	}
	else
	{
		self.hidden = YES;
        [self stopAnimation];
	}
}

- (void) dealloc
{
    [renderer release];
	
    [super dealloc];
}

@end
