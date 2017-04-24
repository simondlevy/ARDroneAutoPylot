//
//  MenuHome.m
//  FreeFlight
//
//  Created by Clément Choquereau / Nicolas Payot on 06/06/11.
//  Copyright 2011 PARROT. All rights reserved.
//

#import "MenuHome.h"
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include "plf.h"
#include <dlfcn.h>

#import "FiniteStateMachine.h"
#import "MenuGuestSpace.h"
#import "MenuGames.h"
#import "MenuUpdater.h"
#import "Common.h"
#import "MediaThumbsViewController.h"
#import "MenuPreferences.h"
#import "ARUtils.h"

#define MAX_RETRIES 5

#define UPDATE_DRONE_ALERT_KEY (105)
#define REMOVE_USB_ALERT_KEY (106)

#define VERSION_TXT @"version.txt"

#define AA_REGISTER_URL @"http://ardrone2.parrot.com/promo/aa/"

typedef enum {
    DRONE_PING_IDLE,
    DRONE_PING_IN_PROGRESS,
} dronePingStatus;

dronePingStatus pingStatus = DRONE_PING_IDLE;

@implementation MenuHome 
@synthesize documentPath; 
@synthesize firmwareVersion;
@synthesize firmwarePath;
@synthesize firmwareFileName;
@synthesize droneFirmwareVersion;
@synthesize fsm;

#pragma mark init
- (id) initWithController:(MenuController*)menuController
{        	
	if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
		self = [super initWithNibName:@"MenuHome-iPad" bundle:nil];
	else
		self = [super initWithNibName:@"MenuHome" bundle:nil];
	
	if (self)
	{
		controller = menuController;
        self.documentPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
	}
    
	return self;
}

- (void)observeNotifications:(NSNotification *)notification
{
    if([[notification name] isEqualToString:ARDroneMediaManagerDidRefresh])
    {   
        if(![photosVideosButton isActive])
        {
            [photosVideosButton setActive:YES];
            [[NSNotificationCenter defaultCenter] removeObserver:self name:ARDroneMediaManagerDidRefresh object:nil];
        }
    }
}

