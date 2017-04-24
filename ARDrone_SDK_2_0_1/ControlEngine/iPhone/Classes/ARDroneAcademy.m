//
//  ARDroneAcademy.m
//  ARDroneEngine
//
//  Created by Nicolas Payot on 20/06/11.
//  Copyright 2011 PARROT. All rights reserved.
//

#import "ARDroneAcademy.h"
#import <ardrone_tool/Academy/academy.h>

static ARDroneAcademy *ardroneAcademy = nil;

void ARDroneAcademyCallback(academy_state_t state)
{
    id <ARDroneAcademyDelegate> delegate = ardroneAcademy.delegate;
    
    ardroneAcademy.state = (ARDRONE_ACADEMY_STATE) state.state;
//    ardroneAcademy.time_in_ms = (int)state.time_in_ms;
    ardroneAcademy.result = (ARDRONE_ACADEMY_RESULT) state.result;
    
    if (delegate) [delegate ARDroneAcademyDidRespond:ardroneAcademy];
}

@implementation ARDroneAcademy

@synthesize delegate = _delegate;
@synthesize state = _state;
//@synthesize time_in_ms = _time_in_ms;
@synthesize result = _result;

#pragma mark Singleton Methods

+ (id)sharedInstance
{
    @synchronized(self)
    {
        if (ardroneAcademy == nil)
            ardroneAcademy = [[super allocWithZone:NULL] init];
    }
    return ardroneAcademy;
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

- (oneway void)release
{
    // Never released
}

- (id)autorelease
{
    return self;
}

// Should never be called but here for clarity
- (void)dealloc
{
    [super dealloc];
}

- (id)init
{
    self = [super init];
    if (self) 
    {
    }
    return self;
}


- (BOOL)connectWithUsername:(NSString *)username withPassword:(NSString *)password
{
    const char *pcUsername = [username cStringUsingEncoding:NSASCIIStringEncoding];
    const char *pcPassword = [password cStringUsingEncoding:NSASCIIStringEncoding];
    
    C_RESULT res = academy_connect(pcUsername, pcPassword, ARDroneAcademyCallback);
    
    return (res == C_FAIL) ? NO : YES;
}

- (BOOL)disconnect
{
    C_RESULT res =  academy_disconnect();
    
    return (res == C_FAIL) ? NO : YES;
}

@end
