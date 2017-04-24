//
//  AppDelegate.h
//  FreeFlight
//
//  Created by Frédéric D'HAEYER on 16/10/09.
//  Copyright Parrot SA 2009. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "ARDrone.h"
#import "MenuController.h"
#import <MediaPlayer/MediaPlayer.h>
#import "Common.h"
#import "GoogleAPIManager.h"
#import "ARUtils.h"

@class EAGLView;

@interface AppDelegate : NSObject <UIApplicationDelegate, ARDroneProtocolIn, GoogleAPIManagerDelegate> 
{
	UIWindow *window;
	BOOL was_in_game;
	
	MenuController *menuController;
	ARDrone *drone;
	EAGLView *glView;
}

@property (nonatomic, retain) IBOutlet MenuController *menuController;
@property (nonatomic, retain) IBOutlet UIWindow *window;

@end
