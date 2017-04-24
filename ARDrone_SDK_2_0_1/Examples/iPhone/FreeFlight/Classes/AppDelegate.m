//
//  AppDelegate.m
//  FreeFlight
//
//  Created by Frédéric D'HAEYER on 16/10/09.
//  Copyright Parrot SA 2009. All rights reserved.
//
#import <AVFoundation/AVFoundation.h>
#import "AppDelegate.h"
#import "EAGLView.h"
#import "GoogleAPIManager.h"
#import "ARDroneMediaManager.h"
#import "MenuHome.h"

@implementation AppDelegate
@synthesize window;
@synthesize menuController;

- (void) applicationSetUpBackground
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    /***************************************************************/
    // Get username & password (Google)
    NSString *username = [defaults valueForKey:GOOGLE_USERNAME_KEY];
    NSString *password = [defaults valueForKey:GOOGLE_PASSWORD_KEY];
    
    // Setup credentials if user wished to stay connected to their google account in the previous session
    if (username && password)
    {
        // Set ConnectionManager
        [[GoogleAPIManager sharedInstance] signIn:self username:username password:password];
    }
    

}

- (void) applicationSetUpForeground
{
	// Setup the ARDrone
	ARDroneHUDConfiguration hudconfiguration = {YES, YES, YES, YES, YES};
	drone = [[ARDrone alloc] initWithFrame:menuController.view.frame withState:was_in_game withDelegate:menuController withHUDConfiguration:&hudconfiguration percentageMemorySpace:MEMORY_USAGE];
    
    [self performSelectorInBackground:@selector(applicationSetUpBackground) withObject:nil];
    
    // Setup the OpenGL view for video streaming
	glView = [[EAGLView alloc] initWithFrame:menuController.view.frame andDrone:drone];
	[glView changeState:was_in_game];
	[glView setRenderer:drone];
    
	[menuController.view addSubview:drone.view];
    
    [window addSubview:glView];
    
	[window bringSubviewToFront:menuController.view];
 	[window makeKeyAndVisible];
    
    [self checkAuthorizationLibrary];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:@"application_initialized" object:self];
}

- (void) applicationDidFinishLaunching:(UIApplication *)application
{
	application.idleTimerDisabled = YES;
    
    // Setup the menu controller
	menuController.delegate = self;
	was_in_game = NO;
    
	[menuController changeState:was_in_game];
    
    [window setRootViewController:menuController];
    
	[window bringSubviewToFront:menuController.view];
 	[window makeKeyAndVisible];
    
    [self performSelectorOnMainThread:@selector(applicationSetUpForeground) withObject:nil waitUntilDone:NO];
}

- (void) dealloc
{
    [menuController release];
    [window release];
    [super dealloc];
}

#pragma mark -
#pragma mark Drone protocol implementation
- (void)changeState:(BOOL)inGame
{
	was_in_game = inGame;
	if (inGame)
	{
		int value;
		[drone setScreenOrientationRight:(menuController.interfaceOrientation == UIInterfaceOrientationLandscapeRight)];
		value = ARDRONE_CAMERA_DETECTION_NONE;
		[drone setDefaultConfigurationForKey:ARDRONE_CONFIG_KEY_DETECT_TYPE withValue:&value];
		[glView setScreenOrientationRight:(menuController.interfaceOrientation == UIInterfaceOrientationLandscapeRight)];
		value = 0;
		[drone setDefaultConfigurationForKey:ARDRONE_CONFIG_KEY_CONTROL_LEVEL withValue:&value];
        
        [[(AppDelegate *)[UIApplication sharedApplication].delegate window] setBackgroundColor:[UIColor blackColor]];
    }
    else
    {
        [[(AppDelegate *)[UIApplication sharedApplication].delegate window] setBackgroundColor:[UIColor whiteColor]];
	}
    
	[drone changeState:inGame];
	[glView changeState:inGame];
}

- (void) applicationWillResignActive:(UIApplication *)application
{
	// Become inactive
	if(was_in_game)
	{
		[drone changeState:NO];
		[glView changeState:NO];
	}
    // NO ELSE - MenuController is in charge to change state
}

- (void) applicationDidBecomeActive:(UIApplication *)application
{
	if(was_in_game)
	{
		[drone changeState:YES];
		[glView changeState:YES];
	}
    // NO ELSE - MenuController is in charge to change state
}

- (void)applicationWillTerminate:(UIApplication *)application
{
	printf("%s : %d\n", __FUNCTION__, was_in_game);
    
    [[GoogleAPIManager sharedInstance] signOut];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
	if(was_in_game)
	{
        [window setBackgroundColor:[UIColor whiteColor]];
        
		[drone changeState:NO];
		[glView changeState:NO];
	}
    // NO ELSE - MenuController is in charge to change state
    
    [glView release];
    [drone release];
}

- (void)executeCommandIn:(ARDRONE_COMMAND_IN_WITH_PARAM)commandIn fromSender:(id)sender refreshSettings:(BOOL)refresh
{
	
}

- (void)executeCommandIn:(ARDRONE_COMMAND_IN)commandId withParameter:(void*)parameter fromSender:(id)sender
{
	
}

- (void)setDefaultConfigurationForKey:(ARDRONE_CONFIG_KEYS)key withValue:(void *)value
{
	
}

- (BOOL)checkState
{
	BOOL result = NO;
	
	if(was_in_game)
	{
		result = [drone checkState];
	}
    // NO ELSE - Menu controller is in charge to change state
	
	return result;
}


-(void)checkAuthorizationLibrary
{
    if ( [ALAssetsLibrary respondsToSelector:@selector(authorizationStatus)]
        && [ALAssetsLibrary authorizationStatus] !=3 )
    {
        UIAlertView *alertViewAsset = [[UIAlertView alloc] initWithTitle:@"Services Privacy Photos disabled"//ARDroneEngineLocalizeString(@"ID000125")
                                                                 message:@"If you want to access your media gallery, enable it in your device's settings."//ARDroneEngineLocalizeString(@"ID000124")
                                                                delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil, nil];
        [alertViewAsset show];
        [alertViewAsset release];
    }
    
}

@end
