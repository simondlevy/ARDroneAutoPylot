//
//  MenuUpdater.m
//  Updater
//
//  Created by Clément Choquereau / Nicolas Payot on 10-05-14.
//  Copyright Parrot 2010. All rights reserved.
//
#import "MenuUpdater.h"
#import "MenuHome.h"
#import "MenuPreferences.h"

#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include "plf.h"

#define ALPHA_IN_PROGRESS   0.5
#define ALPHA_PASS          0.2

#define U_ASSERT(var, value)                                        \
if (var != value)													\
{																	\
	NSLog(@"oO ! "#var" is #%u (should be #%u)", (var), (value));	\
	return;															\
}

static BOOL first_time = YES;

typedef enum STEP_IMAGE
{
	STEP_IMAGE_EMPTY,
	STEP_IMAGE_PROGRESS,
	STEP_IMAGE_PASS,
	STEP_IMAGE_FAIL,
	STEP_IMAGE_MAX,
} eSTEP_IMAGE;

#define MAX_RETRIES 5
#define VERSION_TXT @"version.txt"

@interface MenuUpdater (private)
- (void) updateStepImage:(eSTEP_IMAGE)step toImageView:(UIImageView *)imageView;
- (void) updateStatusLabel;
@end

@implementation MenuUpdater
@synthesize documentPath;
@synthesize firmwareVersion;
@synthesize firmwarePath;
@synthesize firmwareFileName;
@synthesize repairPath;
@synthesize repairFileName;
@synthesize repairVersion;
@synthesize bootldrPath;
@synthesize bootldrFileName;
@synthesize droneFirmwareVersion;
@synthesize ftp;
@synthesize repairFtp;
@synthesize fsm;

#pragma mark init
- (id) initWithController:(MenuController*)menuController
{
    self.documentPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
	
	if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
		self = [super initWithNibName:@"MenuUpdater-iPad" bundle:nil];
	else
		self = [super initWithNibName:@"MenuUpdater" bundle:nil];
	
	if (self) controller = menuController;
    
	return self;
}

- (void) viewDidLoad
{
    [super viewDidLoad];

    self.navigationController.navigationBarHidden = YES;

    statusBar = [[ARStatusBarViewController alloc] initWithNibName:STATUS_BAR bundle:nil];
    [statusBar setDelegate:self];
    [self.view addSubview:statusBar.view];

    // Do any additional setup after loading the view from its nib.
    navBar = [[ARNavigationBarViewController alloc] initWithNibName:NAVIGATION_BAR bundle:nil];
    [self.view addSubview:navBar.view];
    [navBar setViewTitle:LOCALIZED_STRING(@"AR.DRONE UPDATE")];
    [navBar displayHomeButton];
    [navBar.leftButton addTarget:self action:@selector(goBack) forControlEvents:UIControlEventTouchUpInside];
    
    NSString *plistPath = [[NSBundle mainBundle] pathForResource:@"Firmware" ofType:@"plist"];
	NSDictionary *plistDict = [NSDictionary dictionaryWithContentsOfFile:plistPath];
	self.firmwareFileName = [plistDict objectForKey:@"FirmwareFileName"];
    self.firmwarePath = nil;
    self.droneFirmwareVersion = [NSString stringWithCString:&controller.ardrone_info->drone_version[0] encoding:NSUTF8StringEncoding];
	self.repairFileName = [plistDict objectForKey:@"RepairFileName"];
	self.bootldrFileName = [plistDict objectForKey:@"BootldrFileName"];
	self.repairVersion = [plistDict objectForKey:@"RepairVersion"];
	self.repairPath = [[NSBundle mainBundle] pathForResource:repairFileName ofType:@"bin"];
	self.bootldrPath = [[NSBundle mainBundle] pathForResource:bootldrFileName ofType:@"bin"];

    progressBar.hidden = YES;
    updateRetryCount = 0;
	
    [repairingLabel setText:UPDATER_LOCALIZED_UPPER_STRING(@"Checking / Repairing")];
    [repairingLabel setAlpha:ALPHA_PASS];
    [self updateStepImage:STEP_IMAGE_EMPTY toImageView:repairingImageView];
    [sendingFileLabel setText:UPDATER_LOCALIZED_UPPER_STRING(@"Sending file")];
    [sendingFileLabel setAlpha:ALPHA_PASS];
    [self updateStepImage:STEP_IMAGE_EMPTY toImageView:sendingFileImageView];

    NSArray *components = [droneFirmwareVersion componentsSeparatedByString:@"."];
    if(NSOrderedSame != [(NSString *)[components objectAtIndex:0] compare:@"1" options:NSNumericSearch])
    {
        [restartingLabel setText:UPDATER_LOCALIZED_UPPER_STRING(@"Restarting the AR.Drone")];
    }
    else
    {
        [restartingLabel setText:UPDATER_LOCALIZED_UPPER_STRING(@"Please restart the AR.Drone")];
    }

    [restartingLabel setAlpha:ALPHA_PASS];
    [self updateStepImage:STEP_IMAGE_EMPTY toImageView:restartingImageView];
    [installingLabel setText:UPDATER_LOCALIZED_UPPER_STRING(@"Installing")];
    [installingLabel setAlpha:ALPHA_PASS];
    [self updateStepImage:STEP_IMAGE_EMPTY toImageView:installingImageView];
    
	self.fsm = [FiniteStateMachine fsmWithXML:[[NSBundle mainBundle] pathForResource:@"updater_fsm" ofType:@"xml"]];
	fsm.delegate = self;
    [self performSelectorInBackground:@selector(startFsm) withObject:nil];
}

- (void)startFsm
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    fsm.currentState = U_STATE_REPAIR;
    [pool drain];
}

