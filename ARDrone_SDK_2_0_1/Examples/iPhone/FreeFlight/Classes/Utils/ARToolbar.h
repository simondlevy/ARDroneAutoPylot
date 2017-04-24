//
//  ARToolbar.h
//  ARDroneAcademy
//
//  Created by Nicolas Payot on 03/05/11.
//  Copyright 2011 PARROT. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Common.h"

@interface ARToolbar : UIToolbar {
    UIBarButtonItem *doneButton;
}

@property (nonatomic, retain) UIBarButtonItem *doneButton;

- (id)init;

@end
