//
//  MenuController.m
//  ArDroneGameLib
//
//  Created by Clément Choquereau on 5/4/11.
//  Copyright 2011 Parrot. All rights reserved.
//

#import "MenuController.h"

#import "ARDrone.h"
#import "FiniteStateMachine.h"

@interface MenuController()

- (void) enterState:(id)state;
- (void) quitState:(id)state;
@end

@implementation MenuController

@synthesize fsm;
@synthesize drone;
@synthesize delegate;
@synthesize ardrone_info;

- (void)viewDidLoad
{
	[super viewDidLoad];
    
	currentMenu = nil;
	ardrone_info = NULL;
    
	self.fsm = [FiniteStateMachine fsmWithXML:[[NSBundle mainBundle] pathForResource:@"menus_fsm" ofType:@"xml"]];
    fsm.currentState = MENU_FF_STATE_HOME;
    [[ARDroneAcademy sharedInstance] setDelegate:self];
}

- (void) dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
	// Release the current menu
    if (currentMenu)
	{
		[currentMenu.view removeFromSuperview];
		[currentMenu release];
		currentMenu = nil;
	}
	
    [fsm release];
    fsm = nil;
    
	[super dealloc];
}

/*
 * Finite State Machine setter
 *
 * 
 */
- (void)setFsm:(FiniteStateMachine *)_fsm
{
    [_fsm retain];
    [fsm release];
    fsm = _fsm;
    
    [fsm setDelegate:self];
    
    unsigned int n = fsm.statesCount;
    
    for (unsigned int state = 0 ; state < n ; state++)
    {
        [fsm setEnterStateCallback:@selector(enterState:) forState:state];
        [fsm setQuitStateCallback:@selector(quitState:) forState:state];
    }
}

/*
 * enterState
 *
 * 
 */
- (void) enterState:(id)_fsm
{
	if (![fsm currentObject])
		return;
	
	NSString *object = [fsm currentObject];
	
	if ([object compare:FSM_HUD] == NSOrderedSame)
	{
		[delegate changeState:YES];
		[self changeState:YES];
		
		return;
	}
	
    NSArray *components = [object componentsSeparatedByString:@":"];
	if(([components count] > 1) && ([(NSString *)[components objectAtIndex:0] isEqualToString:FSM_NAVIGATION_CONTROLLER]))
    {
        Class menuClass = NSClassFromString((NSString *)[components objectAtIndex:1]);

        currentMenu = [(UIViewController<MenuProtocol> *)[menuClass alloc] initWithController:self];
        UINavigationController *navigationController = [[UINavigationController alloc] initWithRootViewController:currentMenu];
        [navigationController.navigationBar setBarStyle:UIBarStyleBlackTranslucent];    
        [currentMenu release];
        [self presentModalViewController:navigationController animated:NO];
        [navigationController release];
        navigationController = nil;
    }
    else
    {
        Class menuClass = NSClassFromString(object);
        currentMenu = [(UIViewController<MenuProtocol> *)[menuClass alloc] initWithController:self];
        if (![delegate checkState])
            [self.view addSubview:currentMenu.view];
    }
}

/*
 * quitState
 *
 * 
 */
- (void) quitState:(id)_fsm
{
	NSString *object = nil;
	
	if (fsm)
		object = [fsm currentObject];
	
	if ( (object) && ([object compare:FSM_HUD] == NSOrderedSame) )
	{
		[self changeState:NO];
		[delegate changeState:NO];
		
		return;
	}
    
	if([object hasPrefix:FSM_NAVIGATION_CONTROLLER])
    {
        [currentMenu.navigationController dismissModalViewControllerAnimated:NO];
    }
    else 
    {
        [currentMenu.view removeFromSuperview];
        [currentMenu release];
        currentMenu = nil;
    }
}

/*
 * doAction
 *
 * 
 */
- (void)doAction:(unsigned int)action
{
    if (!fsm)
        return;
    
    [fsm doAction:action];
}

/*
 * currentState
 *
 *
 */
- (unsigned int)currentState
{
	if (!fsm)
		return NO_STATE;
	
	return [fsm currentState];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation 
{	
	if([delegate checkState] == NO)
		return UIInterfaceOrientationIsLandscape(interfaceOrientation);
	else
		return FALSE;
}

// ARDrone protocols:
// ProtocolIn
- (void)changeState:(BOOL)inGame
{
	if(!inGame)
	{
        // If not in game, the MenuController removes the drone view, and adds a menu view.
		if (drone)
			[drone.view removeFromSuperview];
        
		if (currentMenu)
			[self.view addSubview:currentMenu.view];
	}
	else
	{
        // If in game, the MenuController removes the active menu view, and adds the drone view.
		if (currentMenu)
			[currentMenu.view removeFromSuperview];
		
		if (drone)
			[self.view addSubview:drone.view];
	}
}

- (void)ARDroneAcademyDidRespond:(ARDroneAcademy *)ARDroneAcademy
{
    //static int32_t time_to_process = 0;
    switch (ARDroneAcademy.result)
    {
        case ARDRONE_ACADEMY_RESULT_NONE:
            break;
            
        case ARDRONE_ACADEMY_RESULT_OK:
            /*printf("Synchronizing\n");
            time_to_process += ARDroneAcademy.time_in_ms;
            if (ARDroneAcademy.state == ARDRONE_ACADEMY_STATE_DRONE_DISCONNECTION)
            {
                printf("Synchronizing in %d ms\n", time_to_process);
                time_to_process = 0;
            }*/
            break;
            
        case ARDRONE_ACADEMY_RESULT_FAILED:
            /*if (ARDroneAcademy.state == ARDRONE_ACADEMY_STATE_DRONE_PREPARE_DOWNLOAD)
                time_to_process = 0;*/
            break;
    }
}

- (void) executeCommandIn:(ARDRONE_COMMAND_IN_WITH_PARAM)commandIn fromSender:(id)sender refreshSettings:(BOOL)refresh
{
}

- (void)executeCommandIn:(ARDRONE_COMMAND_IN)commandId withParameter:(void *)parameter fromSender:(id)sender
{
}

- (BOOL)checkState
{
	return YES;
}

- (void)setDefaultConfigurationForKey:(ARDRONE_CONFIG_KEYS)key withValue:(void *)value
{
    
}

// ProtocolOut
- (void)executeCommandOut:(ARDRONE_COMMAND_OUT)commandId withParameter:(void *)parameter fromSender:(id)sender
{
    switch(commandId)
	{
		case ARDRONE_COMMAND_RUN:
            ardrone_info = (ardrone_info_t*)parameter; 
			break;
            
        case ARDRONE_COMMAND_PAUSE:
            ardrone_info = (ardrone_info_t*)parameter; 
            [fsm doAction:MENU_FF_ACTION_JUMP_TO_HOME];
            break;
            
		default:
			break;
	}
    
	if ((currentMenu) && [currentMenu respondsToSelector:@selector(executeCommandOut:withParameter:fromSender:)])
		[currentMenu executeCommandOut:commandId withParameter:parameter fromSender:sender];
}

-(BOOL)shouldAutorotate
{
    if (currentMenu)
        return YES;
    else
        return NO;
}

-(NSInteger)supportedInterfaceOrientations{
    return UIInterfaceOrientationMaskLandscape;

}

@end
