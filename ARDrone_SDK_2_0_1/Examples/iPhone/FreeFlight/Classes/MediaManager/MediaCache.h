//
//  MediaCache.h
//  FreeFlight
//
//  Created by Nicolas Payot on 11/01/12.
//  Copyright (c) 2012 PARROT. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface MediaCache : NSCache
{
    // Nothing here
}

+ (MediaCache *)sharedInstance;

@end
