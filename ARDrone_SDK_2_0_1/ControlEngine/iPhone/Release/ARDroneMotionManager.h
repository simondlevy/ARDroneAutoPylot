//
//  ARDroneMotionManager.h
//  ARDroneEngine
//
//  Created by Frédéric D'HAEYER on 12/12/11.
//  Copyright (c) 2011 Parrot SA. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreMotion/CMMotionManager.h>

@interface ARDroneMotionManager : NSObject
{
    CMMotionManager* motionManager;
}
@property (nonatomic, assign) CMMotionManager* motionManager;

+ (ARDroneMotionManager *)sharedInstance;

@end