- (void)didReceiveMemoryWarning
{
	[super didReceiveMemoryWarning];
}

- (void)dealloc
{
    [self.repairFtp close];
	self.repairFtp = nil;
    [self.ftp close];
	self.ftp = nil;

	self.firmwarePath = nil;
	self.firmwareFileName = nil;
	self.firmwareVersion = nil;
	self.droneFirmwareVersion = nil;
	self.repairPath = nil;
	self.repairFileName = nil;
	self.repairVersion = nil;
	self.bootldrPath = nil;
	self.bootldrFileName = nil;
	self.documentPath = nil;
	self.fsm = nil;
    
	[super dealloc];
}

// NSURLConnection needed to ping the ARDrone before creating the FTP.
- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
	[connection release];
	
	if ([self.ftp keepConnexionAlive])
		[fsm doAction:U_ACTION_SUCCESS];
	else
    {
        [self.ftp close];
        [self.repairFtp close];
		[fsm doAction:U_ACTION_FAIL];
    }
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
	[connection release];
    
	[self.ftp close];
    [self.repairFtp close];
	[fsm doAction:U_ACTION_FAIL];
}

- (void)executeCommandOut:(ARDRONE_COMMAND_OUT)commandId withParameter:(void*)parameter fromSender:(id)sender
{
	// Nothing here but needs to be implemented
}

// Updates the display with the FSM object.
- (void) updateStatusLabel
{    
	NSString *key = [(NSString *)fsm.currentObject stringByReplacingOccurrencesOfString:@"\\n" withString:@"\n"];

	switch (fsm.currentState)
	{                        
        case U_STATE_NOT_UPDATED:
			status2Label.text = [NSString stringWithFormat:UPDATER_LOCALIZED_STRING(key), [[UIDevice currentDevice] model]];
			break;
		default:
			status2Label.text = UPDATER_LOCALIZED_STRING(key);
			break;
	}
}

- (void) updateStepImage:(eSTEP_IMAGE)step toImageView:(UIImageView *)imageView 
{
	switch (step)
	{
		case STEP_IMAGE_PASS:
             [imageView setImage:[UIImage imageNamed:@"ff2.0_updater_ok.png"]];
			break;
			
		case STEP_IMAGE_PROGRESS:
            [imageView setImage:[UIImage imageNamed:@"ff2.0_updater_in_progress.png"]];
			break;
			
		case STEP_IMAGE_FAIL:
            [imageView setImage:[UIImage imageNamed:@"ff2.0_updater_ko.png"]];
			break;
        
        case STEP_IMAGE_EMPTY:
		case STEP_IMAGE_MAX:
            [imageView setImage:[UIImage imageNamed:@"ff2.0_updater_empty.png"]];
			break;
			
		default:
			break;
	}
}

