//
//  MainViewController.h
//  ARDroneEngine
//
//  Created by Mykonos on 17/12/09.
//  Copyright 2009 Parrot SA. All rights reserved.
//

#include "ConstantsAndMacros.h"
#import "HUD.h"
#import "SettingsMenu.h"
#import "ARDrone.h"
#import "ARDroneProtocols.h"
#import "InternalProtocols.h"

@interface MainViewController : UIViewController
{
@private
	/**
	 * Id of Game engine implementing protocol 
	 */
	id<ARDroneProtocolOut> gameEngine;
	
	HUD			 *hud;
	SettingsMenu *menuSettings;
}

@property (nonatomic, assign) BOOL wifiReachabled;

- (id) initWithFrame:(CGRect)frame withState:(BOOL)inGame withDelegate:(id<ARDroneProtocolOut>)delegate withNavdataDelegate:(id<NavdataProtocol>)_navdata_delegate withHUDConfiguration:(ARDroneHUDConfiguration*)hudconfiguration;
- (void)setScreenOrientationRight:(BOOL)right;
- (ARDroneEnemiesData*)humanEnemiesData;
- (ARDroneNavigationData*)navigationData;
- (ARDroneCamera*)droneCamera;
- (ARDroneDetectionCamera*)detectionCamera;
- (void)changeState:(BOOL)inGame;
- (void)executeCommandIn:(ARDRONE_COMMAND_IN_WITH_PARAM)commandIn fromSender:(id)sender refreshSettings:(BOOL)refresh;
- (void)executeCommandIn:(ARDRONE_COMMAND_IN)commandId withParameter:(void*)parameter fromSender:(id)sender;
- (void)setDefaultConfigurationForKey:(ARDRONE_CONFIG_KEYS)key withValue:(void *)value;


+ (void)initDefaultConfig;
+ (void)getConfiguration;
+ (void)setGPSInfo:(gps_info_t)gps_info;
@end