- (void) viewDidLoad
{          
    [super viewDidLoad];
    
    statusBar = [[ARStatusBarViewController alloc] initWithNibName:STATUS_BAR bundle:nil];
    [statusBar setDelegate:self];
    [self.view addSubview:statusBar.view];
    
    [freeFlightButton setTitle:LOCALIZED_STRING(@"PILOTING") forState:UIControlStateNormal];
    [ARDroneAcademyButton setTitle:LOCALIZED_STRING(@"AR.DRONE\nACADEMY") forState:UIControlStateNormal];
    [photosVideosButton setTitle:LOCALIZED_STRING(@"PHOTOS\nVIDEOS") forState:UIControlStateNormal];
    [updateFirmwareButton setTitle:LOCALIZED_STRING(@"AR.DRONE\nUPDATE") forState:UIControlStateNormal];
    [gamesButton setTitle:LOCALIZED_STRING(@"GAMES") forState:UIControlStateNormal];
    [guestSpaceButton setTitle:LOCALIZED_STRING(@"USERS\nVIDEOS") forState:UIControlStateNormal];
    // Set menu buttons information text
    [freeFlightButton.infoLabel setText:LOCALIZED_STRING(@"Wi-Fi NOT AVAILABLE, PLEASE CONNECT YOUR DEVICE TO YOUR AR.DRONE")];
    [ARDroneAcademyButton.infoLabel setText:LOCALIZED_STRING(@"INTERNET CONNECTION NOT AVAILABLE")];
    [photosVideosButton.infoLabel setText:LOCALIZED_STRING(@"NO FLIGHT PHOTOS OR VIDEOS SAVED ON YOUR DEVICE")];
    [updateFirmwareButton.infoLabel setText:LOCALIZED_STRING(@"Wi-Fi NOT AVAILABLE, PLEASE CONNECT YOUR DEVICE TO YOUR AR.DRONE")];
    
    if([[[ARDroneMediaManager sharedInstance] mediaDictionary] count] > 0)
    {
        [photosVideosButton setActive:YES];
    }
    else
    {
        [photosVideosButton setActive:NO];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(observeNotifications:) name:ARDroneMediaManagerDidRefresh object:nil];
    }
    
    NSString *plistPath = [[NSBundle mainBundle] pathForResource:@"Firmware" ofType:@"plist"];
	NSDictionary *plistDict = [NSDictionary dictionaryWithContentsOfFile:plistPath];
	self.firmwareFileName = [plistDict objectForKey:@"FirmwareFileName"];
	self.firmwarePath = nil;
	self.firmwareVersion = nil;
	self.droneFirmwareVersion = nil;
    checkConnection = YES;
    
    [freeflightVersion setText:[NSString stringWithFormat:@"v%s", 
                                [[[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"] cStringUsingEncoding:NSUTF8StringEncoding]]];
    	
    [freeFlightButton setActive:NO];
    [updateFirmwareButton setActive:NO];
    [ARDroneAcademyButton setActive:NO];
    
    // Check internet connection for AR.Drone Academy button enabling
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:AA_REGISTER_URL]];
    reachabilityConnection = [[NSURLConnection connectionWithRequest:request delegate:self] retain];
    [reachabilityConnection start];
    
    self.fsm = [FiniteStateMachine fsmWithXML:[[NSBundle mainBundle] pathForResource:@"initializer_fsm" ofType:@"xml"]];
    fsm.delegate = self;
    fsm.currentState = H_STATE_WAITING_CONNECTION;

    [self performSelectorInBackground:@selector(checkDroneConnection) withObject:nil];
}

- (void)startPing
    {
    NSURL *myURL = [NSURL URLWithString:[NSString stringWithFormat:@"ftp://%@:%d/", [NSString stringWithCString:&controller.ardrone_info->drone_address[0] encoding:NSUTF8StringEncoding], 5551]];
    NSURLRequest *theRequest = [NSURLRequest requestWithURL:myURL cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:1.0];
    pingStatus = DRONE_PING_IN_PROGRESS;
    droneConnection = [[[NSURLConnection alloc] initWithRequest:theRequest delegate:self] retain];   
    }

- (void)checkDroneConnection
{
    while (checkConnection) 
    {
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        
        if (DRONE_PING_IDLE == pingStatus
            && NULL != controller.ardrone_info
            && NULL != controller.ardrone_info->drone_address)
        {
            [self performSelectorOnMainThread:@selector(startPing) withObject:nil waitUntilDone:NO];
        }[pool drain];
        
        sleep (2);
    }
}

- (void)getDroneVersion:(NSNumber *)_succeded
{
    BOOL succeded = [_succeded boolValue];
    
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    BOOL opSucceded = NO;
    
    if (succeded)
    {
        ARDroneFTP *checkFtp = [ARDroneFTP anonymousUpdateFTPwithDelegate:self withDefaultCallback:nil];
        NSString *path = [NSString stringWithFormat:@"%@/%@", documentPath, @"version.txt"];
        ARDFTP_RESULT res = [checkFtp getSynchronouslyDistantFile:@"version.txt" toLocalFile:path withResume:NO];
        if (ARDFTP_SUCCEEDED (res))
        {
            NSError *readError;
            NSString *tempDroneFirmwareVersion = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:&readError];
            if (nil != tempDroneFirmwareVersion)
            {
                opSucceded = YES;
                self.droneFirmwareVersion = [tempDroneFirmwareVersion copy];
            }
        }
        [checkFtp close];
        pingStatus = DRONE_PING_IDLE;
    }
    else
    {
        pingStatus = DRONE_PING_IDLE;
    }
    
    [droneConnection cancel];
    [droneConnection release];
    [self performSelectorOnMainThread:@selector(enableFreeFlightButton:) withObject:[NSNumber numberWithBool:opSucceded] waitUntilDone:YES];
    if (opSucceded)
    {
        [fsm setCurrentState:H_STATE_WAITING_CONNECTION];
        [fsm doAction:H_ACTION_SUCCESS];
    }
    else
    {
        [updateFirmwareButton setActive:NO];
    }
    
    [pool drain];
}

- (void)didReceiveMemoryWarning
{
	[super didReceiveMemoryWarning];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [statusBar release];
    [freeFlightButton release];
    [guestSpaceButton release];
    [updateFirmwareButton release];
    [ARDroneAcademyButton release];
    [gamesButton release];
    [photosVideosButton release];
    [freeflightVersion release];
    [reachabilityConnection release];
	
	self.firmwarePath = nil;
	self.firmwareFileName = nil;
	self.firmwareVersion = nil;
	self.droneFirmwareVersion = nil;
	self.documentPath = nil;
	self.fsm = nil;

	[super dealloc];
}

- (void)enableFreeFlightButton:(NSNumber *)enable
{
    static BOOL firstTime = YES;
    if ([enable boolValue] && firstTime && NULL != controller.ardrone_info)
    {
        NSArray *components = [[NSString stringWithCString:&controller.ardrone_info->drone_version[0] encoding:NSUTF8StringEncoding] componentsSeparatedByString:@"."];
        if(NSOrderedSame == [(NSString *)[components objectAtIndex:0] compare:@"1" options:NSNumericSearch] &&
           NSOrderedAscending == [(NSString *)[components objectAtIndex:1] compare:@"10" options:NSNumericSearch])
        {
            UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:LOCALIZED_STRING(@"Update Warning") 
                                                                message:LOCALIZED_STRING(@"Please update your AR.Drone to allow video recording and sharing and full compatibility with this app update.") 
                                                               delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil, nil];
            [alertView setTag:UPDATE_DRONE_ALERT_KEY];
            [alertView show];
            [alertView release];
        }
        firstTime = NO;
    }
    [freeFlightButton setActive:[enable boolValue]];
}