- (BOOL) rebootARDrone
{
    int socket_desc;
	struct sockaddr_in address;
	
	socket_desc=socket(AF_INET,SOCK_STREAM,0);
	if (socket_desc>-1)
	{
		char buffer[1024];
		int size;
		printf("Socket created (ip: %s)\n", &controller.ardrone_info->drone_address[0]);
		
		/* type of socket created in socket() */
		address.sin_family = AF_INET;
		address.sin_addr.s_addr = inet_addr(&controller.ardrone_info->drone_address[0]);
		
		/* TELNET_PORT is the port to use for connections */
		address.sin_port = htons(TELNET_PORT);
		/* connect the socket to the port specified above */
		connect(socket_desc, (struct sockaddr *)&address, sizeof(struct sockaddr));
		
		// Launch reboot command 
		sprintf(buffer, "reboot\n");
		size = send(socket_desc, buffer, strlen(buffer), 0);
		if(size != strlen(buffer))
		{
			printf("Can't reboot ...\n");
			return NO;
		}
				
		close(socket_desc);
	}
	else
	{
		perror("Can't create socket");
		return NO;
	}
	
	return YES;
}

/*
 * Repair State:
 *
 *
 */
- (BOOL) repair
{
	int socket_desc;
	struct sockaddr_in address;
	
	socket_desc=socket(AF_INET,SOCK_STREAM,0);
	if (socket_desc>-1)
	{
		char buffer[1024];
		int size;
		printf("Socket created (ip: %s)\n", &controller.ardrone_info->drone_address[0]);
		
		/* type of socket created in socket() */
		address.sin_family = AF_INET;
		address.sin_addr.s_addr = inet_addr(&controller.ardrone_info->drone_address[0]);
		
		/* TELNET_PORT is the port to use for connections */
		address.sin_port = htons(TELNET_PORT);
		/* connect the socket to the port specified above */
		connect(socket_desc, (struct sockaddr *)&address, sizeof(struct sockaddr));
		
		// Change access right to XR 
		sprintf(buffer, "cd `find /data -name \"repair\" -exec dirname {} \\;` && chmod 755 repair\n");
		size = send(socket_desc, buffer, strlen(buffer), 0);
		if(size != strlen(buffer))
		{
			printf("Cannot change access right ...\n");
			return NO;
		}
		
		// execute repair binary file 
		sprintf(buffer, "cd `find /data -name \"repair\" -exec dirname {} \\;` && ./repair\n");
		size = send(socket_desc, buffer, strlen(buffer), 0);
		if(size != strlen(buffer))
		{
			printf("Cannot execute binary to repair AR.Drone ...\n");
			return NO;
		}
		
		close(socket_desc);
	}
	else
	{
		perror("Can't create socket");
		return NO;
	}
	
	return YES;
}

// Called back when repair is needed:
- (void)repairFileCallback:(ARDroneFTPCallbackArg *)arg
{
	
	U_ASSERT(fsm.currentState, U_STATE_REPAIR)
	U_ASSERT(arg.operation, FTP_SEND)
	
	if (ARDFTP_FAILED(arg.status))
	{
        
        if(ARDFTP_ABORT == arg.status)
        {
            [self performSelectorOnMainThread:@selector(exit) withObject:nil waitUntilDone:NO];
        }
        else
        {
            ++updateRetryCount;
            
            if (MAX_RETRIES <= updateRetryCount)
            {
                [self.ftp close];
                [self.repairFtp close];
                [fsm doAction:H_ACTION_FAIL];
                return;
            }
            
            [repairFtp sendLocalFile:repairPath toDistantFile:repairFileName withResume:YES withCallback:@selector(repairFileCallback:)];
        }
        
		return;
	}
	
	if (!ARDFTP_SUCCEEDED(arg.status))
		return;
	
	self.repairFtp = nil;
	
	if ([self repair])
    {
		[fsm doAction:H_ACTION_SUCCESS];
    }
	else
    {
        [self.ftp close];
        [self.repairFtp close];
		[fsm doAction:H_ACTION_FAIL];
    }
}

