//
//  ARDroneAcademy.h
//  ARDroneEngine
//
//  Created by Nicolas Payot on 20/06/11.
//  Copyright 2011 PARROT. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ARDroneGeneratedTypes.h"

@class ARDroneAcademy;

@protocol ARDroneAcademyDelegate <NSObject>

- (void)ARDroneAcademyDidRespond:(ARDroneAcademy *)ARDroneAcademy;

@end

@interface ARDroneAcademy : NSObject {
    
    id <ARDroneAcademyDelegate> _delegate;
    
    ARDRONE_ACADEMY_STATE _state;
//    int               _time_in_ms;
    ARDRONE_ACADEMY_RESULT _result;
}

@property (nonatomic, retain) id <ARDroneAcademyDelegate> delegate;
//@property int time_in_ms;
@property ARDRONE_ACADEMY_STATE state;
@property ARDRONE_ACADEMY_RESULT result;

+ (id)sharedInstance;

- (BOOL)connectWithUsername:(NSString *)username withPassword:(NSString *)password;
- (BOOL)disconnect;

@end
