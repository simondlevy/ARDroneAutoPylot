//
//  MenuPreferences.h
//  FreeFlight
//
//  Created by Frédéric D'Haeyer on 11/14/11.
//  Copyright 2011 Parrot SA. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "MenuController.h"
#import "FiniteStateMachine.h"
#import "GoogleAPIManager.h"
#import "GoogleAPISignViewController.h"
#import "ARUtils.h"

@interface MenuPreferences : ARNavigationController <MenuProtocol>
{
    ARNavigationBarViewController *navBar;
    IBOutlet ARButton *googleAccountSignIn;
    BOOL displayHomeIcon;
    IBOutlet UILabel *googleAccountLabel;
}

@property (nonatomic, assign) BOOL displayHomeIcon;

@end
