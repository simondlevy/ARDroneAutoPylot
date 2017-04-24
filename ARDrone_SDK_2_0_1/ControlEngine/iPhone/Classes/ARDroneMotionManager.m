//
//  ARDroneMotionManager.m
//  ARDroneEngine
//
//  Created by Frédéric D'HAEYER on 12/12/11.
//  Copyright (c) 2011 Parrot SA. All rights reserved.
//

#import "ARDroneMotionManager.h"

static ARDroneMotionManager *_ARDroneMotionManager = nil;

@implementation ARDroneMotionManager

@synthesize motionManager;

+ (ARDroneMotionManager *)sharedInstance
{
    @synchronized(self)
    {
        if (_ARDroneMotionManager == nil)
        {
            _ARDroneMotionManager = [[super allocWithZone:NULL] init];
        }            
    }
    return _ARDroneMotionManager;
}

+ (id)allocWithZone:(NSZone *)zone
{
    return [[self sharedInstance] retain];
}

- (id)copyWithZone:(NSZone *)zone
{
    return self;
}

- (id)retain
{
    return self;
}

- (unsigned)retainCount 
{
    // Denotes an object that cannot be released
    return UINT_MAX; 
}

- (id)autorelease
{
    return self;
}

- (id)init
{
    self = [super init];
    motionManager = [[CMMotionManager alloc] init];

    if (self) 
    {

    }
    return self;
}

// Should never be called but here for clarity
- (void)dealloc
{
    [super dealloc];
}

@end