// Called back when bootldr is needed:
- (void)bootldrFileCallback:(ARDroneFTPCallbackArg *)arg
{    
	U_ASSERT(fsm.currentState, U_STATE_REPAIR)
	U_ASSERT(arg.operation, FTP_SEND)
	
	if (ARDFTP_FAILED(arg.status))
	{
        if(ARDFTP_ABORT == arg.status)
        {
            [self performSelectorOnMainThread:@selector(exit) withObject:nil waitUntilDone:NO];
        }
        else
        {
            ++updateRetryCount;
            
            if (MAX_RETRIES <= updateRetryCount)
            {
                [self.ftp close];
                [self.repairFtp close];
                [fsm doAction:H_ACTION_FAIL];
                return;
            }
            
            [repairFtp sendLocalFile:bootldrPath toDistantFile:[NSString stringWithFormat:@"%@.bin", bootldrFileName] withResume:YES withCallback:@selector(bootldrFileCallback:)];
        }
		
		return;
	}
	
	if (!ARDFTP_SUCCEEDED(arg.status))
		return;
	
	[repairFtp sendLocalFile:repairPath toDistantFile:repairFileName withResume:NO withCallback:@selector(repairFileCallback:)];
}

// Checks drone version:
- (void)checkRepairVersion
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    switch ([droneFirmwareVersion compare:repairVersion options:NSNumericSearch])
    {
        case NSOrderedAscending:
            self.repairFtp = [ARDroneFTP anonymousStandardFTPwithDelegate:self withDefaultCallback:nil];
        
            [repairFtp sendLocalFile:bootldrPath toDistantFile:[NSString stringWithFormat:@"%@.bin", bootldrFileName] withResume:NO withCallback:@selector(bootldrFileCallback:)];
        
            break;
        
        default:
            [fsm doAction:H_ACTION_SUCCESS];
            break;
    }
    [pool drain];
}

// Enter
- (void)enterRepair:(id)_fsm
{
    updateRetryCount = 0;
    dispatch_async(dispatch_get_main_queue(), ^(void)
    {
        [statusLabel setText:UPDATER_LOCALIZED_UPPER_STRING(@"Checking / Repairing")];   
        [sendingFileLabel setAlpha:ALPHA_IN_PROGRESS];
        [self updateStepImage:STEP_IMAGE_PROGRESS toImageView:repairingImageView];
        [self updateStatusLabel];
    });
	[self performSelectorInBackground:@selector(checkRepairVersion) withObject:nil];
}

// Quit
- (void)quitRepair:(id)_fsm
{
    dispatch_async(dispatch_get_main_queue(), ^(void)
    {
        [sendingFileLabel setAlpha:ALPHA_PASS];
        [self updateStepImage:STEP_IMAGE_PASS toImageView:repairingImageView];
        [self updateStatusLabel];
    });
}

// Enter
- (void)enterNotRepaired:(id)_fsm
{
    dispatch_async(dispatch_get_main_queue(), ^(void)
    {
        [self updateStepImage:STEP_IMAGE_FAIL toImageView:repairingImageView];
        [repairingLabel setTextColor:[UIColor redColor]];
        [self updateStatusLabel];
    });
}

/*
 * Update Firmware State:
 *
 *
 */
// Send Progress View can only be updated on Main Thread
- (void)updateSendProgressView:(NSNumber *)progress
{
	progressBar.progress = [progress floatValue];
}

// Called back when file sending is in progress.
- (void)sendFileCallback:(ARDroneFTPCallbackArg *)arg
{
	U_ASSERT(fsm.currentState, U_STATE_UPDATE_FIRMWARE)
	U_ASSERT(arg.operation, FTP_SEND)
	
	if (ARDFTP_FAILED(arg.status))
	{
        if(ARDFTP_ABORT == arg.status)
        {
            [self performSelectorOnMainThread:@selector(exit) withObject:nil waitUntilDone:NO];
        }
        else
        {
            ++updateRetryCount;
            
            if (MAX_RETRIES <= updateRetryCount)
            {
                [self.ftp close];
                [self.repairFtp close];
                [fsm doAction:U_ACTION_FAIL];
                return;
            }
            
            [self.ftp sendLocalFile:firmwarePath toDistantFile:[firmwarePath lastPathComponent] withResume:YES withCallback:@selector(sendFileCallback:)];
        }
        
        return;
	}
	
	[self performSelectorOnMainThread:@selector(updateSendProgressView:) withObject:[NSNumber numberWithFloat:arg.progress/100.f] waitUntilDone:NO];
	
	if (!ARDFTP_SUCCEEDED(arg.status))
		return;
	
	[fsm doAction:U_ACTION_SUCCESS];
}

