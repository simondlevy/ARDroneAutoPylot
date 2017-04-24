//
//  ARNavigationController.h
//  FreeFlight
//
//  Created by Nicolas Payot on 25/08/11.
//  Copyright 2011 PARROT. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "MenuController.h"


@interface ARNavigationController : UIViewController <MenuProtocol> 
{
    MenuController *controller;
}

@end
