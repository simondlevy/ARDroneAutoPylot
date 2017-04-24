//
//  MenuUpdater.h
//  Updater
//
//  Created by Clément Choquereau / Nicolas Payot on 10-05-14.
//  Copyright Playsoft 2010. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "MenuController.h"
#import "ARUtils.h"

#import "ARDroneFTP.h"
#import "FiniteStateMachine.h"

#define UPDATER_LOCALIZED_STRING(key) [[NSBundle mainBundle] localizedStringForKey:(key) value:@"" table:@"updater"]
#define UPDATER_LOCALIZED_UPPER_STRING(key) [[[NSBundle mainBundle] localizedStringForKey:(key) value:@"" table:@"updater"] uppercaseString]

enum
{
	U_STATE_REPAIR,
	U_STATE_NOT_REPAIRED,
	U_STATE_UPDATE_FIRMWARE,
	U_STATE_NOT_UPDATED,
	U_STATE_RESTART_DRONE,
	U_STATE_INSTALLING_FIRMWARE,
	U_STATES_COUNT
};

enum
{
	U_ACTION_FAIL,
	U_ACTION_SUCCESS,
	U_ACTIONS_COUNT
};

enum
{
	U_STEP_SEND,
	U_STEP_RESTART,
	U_STEP_INSTALL,
	U_STEPS_COUNT
};

@interface MenuUpdater : ARNavigationController <ARStatusBarDelegate, MenuProtocol>
{
    ARNavigationBarViewController *navBar;
    ARStatusBarViewController *statusBar;
    
	IBOutlet UILabel *statusLabel;
	IBOutlet UILabel *status2Label;

    IBOutlet ARProgressView *progressBar;
    
    IBOutlet UILabel *repairingLabel;
    IBOutlet UIImageView *repairingImageView;

    IBOutlet UILabel *sendingFileLabel;
    IBOutlet UIImageView *sendingFileImageView;
    
    IBOutlet UILabel *restartingLabel;
    IBOutlet UIImageView *restartingImageView;

    IBOutlet UILabel *installingLabel;
    IBOutlet UIImageView *installingImageView;
    
	NSString *firmwarePath;
	NSString *firmwareFileName;
	NSString *firmwareVersion;
	NSString *repairPath;
	NSString *repairFileName;
	NSString *repairVersion;
	NSString *bootldrPath;
	NSString *bootldrFileName;
	NSString *droneFirmwareVersion;
    
    ARDroneFTP *repairFtp;
    ARDroneFTP *ftp;
    
    int updateRetryCount;
	
	FiniteStateMachine *fsm;
    
    NSString *documentPath;
}

@property (nonatomic, copy) NSString *firmwarePath;
@property (nonatomic, copy) NSString *firmwareFileName;
@property (nonatomic, copy) NSString *firmwareVersion;
@property (nonatomic, copy) NSString *repairPath;
@property (nonatomic, copy) NSString *repairFileName;
@property (nonatomic, copy) NSString *repairVersion;
@property (nonatomic, copy) NSString *bootldrPath;
@property (nonatomic, copy) NSString *bootldrFileName;
@property (nonatomic, copy) NSString *droneFirmwareVersion;
@property (nonatomic, copy) NSString *documentPath;

@property (nonatomic, retain) ARDroneFTP *ftp;
@property (nonatomic, retain) ARDroneFTP *repairFtp;
@property (nonatomic, retain) FiniteStateMachine *fsm;

// Launch FSM
- (void)startFsm;

// Repair:
- (void)enterRepair:(id)_fsm;
- (void)quitRepair:(id)_fsm;

// Not Repaired:
- (void)enterNotRepaired:(id)_fsm;

// Update Firmware:
- (void)enterUpdateFirmware:(id)_fsm;
- (void)quitUpdateFirmware:(id)_fsm;

// Not Updated:
- (void)enterNotUpdated:(id)_fsm;

// Restart Drone:
- (void)enterRestartDrone:(id)_fsm;
- (void)quitRestartDrone:(id)_fsm;

// Installing Firmware:
- (void)enterInstallingFirmware:(id)_fsm;
- (void)quitInstallingFirmware:(id)_fsm;

@end