// Called back when drone version is found:
- (void)enterUpdateFirmwareVersionTxtCallback:(ARDroneFTPCallbackArg *)arg
{	
	U_ASSERT(fsm.currentState, U_STATE_UPDATE_FIRMWARE)
	U_ASSERT(arg.operation, FTP_GET)
	
	NSString *path = [NSString stringWithFormat:@"%@/%@", documentPath, VERSION_TXT];
	
	if (ARDFTP_FAILED(arg.status))
	{
        if(ARDFTP_ABORT == arg.status)
        {
            [self performSelectorOnMainThread:@selector(exit) withObject:nil waitUntilDone:NO];
        }
        else
        {
            
            updateRetryCount++;
            
            if (MAX_RETRIES <= updateRetryCount)
            {
                [self.ftp close];
                [self.repairFtp close];
                [fsm doAction:U_ACTION_FAIL];
                return;
            }
            
            [self.ftp getDistantFile:VERSION_TXT toLocalFile:path withResume:YES withCallback:@selector(enterUpdateFirmwareVersionTxtCallback:)];
        }
		
        return;
	}
	
	if (!ARDFTP_SUCCEEDED(arg.status))
		return;
	
    NSError *error = nil;
	self.droneFirmwareVersion = [[NSString stringWithContentsOfFile:path encoding:NSASCIIStringEncoding error:&error] stringByReplacingOccurrencesOfString:@"\n" withString:@""];

    NSArray *components = [droneFirmwareVersion componentsSeparatedByString:@"."];
    if(NSOrderedSame == [(NSString *)[components objectAtIndex:0] compare:@"1" options:NSNumericSearch])
    {
        self.firmwarePath = [[NSBundle mainBundle] pathForResource:[NSString stringWithFormat:firmwareFileName, @""] ofType:@"plf"];
    }
    else
    {
        self.firmwarePath = [[NSBundle mainBundle] pathForResource:[NSString stringWithFormat:firmwareFileName, (NSString *)[components objectAtIndex:0]] ofType:@"plf"];
    }
    
    plf_phdr plf_header;
    
    if(plf_get_header([self.firmwarePath cStringUsingEncoding:NSUTF8StringEncoding], &plf_header) != 0)
        memset(&plf_header, 0, sizeof(plf_phdr));
    
    self.firmwareVersion = [NSString stringWithFormat:@"%d.%d.%d", plf_header.p_ver, plf_header.p_edit, plf_header.p_ext];
    
    [self.ftp sendLocalFile:firmwarePath toDistantFile:[firmwarePath lastPathComponent] withResume:!first_time withCallback:@selector(sendFileCallback:)];
    first_time = NO;
}

// Enter
- (void)enterUpdateFirmware:(id)_fsm
{
    updateRetryCount = 0;
    dispatch_async(dispatch_get_main_queue(), ^(void) 
    {
        [statusLabel setText:UPDATER_LOCALIZED_UPPER_STRING(@"Sending file")];
        [sendingFileLabel setAlpha:ALPHA_IN_PROGRESS];
        [self updateStatusLabel];
        [self updateStepImage:STEP_IMAGE_PROGRESS toImageView:sendingFileImageView];
        progressBar.hidden = NO;
        progressBar.progress = 0.f;
    });
    self.ftp = [ARDroneFTP anonymousUpdateFTPwithDelegate:self withDefaultCallback:nil];
    
    NSString *path = [NSString stringWithFormat:@"%@/%@", documentPath, VERSION_TXT];
	
	NSError *error = nil;
	
	if ([[NSFileManager defaultManager] fileExistsAtPath:path])
		[[NSFileManager defaultManager] removeItemAtPath:path error:&error];
	
	[self.ftp getDistantFile:VERSION_TXT toLocalFile:path withResume:NO withCallback:@selector(enterUpdateFirmwareVersionTxtCallback:)];
}

// Quit
- (void)quitUpdateFirmware:(id)_fsm
{
    dispatch_async(dispatch_get_main_queue(), ^(void)
    {
        [sendingFileLabel setAlpha:ALPHA_PASS];
        [self updateStepImage:STEP_IMAGE_PASS toImageView:sendingFileImageView];
        progressBar.hidden = YES;
    });
}