#pragma mark ----
- (void)executeCommandOut:(ARDRONE_COMMAND_OUT)commandId withParameter:(void*)parameter fromSender:(id)sender
{
    switch(commandId)
    {
        case ARDRONE_COMMAND_RUN:
            break;
            
        case ARDRONE_COMMAND_PAUSE:
           break;
            
        default:
            break;
    }
}

/*
 * Waiting Connection State:
 *
 *
 */

// Enter
- (void)enterWaitingConnection:(id)_fsm
{

}

// Quit
- (void)quitWaitingConnection:(id)_fsm
{

}

/*
 * Check Version State:
 *
 *
 */
// Enter
- (void)enterCheckVersion:(id)_fsm
{
    plf_phdr plf_header;
	NSArray *components = [droneFirmwareVersion componentsSeparatedByString:@"."];
    if(NSOrderedSame == [(NSString *)[components objectAtIndex:0] compare:@"1" options:NSNumericSearch])
    {
        self.firmwarePath = [[NSBundle mainBundle] pathForResource:[NSString stringWithFormat:firmwareFileName, @""] ofType:@"plf"];
    }
    else
    {
        self.firmwarePath = [[NSBundle mainBundle] pathForResource:[NSString stringWithFormat:firmwareFileName, (NSString *)[components objectAtIndex:0]] ofType:@"plf"];
    }
    
    if(plf_get_header([self.firmwarePath cStringUsingEncoding:NSUTF8StringEncoding], &plf_header) != 0)
        memset(&plf_header, 0, sizeof(plf_phdr));
    
    self.firmwareVersion = [NSString stringWithFormat:@"%d.%d.%d", plf_header.p_ver, plf_header.p_edit, plf_header.p_ext];
        
    [updateFirmwareButton.infoLabel setText:LOCALIZED_STRING(@"YOUR AR.DRONE IS UP TO DATE")];
    
	switch ([firmwareVersion compare:droneFirmwareVersion options:NSNumericSearch])
	{
		case NSOrderedAscending:
			[fsm doAction:H_ACTION_ASK_FOR_FREEFLIGHT_UPDATE];
            [updateFirmwareButton setActive:NO];
			break;
            
		case NSOrderedSame:
			[fsm doAction:H_ACTION_SUCCESS];
            [updateFirmwareButton setActive:NO];
			break;
            
		default:
            [updateFirmwareButton setActive:YES];
			break;
	}
    
}

