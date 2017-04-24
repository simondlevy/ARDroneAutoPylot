//
//  MediaCache.m
//  FreeFlight
//
//  Created by Nicolas Payot on 11/01/12.
//  Copyright (c) 2012 PARROT. All rights reserved.
//

#import "MediaCache.h"

@implementation MediaCache

static MediaCache *singleton = nil;

// Making a thread-safe singleton creation
+ (MediaCache *)sharedInstance 
{        
    if (nil != singleton) return singleton;
    // Lock
    static dispatch_once_t pred;
    // This code is executed at most once
    dispatch_once(&pred, ^{ 
        singleton = [[super allocWithZone:NULL] init]; 
    });
    return singleton;
}

- (id)init
{
    self = [super init];
    if (self) 
    {
        // Nothing here
    }
    return self;
}

- (void)dealloc
{
    // Never called but here for clarity
    [super dealloc];
}

// Should not allocate a new instance, so return the current one
+ (id)allocWithZone:(NSZone*)zone 
{
    return [[self sharedInstance] retain];
}

// Should not generate multiple copies of the singleton
- (id)copyWithZone:(NSZone *)zone 
{
    return self;
}

// Do nothing, as no retain counter for this object
- (id)retain 
{
    return self;
}

// Replace the retain counter so we can never release this object
- (NSUInteger)retainCount 
{
    return NSUIntegerMax;
}

- (oneway void)release 
{
    // Empty, as we don't want to let the user release this object
}

// Do nothing, other than return the shared instance - as this is expected from autorelease
- (id)autorelease 
{
    return self;
}

@end