/*
 * Not Updated State:
 *
 *
 */
// Enter
- (void)enterNotUpdated:(id)_fsm
{
    dispatch_async(dispatch_get_main_queue(), ^(void)
    {
        [self updateStatusLabel];
        [self updateStepImage:STEP_IMAGE_FAIL toImageView:sendingFileImageView];
        [sendingFileLabel setTextColor:[UIColor redColor]];
    });
}

/*
 * Restart Drone State:
 *
 *
 */
// Checks if the drone is powered off
- (void)checkDroneRestarted
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    U_ASSERT(fsm.currentState, U_STATE_RESTART_DRONE)
	
    if ([self.ftp keepConnexionAlive])
    {
        [NSThread sleepForTimeInterval:1.0];
        [self performSelectorInBackground:@selector(checkDroneRestarted) withObject:nil];    }
    else
    {
        [self.ftp close];
        [self.repairFtp close];
        [fsm doAction:U_ACTION_SUCCESS];
    }
    [pool drain];
}

// Enter
- (void)enterRestartDrone:(id)_fsm
{
    updateRetryCount = 0;
    dispatch_async(dispatch_get_main_queue(), ^(void)
    {
        [statusLabel setText:UPDATER_LOCALIZED_UPPER_STRING(@"Restarting the AR.Drone")];
        [restartingLabel setAlpha:ALPHA_IN_PROGRESS];
        [self updateStatusLabel];
        [self updateStepImage:STEP_IMAGE_PROGRESS toImageView:restartingImageView];
    });
	
    NSArray *components = [droneFirmwareVersion componentsSeparatedByString:@"."];
    if(NSOrderedSame != [(NSString *)[components objectAtIndex:0] compare:@"1" options:NSNumericSearch])
    {
        [NSThread sleepForTimeInterval:1.0];
        if([self rebootARDrone])
    {
        // If drone version not drone 1 and rebootARDrone is ok
		[fsm doAction:H_ACTION_SUCCESS];
        }
        else
        {
            [self performSelectorInBackground:@selector(checkDroneRestarted) withObject:nil];
        }
    }
    else
    {
        [self performSelectorInBackground:@selector(checkDroneRestarted) withObject:nil];
    }
}

// Quit
- (void)quitRestartDrone:(id)_fsm
{
    dispatch_async(dispatch_get_main_queue(), ^(void)
    {
        [restartingLabel setAlpha:ALPHA_PASS];
        [self updateStepImage:STEP_IMAGE_PASS toImageView:restartingImageView];
    });
}

/*
 * Installing Firmware State:
 *
 *
 */
// Enter
- (void)enterInstallingFirmware:(id)_fsm
{
    updateRetryCount = 0;
    dispatch_async(dispatch_get_main_queue(), ^(void)
    {    
        [statusLabel setText:UPDATER_LOCALIZED_UPPER_STRING(@"Installing")];
        [installingLabel setAlpha:ALPHA_IN_PROGRESS];
        [self updateStatusLabel];
        [self updateStepImage:STEP_IMAGE_PROGRESS toImageView:installingImageView];
    });
}

// Quit
- (void)quitInstallingFirmware:(id)_fsm
{
    dispatch_async(dispatch_get_main_queue(), ^(void)
    {
        [installingLabel setAlpha:ALPHA_PASS];
        [self updateStepImage:STEP_IMAGE_PASS toImageView:restartingImageView];
    });
}

- (void)exit
{
    [controller doAction:MENU_FF_ACTION_JUMP_TO_HOME];
}

- (void)goBack
{
    if(ARDFTP_SUCCESS != [self.ftp abortCurrentOperation])
    {
        [self exit];
    }
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // Return YES for supported orientations
    return UIInterfaceOrientationIsLandscape(interfaceOrientation);
}

#pragma mark ARStatusBarDelegate
- (void)statusBarPreferencesClicked:(ARStatusBarViewController *)bar
{
    MenuPreferences *menuPreferences = [[MenuPreferences alloc] initWithController:controller];
    [self.navigationController pushViewController:menuPreferences animated:NO];
    [menuPreferences release];
}

@end
