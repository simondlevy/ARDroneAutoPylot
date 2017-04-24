//
//  MenuController.h
//  ArDroneGameLib
//
//  Created by Clément Choquereau on 5/4/11.
//  Copyright 2011 Parrot. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "ARDroneProtocols.h"
#import "ARDroneAcademy.h"
#import "ARDroneMediaManager.h"
#import "Common.h"

// States & Actions:

#define FSM_HUD @"hud"
#define FSM_NAVIGATION_CONTROLLER @"nav"

enum
{
    MENU_FF_STATE_HOME,
    MENU_FF_STATE_HUD,
    MENU_FF_STATE_GUEST_SPACE,
    MENU_FF_STATE_UPDATER,
    MENU_AA_NAVIGATION_CONTROLLER,
    MENU_FF_STATE_GAMES,
    MENU_FF_STATE_MEDIA,
    MENU_FF_STATE_SETTINGS,
	MENU_STATES_COUNT
};

enum
{
    MENU_FF_ACTION_JUMP_TO_HUD,             
    MENU_FF_ACTION_JUMP_TO_GUEST_SPACE,     
    MENU_FF_ACTION_JUMP_TO_UPDATER,         
    MENU_FF_ACTION_JUMP_TO_ARDRONE_ACADEMY, 
    MENU_FF_ACTION_JUMP_TO_GAMES,           
    MENU_FF_ACTION_JUMP_TO_MEDIA,
    MENU_FF_ACTION_JUMP_TO_PREFERENCES,
    MENU_FF_ACTION_JUMP_TO_HOME,            
	MENU_FF_ACTIONS_COUNT
};

@class MenuController;

@protocol MenuProtocol <ARDroneProtocolOut>

- (id)initWithController:(MenuController *)menuController;

@end

@class FiniteStateMachine;
@class ARDrone;

@interface MenuController : UIViewController <ARDroneProtocolIn, ARDroneProtocolOut, ARDroneAcademyDelegate>
{
	UIViewController <MenuProtocol> *currentMenu;
	
	ARDrone							*drone;
	id<ARDroneProtocolIn>			delegate;
    
    FiniteStateMachine              *fsm;
    
    ardrone_info_t                  *ardrone_info;
}

/*
 * Set a FSM with UIViewController<MenuProtocol> Class String (see NSStringFromClass) as object attached to each state.
 * Entering a state will allocate and initialize this Class.
 * Quitting a state will release the previously allocated object.
 *
 * You can then use [MenuController doAction:] to communicate with the FSM.
 *
 * /!\ The MenuController will set the FSM delegate to itself.
 */
@property (nonatomic, retain) FiniteStateMachine *fsm;

- (void)doAction:(unsigned int)action;

@property (readonly) unsigned int currentState;

@property (nonatomic, assign) ARDrone *drone;
@property (nonatomic, assign) id<ARDroneProtocolIn> delegate;

@property ardrone_info_t *ardrone_info;

@end