// Quit
- (void)quitCheckVersion:(id)_fsm
{

}

/*
 * Update Freeflight State:
 *
 *
 */
// Enter
- (void)enterUpdateFreeflight:(id)_fsm
{

}

/*
 * Launch Freeflight State:
 *
 *
 */
// Enter
- (void)enterLaunchFreeflight:(id)_fsm
{

}

#pragma mark - 
#pragma mark - IBActions

- (IBAction)flyAction:(id)sender
{
	if (![freeFlightButton isActive])
	{
		[freeFlightButton displayInfo];
		return;
	}
	
    checkConnection = NO;
    [controller doAction:MENU_FF_ACTION_JUMP_TO_HUD];
}

- (IBAction)updateFirmware:(id)sender
{
	if (![updateFirmwareButton isActive])
	{
		[updateFirmwareButton displayInfo];
		return;
	}
    
    NSArray *components = [[NSString stringWithCString:&controller.ardrone_info->drone_version[0] encoding:NSUTF8StringEncoding] componentsSeparatedByString:@"."];
    if(NSOrderedSame != [(NSString *)[components objectAtIndex:0] compare:@"1" options:NSNumericSearch])
    {
        UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:LOCALIZED_STRING(@"Update Warning") 
                                                            message:LOCALIZED_STRING(@"Please un-plug your USB key from the AR.Drone now") 
                                                           delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil, nil];
        [alertView setTag:REMOVE_USB_ALERT_KEY];
        [alertView show];
        [alertView release];
    }
    else
    {
        checkConnection = NO;
        [controller doAction:MENU_FF_ACTION_JUMP_TO_UPDATER];
    }
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (REMOVE_USB_ALERT_KEY == alertView.tag)
    {
        checkConnection = NO;
        [controller doAction:MENU_FF_ACTION_JUMP_TO_UPDATER];
    }
}

- (IBAction)launchARDroneAcademy:(id)sender
{
	if (![ARDroneAcademyButton isActive])
	{
		[ARDroneAcademyButton displayInfo];
	}
    else
    {
        NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:AA_REGISTER_URL]];
        ARWebViewController *webViewController = [[ARWebViewController alloc] init];
        [controller presentModalViewController:webViewController animated:YES];
        [webViewController loadRequest:request];
        [webViewController release];
    }
}

- (IBAction)openGuestSpace:(id)sender
{
    checkConnection = NO;
    [controller doAction:MENU_FF_ACTION_JUMP_TO_GUEST_SPACE];
}

- (IBAction)openGames:(id)sender
{
    checkConnection = NO;
    [controller doAction:MENU_FF_ACTION_JUMP_TO_GAMES];
}

- (IBAction)openMedia:(id)sender
{
	if (![photosVideosButton isActive])
	{
		[photosVideosButton displayInfo];
		return;
	}
	
    checkConnection = NO;
    [controller doAction:MENU_FF_ACTION_JUMP_TO_MEDIA];
}

- (void)statusBarPreferencesClicked:(ARStatusBarViewController *)bar
{
    checkConnection = NO;
    [controller doAction:MENU_FF_ACTION_JUMP_TO_PREFERENCES];
}

#pragma mark - 
#pragma mark NSURLConnection delegate

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
    if (reachabilityConnection == connection)
    {
        // Device is connected to internet
        [ARDroneAcademyButton setActive:YES];
}
    else if (droneConnection == connection)
    {
        pingStatus = DRONE_PING_IDLE;
        [self getDroneVersion:[NSNumber numberWithBool:YES]];
        [connection release];
    }
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    if (reachabilityConnection == connection)
    {
        [ARDroneAcademyButton setActive:NO];
}
    else if (droneConnection == connection)
    {
        pingStatus = DRONE_PING_IDLE;
        [self getDroneVersion:[NSNumber numberWithBool:NO]];
        [connection release];
    }
}

@end
