//
//  MenuHome.h
//  FreeFlight
//
//  Created by Clément Choquereau / Nicolas Payot on 06/06/11.
//  Copyright 2011 PARROT. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <SystemConfiguration/SystemConfiguration.h>
#import <QuartzCore/QuartzCore.h>

#import "MenuController.h"
#import "ARDroneFTP.h"
#import "ARUtils.h"

enum
{
    H_STATE_WAITING_CONNECTION,
	H_STATE_CHECK_VERSION,
	H_STATE_UPDATE_FREEFLIGHT,
	H_STATE_LAUNCH_FREEFLIGHT,
	H_STATES_COUNT
};

enum
{
	H_ACTION_FAIL,
	H_ACTION_SUCCESS,
	H_ACTION_ASK_FOR_FREEFLIGHT_UPDATE,
	H_ACTIONS_COUNT
};

enum 
{ 
    FREE_FLIGHT_BUTTON,  
    UPDATE_FIRMWARE_BUTTON,
    ARDRONE_ACADEMY_BUTTON,
    PHOTOS_VIDEOS_BUTTON
};

@class ARMenuButton;

@interface MenuHome : UIViewController <MenuProtocol, ARDroneProtocolOut, UIAlertViewDelegate, ARStatusBarDelegate, 
                                        UINavigationControllerDelegate, UIImagePickerControllerDelegate>
{    
	MenuController *controller;
	
	IBOutlet UILabel *freeflightVersion;
	
    ARStatusBarViewController *statusBar;
    
    IBOutlet ARMenuButton *freeFlightButton;
    IBOutlet ARMenuButton *guestSpaceButton;
    IBOutlet ARMenuButton *updateFirmwareButton;
    IBOutlet ARMenuButton *ARDroneAcademyButton;
    IBOutlet ARMenuButton *gamesButton;
    IBOutlet ARMenuButton *photosVideosButton;
    
    NSURLConnection *reachabilityConnection;
    NSURLConnection *droneConnection;
    
	NSString *firmwarePath;
	NSString *firmwareFileName;
	NSString *firmwareVersion;
	NSString *droneFirmwareVersion;
    
    ARDroneFTP *ftp;
	
	FiniteStateMachine *fsm;
    NSString *documentPath;
    
    BOOL checkConnection;
}

@property (nonatomic, copy) NSString *firmwarePath;
@property (nonatomic, copy) NSString *firmwareFileName;
@property (nonatomic, copy) NSString *firmwareVersion;
@property (nonatomic, copy) NSString *droneFirmwareVersion;
@property (nonatomic, copy) NSString *documentPath;
@property (nonatomic, retain) FiniteStateMachine *fsm;

// Waiting connection
- (void)enterWaitingConnection:(id)_fsm;
- (void)quitWaitingConnection:(id)_fsm;

// Check Version:
- (void)enterCheckVersion:(id)_fsm;
- (void)quitCheckVersion:(id)_fsm;

// Update Freeflight:
- (void)enterUpdateFreeflight:(id)_fsm;

// Launch Freeflight:
- (void)enterLaunchFreeflight:(id)_fsm;

// IBActions:
- (IBAction)flyAction:(id)sender;
- (IBAction)updateFirmware:(id)sender;
- (IBAction)launchARDroneAcademy:(id)sender;
- (IBAction)openGuestSpace:(id)sender;
- (IBAction)openGames:(id)sender;
- (IBAction)openMedia:(id)sender;

- (void)checkDroneConnection;
- (void)startPing;

@end
