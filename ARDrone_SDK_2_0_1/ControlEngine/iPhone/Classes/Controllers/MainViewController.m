//
//  MainViewController.m
//  ARDroneEngine
//
//  Created by Mykonos on 17/12/09.
//  Copyright 2009 Parrot SA. All rights reserved.
//
#import "MainViewController.h"
#import "ARDroneMediaManager.h"
#import "utils/ardrone_video_encapsuler.h"
#import "ardrone_tool/Academy/academy_download.h"
#import "utils/ardrone_time.h"

typedef enum _ERROR_STATE_
{
	ERROR_STATE_NONE,
	ERROR_STATE_NAVDATA_CONNECTION,
	ERROR_STATE_START_NOT_RECEIVED,
	ERROR_STATE_EMERGENCY_CUTOUT,
	ERROR_STATE_EMERGENCY_MOTORS,
	ERROR_STATE_EMERGENCY_CAMERA,
	ERROR_STATE_EMERGENCY_PIC_WATCHDOG,
	ERROR_STATE_EMERGENCY_PIC_VERSION,
	ERROR_STATE_EMERGENCY_ANGLE_OUT_OF_RANGE,
	ERROR_STATE_EMERGENCY_VBAT_LOW,
	ERROR_STATE_EMERGENCY_USER_EL,
	ERROR_STATE_EMERGENCY_ULTRASOUND,
	ERROR_STATE_EMERGENCY_UNKNOWN,
	ERROR_STATE_ALERT_CAMERA,
	ERROR_STATE_ALERT_VBAT_LOW,
	ERROR_STATE_ALERT_ULTRASOUND,
	ERROR_STATE_ALERT_VISION,
	ERROR_STATE_MAX
} ERROR_STATE;

extern ControlData ctrldata;

static gps_info_t   gpsInfo = { 0 };
static CONFIG_STATE gpsState = CONFIG_STATE_IDLE;
static CONFIG_STATE configurationState = CONFIG_STATE_IDLE;
static ardrone_timer_t emergencyTimer;

static NSString * const error_msg[ERROR_STATE_MAX] =
{
	[ERROR_STATE_NONE] = @"",
	[ERROR_STATE_NAVDATA_CONNECTION] = @"CONTROL LINK NOT AVAILABLE",
	[ERROR_STATE_START_NOT_RECEIVED] = @"START NOT RECEIVED",
	[ERROR_STATE_EMERGENCY_CUTOUT] = @"CUT OUT EMERGENCY",
	[ERROR_STATE_EMERGENCY_MOTORS] = @"MOTORS EMERGENCY",
	[ERROR_STATE_EMERGENCY_CAMERA] = @"CAMERA EMERGENCY",
	[ERROR_STATE_EMERGENCY_PIC_WATCHDOG] = @"PIC WATCHDOG EMERGENCY",
	[ERROR_STATE_EMERGENCY_PIC_VERSION] = @"PIC VERSION EMERGENCY",
	[ERROR_STATE_EMERGENCY_ANGLE_OUT_OF_RANGE] = @"TOO MUCH ANGLE EMERGENCY",
	[ERROR_STATE_EMERGENCY_VBAT_LOW] = @"BATTERY LOW EMERGENCY",
	[ERROR_STATE_EMERGENCY_USER_EL] = @"USER EMERGENCY",
	[ERROR_STATE_EMERGENCY_ULTRASOUND] = @"ULTRASOUND EMERGENCY",
	[ERROR_STATE_EMERGENCY_UNKNOWN] = @"UNKNOWN EMERGENCY",
    [ERROR_STATE_ALERT_CAMERA] = @"VIDEO CONNECTION ALERT",
	[ERROR_STATE_ALERT_VBAT_LOW] = @"BATTERY LOW ALERT",
	[ERROR_STATE_ALERT_ULTRASOUND] = @"ULTRASOUND ALERT",
	[ERROR_STATE_ALERT_VISION] = @"VISION ALERT",
};

void gpsConfigSuccess(bool_t result)
{
	if(result)
		gpsState = CONFIG_STATE_IDLE;
}

void getConfigSuccess(bool_t result)
{
	if(result)
		configurationState = CONFIG_STATE_IDLE;
}

ARDroneNavigationData navigationData;
ARDroneEnemiesData humanEnemiesData;	
ARDroneDetectionCamera detectionCamera;
ARDroneCamera droneCamera;

id<NavdataProtocol>navdata_delegate;
CGRect screenFrame;
BOOL bContinue;
ARDroneHUDConfiguration hudconfig;
bool_t wifiReachabled;
navdata_unpacked_t ctrlnavdata;
ERROR_STATE errorState;
@interface MainViewController ()

-(void)TimerHandler;
-(void)update;
@end

@implementation MainViewController
@synthesize wifiReachabled;

- (id) initWithFrame:(CGRect)frame withState:(BOOL)inGame withDelegate:(id<ARDroneProtocolOut>)delegate withNavdataDelegate:(id<NavdataProtocol>)_navdata_delegate withHUDConfiguration:(ARDroneHUDConfiguration*)hudconfiguration
{
	NSLog(@"Main View Controller Frame : %@", NSStringFromCGRect(frame));
    self = [super init];
	if(self)
	{
		bContinue = TRUE;
		screenFrame = frame;
		gameEngine = delegate;
		navdata_delegate = _navdata_delegate;

		errorState = ERROR_STATE_NONE;
        initControlData();
        navdata_reset(&ctrlnavdata);
        
		vp_os_memset(&navigationData, 0x0, sizeof(ARDroneNavigationData)); 
		vp_os_memset(&detectionCamera, 0x0, sizeof(ARDroneCamera));
		vp_os_memset(&droneCamera, 0x0, sizeof(ARDroneCamera)); 
		humanEnemiesData.count = 0;
        ardrone_timer_reset (&emergencyTimer);
		
		for(int i = 0 ; i < ARDRONE_MAX_ENEMIES ; i++)
		{
			vp_os_memset(&humanEnemiesData.data[i], 0x0, sizeof(ARDroneEnemyData));
			humanEnemiesData.data[i].width = 1.0;
			humanEnemiesData.data[i].height = 1.0;
		}

		if(hudconfiguration == nil)
		{
			hudconfig.enableBackToMainMenu = NO;
			hudconfig.enableSwitchScreen = YES;
			hudconfig.enableBatteryPercentage = YES;
		}
		else
		{
			vp_os_memcpy(&hudconfig, hudconfiguration, sizeof(ARDroneHUDConfiguration));
		}		
		hud = [[HUD alloc] initWithFrame:screenFrame withState:inGame withHUDConfiguration:hudconfig];
		[self.view addSubview:hud.view];
		hud.view.multipleTouchEnabled = YES;
		
		self.view.multipleTouchEnabled = YES;
		
		[self changeState:inGame];
		
		[NSThread detachNewThreadSelector:@selector(TimerHandler) toTarget:self withObject:nil];
	}
	
	return self;
}

+ (void)initDefaultConfig
{  
    setApplicationDefaultConfig();
}

- (void)setScreenOrientationRight:(BOOL)right
{
	[hud setScreenOrientationRight:right];
}

- (void) checkErrors
{
    input_state_t* input_state = ardrone_tool_input_get_state();
    
    if(configurationState == CONFIG_STATE_NEEDED)
    {
        NSLog(@"%s:%d get configuration", __FUNCTION__, __LINE__);
        configurationState = CONFIG_STATE_IN_PROGRESS;
        ARDRONE_TOOL_CONFIGURATION_GET(getConfigSuccess);
    }			
    
    if((gpsState == CONFIG_STATE_NEEDED) && configWasDone)
    {
        float64_t d_value;
        gpsState = CONFIG_STATE_IN_PROGRESS;
        d_value = gpsInfo.latitude;
        printf("Userbox latitude : %lf\n", d_value);
        ARDRONE_TOOL_CONFIGURATION_ADDEVENT(latitude, &d_value, NULL);
        d_value = gpsInfo.longitude;
        printf("Userbox longitude : %lf\n", d_value);
        ARDRONE_TOOL_CONFIGURATION_ADDEVENT(longitude, &d_value, NULL);
        d_value = gpsInfo.altitude;
        printf("Userbox altitude : %lf\n", d_value);
        ARDRONE_TOOL_CONFIGURATION_ADDEVENT(altitude, &d_value, gpsConfigSuccess);
        ardrone_video_set_gps_infos(gpsInfo.latitude, gpsInfo.longitude, gpsInfo.altitude);
    }
        
    errorState = ERROR_STATE_NONE;
    if(ardrone_navdata_client_get_num_retries())
    {
        ctrldata.navdata_connected = FALSE;
        errorState = ERROR_STATE_NAVDATA_CONNECTION;
        [hud setWifiLevel:-1.0];
 
        resetControlData();
        navdata_reset(&ctrlnavdata);
    }
    else 
    {
        ctrldata.navdata_connected = TRUE;
        if(ardrone_academy_navdata_get_emergency_state())
        {
            if(ctrlnavdata.ardrone_state & ARDRONE_CUTOUT_MASK)
            {
                errorState = ERROR_STATE_EMERGENCY_CUTOUT;
            }
            else if(ctrlnavdata.ardrone_state & ARDRONE_MOTORS_MASK)
            {
                errorState = ERROR_STATE_EMERGENCY_MOTORS;
            }
            else if(!(ctrlnavdata.ardrone_state & ARDRONE_VIDEO_THREAD_ON))
            {
                errorState = ERROR_STATE_EMERGENCY_CAMERA;
            }
            else if(ctrlnavdata.ardrone_state & ARDRONE_ADC_WATCHDOG_MASK)
            {
                errorState = ERROR_STATE_EMERGENCY_PIC_WATCHDOG;
            }
            else if(!(ctrlnavdata.ardrone_state & ARDRONE_PIC_VERSION_MASK))
            {
                errorState = ERROR_STATE_EMERGENCY_PIC_VERSION;
            }
            else if(ctrlnavdata.ardrone_state & ARDRONE_ANGLES_OUT_OF_RANGE)
            {
                errorState = ERROR_STATE_EMERGENCY_ANGLE_OUT_OF_RANGE;
            }
            else if(ctrlnavdata.ardrone_state & ARDRONE_USER_EL)
            {
                errorState = ERROR_STATE_EMERGENCY_USER_EL;
            }
            else if(ctrlnavdata.ardrone_state & ARDRONE_ULTRASOUND_MASK)
            {
                errorState = ERROR_STATE_EMERGENCY_ULTRASOUND;
            }
            else if(ctrlnavdata.ardrone_state & ARDRONE_VBAT_LOW)
            {
                errorState = ERROR_STATE_EMERGENCY_VBAT_LOW;
            }
            else
            {
                errorState = ERROR_STATE_EMERGENCY_UNKNOWN;
            }

            FLYING_STATE currentFlyingState = ardrone_academy_navdata_get_flying_state(&ctrlnavdata);
            if (FLYING_STATE_LANDED == currentFlyingState)
            {
            resetControlData();
            navdata_reset(&ctrlnavdata);
            }
        }
        else
        {
            if(video_stage_get_num_retries() > VIDEO_MAX_RETRIES)
            {
                errorState = ERROR_STATE_ALERT_CAMERA;
            }
            else if(ctrlnavdata.ardrone_state & ARDRONE_VBAT_LOW)
            {
                errorState = ERROR_STATE_ALERT_VBAT_LOW;
            }
            else if(ctrlnavdata.ardrone_state & ARDRONE_ULTRASOUND_MASK)
            {
                errorState = ERROR_STATE_ALERT_ULTRASOUND;
            }
            else if(!(ctrlnavdata.ardrone_state & ARDRONE_VISION_MASK))
            {
                FLYING_STATE tmp_state = ardrone_academy_navdata_get_flying_state(&ctrlnavdata);
                if(tmp_state == FLYING_STATE_FLYING)
                {
                    errorState = ERROR_STATE_ALERT_VISION;
                }
            }

            static bool_t prevStartStatus = FALSE;
            bool_t startStatus = ((1 << ARDRONE_UI_BIT_START) == (input_state->user_input & (1 << ARDRONE_UI_BIT_START))) ? TRUE : FALSE;
            if (TRUE == startStatus && FALSE == prevStartStatus)
            {
                ardrone_timer_update (&emergencyTimer);
            }
            if(TRUE == startStatus && !ardrone_academy_navdata_get_takeoff_state())
            {
                if (1000 < ardrone_timer_delta_ms (&emergencyTimer))
                {
                errorState = ERROR_STATE_START_NOT_RECEIVED;
                }
            }
            prevStartStatus = startStatus;
        }
    }
 }


- (void) update
{
	static CONFIG_STATE prev_config_state = CONFIG_STATE_IDLE;
    static bool_t prev_camera_ready = FALSE;
    static bool_t prev_usb_ready = FALSE;
    static bool_t show_loading_view = TRUE;
	static bool_t prev_navdata_connected = FALSE;
    static bool_t prev_emergency_state = FALSE;
    static ERROR_STATE prevErrorState = ERROR_STATE_NONE;
    static bool_t prev_flying_state = FALSE;
    static float wifiQuality = 1.0;
    
	if(prev_config_state != configurationState)
	{
		if(configurationState == CONFIG_STATE_IDLE)
        {
            [menuSettings configChanged];
        }
		prev_config_state = configurationState;
	}		
		
	if(prev_navdata_connected != ctrldata.navdata_connected)
	{
		[menuSettings configChanged];
        [hud notifyConnexion:(TRUE == ctrldata.navdata_connected)];
		prev_navdata_connected = ctrldata.navdata_connected;
	}
	
	if(hud.firePressed == YES) 
	{
		[gameEngine executeCommandOut:ARDRONE_COMMAND_FIRE withParameter:nil fromSender:self.view];
        hud.firePressed = NO;
	}
	else if(hud.mainMenuPressed == YES)
	{
		hud.mainMenuPressed = NO;
        show_loading_view = TRUE;
        academy_download_resume();
        [gameEngine executeCommandOut:ARDRONE_COMMAND_PAUSE withParameter:&ardrone_info fromSender:self.view];
	}
	else if(hud.settingsPressed == YES)
	{
		hud.settingsPressed = NO;
		[menuSettings performSelectorOnMainThread:@selector(switchDisplay) withObject:nil waitUntilDone:YES];
	}
	
	// Set velocities	
	navigationData.linearVelocity.x = -ctrlnavdata.navdata_demo.vy;
	navigationData.linearVelocity.y = ctrlnavdata.navdata_demo.vz;
	navigationData.linearVelocity.z = ctrlnavdata.navdata_demo.vx;
	navigationData.angularPosition.x = -ctrlnavdata.navdata_demo.theta / 1000;
	navigationData.angularPosition.y = ctrlnavdata.navdata_demo.psi / 1000;
	navigationData.angularPosition.z = ctrlnavdata.navdata_demo.phi / 1000;
	navigationData.navVideoNumFrames = ctrlnavdata.navdata_demo.num_frames;
//	navigationData.videoNumFrames    = get_video_current_numframes();

	// Set Back to main menu state.
	ARDRONE_FLYING_STATE tmp_state = (ARDRONE_FLYING_STATE)ardrone_academy_navdata_get_flying_state(&ctrlnavdata);
	bool_t current_record_state = ardrone_academy_navdata_get_record_ready();
    bool_t current_camera_ready = ardrone_academy_navdata_get_camera_state();

	if(navigationData.flyingState != tmp_state ||
       prev_camera_ready != current_camera_ready)
	{
        NSLog (@"State changed : Flying : %d -> %d | Camera : %d -> %d\n", navigationData.flyingState, tmp_state, prev_camera_ready, current_camera_ready);
		//NSLog(@"Flying state switch to %d", tmp_state);
        [hud performSelectorOnMainThread:@selector(showBackToMainMenu:) withObject:[NSNumber numberWithBool:((tmp_state == ARDRONE_FLYING_STATE_LANDED) && (current_camera_ready == TRUE))] waitUntilDone:NO];
        [hud performSelectorOnMainThread:@selector(showCameraButton:) withObject:[NSNumber numberWithBool:(current_camera_ready == TRUE)] waitUntilDone:NO];
        prev_camera_ready = current_camera_ready;
	}
	
    // Notify HUD about remaining time
    uint32_t usbRemainingTime = ardrone_academy_navdata_get_remaining_usb_time ();
    [hud performSelectorOnMainThread:@selector(setRemainingUSBTime:) withObject:[NSNumber numberWithUnsignedInt:usbRemainingTime] waitUntilDone:NO];
    
    // Notify when the AR.Drone stops an USB Record
    bool_t ardStopsUSBRecord = ardrone_academy_navdata_check_usb_record_status();
    if (TRUE == ardStopsUSBRecord)
    {
        [hud performSelectorOnMainThread:@selector(droneStoppedRecording) withObject:nil waitUntilDone:NO];
    }
    
    // Notify when take off is cancelled by a timeout
    bool_t ardCancelledTakeOff = ardrone_academy_navdata_check_takeoff_cancelled();
    if (TRUE == ardCancelledTakeOff)
    {
        [hud performSelectorOnMainThread:@selector(showBackToMainMenu:) withObject:[NSNumber numberWithBool:((tmp_state == ARDRONE_FLYING_STATE_LANDED) && (current_camera_ready == TRUE))] waitUntilDone:NO];
    }

    bool_t current_usb_ready = ardrone_academy_navdata_get_usb_state();
    if(prev_usb_ready != current_usb_ready)
    {
        [hud performSelectorOnMainThread:@selector(showUSB:) withObject:[NSNumber numberWithBool:current_usb_ready] waitUntilDone:NO];
        prev_usb_ready = current_usb_ready;
    }

	navigationData.flyingState = tmp_state;
	navigationData.emergencyState = ardrone_academy_navdata_get_emergency_state();
	navigationData.detection_type = (ARDRONE_CAMERA_DETECTION_TYPE)ctrlnavdata.navdata_demo.detection_camera_type;
	navigationData.finishLineCount = ctrlnavdata.navdata_games.finish_line_counter;
	navigationData.doubleTapCount = ctrlnavdata.navdata_games.double_tap_counter;
	navigationData.batteryLevel = ctrlnavdata.navdata_demo.vbat_flying_percentage / 100.0;
    navigationData.isInit = configWasDone;

    if(show_loading_view && navigationData.isInit && configWasDone)
    {
        [hud performSelectorOnMainThread:@selector(showLoadingView:) withObject:[NSNumber numberWithBool:NO] waitUntilDone:NO];
        show_loading_view = FALSE;
    }

	// Set detected ARDRONE_ENEMY_HUMAN enemies if detected.
	humanEnemiesData.count = MIN(ctrlnavdata.navdata_vision_detect.nb_detected, ARDRONE_MAX_ENEMIES);
	
	//printf("enemies count : %d\n", humanEnemiesData.count);
	for(int i = 0 ; i < humanEnemiesData.count ; i++)
	{
		humanEnemiesData.data[i].width = 2 * ctrlnavdata.navdata_vision_detect.width[i] / 1000.0;
		humanEnemiesData.data[i].height = 2 * ctrlnavdata.navdata_vision_detect.height[i] / 1000.0;		
		humanEnemiesData.data[i].position.x = (2 * ctrlnavdata.navdata_vision_detect.xc[i] / 1000.0) - 1.0;
		humanEnemiesData.data[i].position.y = -(2 * ctrlnavdata.navdata_vision_detect.yc[i] / 1000.0) + 1.0;
		humanEnemiesData.data[i].position.z = ctrlnavdata.navdata_vision_detect.dist[i];
		humanEnemiesData.data[i].orientation_angle = ctrlnavdata.navdata_vision_detect.orientation_angle[i];
	}
	
	// Set Detection Camera
	vp_os_memcpy(detectionCamera.rotation, &ctrlnavdata.navdata_demo.detection_camera_rot, sizeof(float) * 9);
	vp_os_memcpy(detectionCamera.translation, &ctrlnavdata.navdata_demo.detection_camera_trans, sizeof(float) * 3);
	detectionCamera.tag_index = ctrlnavdata.navdata_demo.detection_tag_index;
	
	// Set Drone Camera rotation
	vp_os_memcpy(droneCamera.rotation, &ctrlnavdata.navdata_demo.drone_camera_rot, sizeof(float) * 9);
	
	// Set Drone Camera translation
	// Get enemies data
	if ([gameEngine respondsToSelector:@selector(AIEnemiesData:)])
	{
		ARDroneEnemiesData AIEnemiesData;
		vp_os_memset(&AIEnemiesData, 0x0, sizeof(ARDroneEnemiesData));
		[gameEngine AIEnemiesData:&AIEnemiesData];		
	}
	
	vp_os_memcpy(&droneCamera.translation[0], &ctrlnavdata.navdata_demo.drone_camera_trans, sizeof(float) * 3);
	
	// Set battery level in hud view
	[hud setBattery:(int)ctrlnavdata.navdata_demo.vbat_flying_percentage];
    [hud checkRecordProgress];
    [hud updatePopUp];
    // Set wifi link quality in hud view
    float newWifiQuality = 1.0 - ((float)ctrlnavdata.navdata_wifi.link_quality / 500.0);
    wifiQuality = 0.9 * wifiQuality + 0.1 * newWifiQuality;
    if (ERROR_STATE_NAVDATA_CONNECTION != errorState)
    {
        [hud setWifiLevel:wifiQuality];
        if (ERROR_STATE_NAVDATA_CONNECTION == prevErrorState)
        {
            // Check for backToMainMenu button
            [hud performSelectorOnMainThread:@selector(showBackToMainMenu:) withObject:[NSNumber numberWithBool:((tmp_state == ARDRONE_FLYING_STATE_LANDED) && (current_record_state == FALSE))] waitUntilDone:NO];
        }
    }
    else
    {
        if(prevErrorState != errorState)
        {
            [hud performSelectorOnMainThread:@selector(showBackToMainMenu:) withObject:[NSNumber numberWithBool:YES] waitUntilDone:NO];
        }
    }
	
	// Set  all texts in Hud view
    // Blink the emergency message
    if (ERROR_STATE_NONE != errorState)
    {
        if(ctrldata.framecounter >= (kFPS / 2.0))
            [hud setMessageBox:[[NSBundle mainBundle] localizedStringForKey:error_msg[errorState] value:@"UNKNOWN_KEY" table:@"languages"]];
        else
            [hud setMessageBox:@""];
        prevErrorState = errorState;
    }
    else if (prevErrorState != errorState)
    {
        [hud setMessageBox:@""];
        prevErrorState = errorState;
    }
    
    if (navigationData.emergencyState)
    {
        if (FALSE == prev_emergency_state)
        {
            [hud performSelectorOnMainThread:@selector(setEmergency:) withObject:[NSNumber numberWithBool:YES] waitUntilDone:YES];
        }
        prev_emergency_state = TRUE;
    }
    else if (TRUE == prev_emergency_state)
    {
        prev_emergency_state = FALSE;
        [hud setMessageBox:@""];
        [hud performSelectorOnMainThread:@selector(setEmergency:) withObject:[NSNumber numberWithBool:NO] waitUntilDone:YES];
    }
	
    bool_t current_flying_state = ardrone_academy_navdata_get_takeoff_state();
    if (prev_flying_state != current_flying_state)
    {
        prev_flying_state = current_flying_state;
        NSNumber *flyingState = [NSNumber numberWithBool:(current_flying_state ? YES : NO)];
        [menuSettings performSelectorOnMainThread:@selector(setFlyingState:) withObject:flyingState waitUntilDone:NO];
        [hud performSelectorOnMainThread:@selector(setTakeOff:) withObject:flyingState waitUntilDone:YES];
    }
}

- (void) TimerHandler 
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init]; // Top-level pool
	
	ardrone_timer_t timer;
	int refreshTimeInUs = 1000000 / kFPS;
	
	ardrone_timer_reset(&timer);
	ardrone_timer_update(&timer);
	
	while(bContinue)
	{
		uint64_t delta = ardrone_timer_delta_us(&timer);
		if( delta >= refreshTimeInUs)
		{
			// Render frame
			ardrone_timer_update(&timer);
			
			if(self.view.hidden == NO)
			{
				[navdata_delegate parrotNavdata:&ctrlnavdata];
				[self performSelectorOnMainThread:@selector(update) withObject:nil waitUntilDone:YES];
                [self checkErrors];
			}
			
			ctrldata.framecounter = (ctrldata.framecounter + 1) % kFPS;
		}
		else
		{
			usleep(refreshTimeInUs - delta);
		}
	}

    [pool release];  // Release the objects in the pool.
}

- (ARDroneNavigationData*)navigationData
{
	return &navigationData;
}

- (ARDroneDetectionCamera*)detectionCamera
{
	return &detectionCamera;
}

- (ARDroneCamera*)droneCamera
{
	return &droneCamera;
}

- (ARDroneEnemiesData*)humanEnemiesData
{
	return &humanEnemiesData;
}

- (void)changeState:(BOOL)inGame
{
	self.view.hidden = !inGame;
	[hud changeState:inGame];
    
    if (inGame)
    {
		menuSettings = [[SettingsMenu alloc] initWithFrame:screenFrame AndHUDConfiguration:hudconfig withDelegate:hud];
		menuSettings.view.hidden = YES;
		[self.view addSubview:menuSettings.view];
        menuSettings.view.multipleTouchEnabled = YES;
    }
    else
    {
        [menuSettings.view removeFromSuperview];
        [menuSettings release];
        menuSettings = nil;
    }
}

- (void)executeCommandIn:(ARDRONE_COMMAND_IN_WITH_PARAM)commandIn fromSender:(id)sender refreshSettings:(BOOL)refresh
{
	int32_t i_value;
	switch (commandIn.command) {
	
		case ARDRONE_COMMAND_ISCLIENT:
			i_value = ((int)commandIn.parameter == 0) ? ADC_CMD_SELECT_ULTRASOUND_25Hz : ADC_CMD_SELECT_ULTRASOUND_22Hz;
			ARDRONE_TOOL_CONFIGURATION_ADDEVENT(ultrasound_freq, &i_value, commandIn.callback);
			break;
			
		case ARDRONE_COMMAND_DRONE_ANIM:
			{
				ARDRONE_ANIMATION_PARAM *param = (ARDRONE_ANIMATION_PARAM*)commandIn.parameter;
				char str_param[SMALL_STRING_SIZE];
				sprintf(str_param, "%d,%d", param->drone_anim, ((param->timeout == 0) ? MAYDAY_TIMEOUT[param->drone_anim] : param->timeout));
				ARDRONE_TOOL_CONFIGURATION_ADDEVENT(flight_anim, str_param, commandIn.callback);
			}
			break;
			
		case ARDRONE_COMMAND_DRONE_LED_ANIM:
			{
				char param[SMALL_STRING_SIZE];
				float_or_int_t freq;
				freq.f = ((ARDRONE_LED_ANIMATION_PARAM*)commandIn.parameter)->frequency;
				sprintf(param, "%d,%d,%d", ((ARDRONE_LED_ANIMATION_PARAM*)commandIn.parameter)->led_anim, freq.i, ((ARDRONE_LED_ANIMATION_PARAM*)commandIn.parameter)->duration);
				ARDRONE_TOOL_CONFIGURATION_ADDEVENT(leds_anim, param, commandIn.callback);
			}
			break;
			
		case ARDRONE_COMMAND_ENABLE_COMBINED_YAW:
			{
				bool_t enable = (bool_t)commandIn.parameter;
				i_value = enable ? (ardrone_control_config.control_level | (1 << CONTROL_LEVEL_COMBINED_YAW)) : (ardrone_control_config.control_level & ~(1 << CONTROL_LEVEL_COMBINED_YAW));
				ARDRONE_TOOL_CONFIGURATION_ADDEVENT(control_level, &i_value, commandIn.callback);
				[hud combinedYawValueChanged:enable];
			}
			break;
			
		case ARDRONE_COMMAND_SET_CONFIG:
		{
			ARDRONE_CONFIG_PARAM *param = (ARDRONE_CONFIG_PARAM *)commandIn.parameter;
			switch (param->config_key)
			{
#undef COMMAND_IN_CONFIG_KEY
#undef COMMAND_IN_CONFIG_KEY_STRING
#define COMMAND_IN_CONFIG_KEY(CASE, KEY, TYPE)													\
case CASE:																						\
	ardrone_control_config.KEY = *(TYPE *)(param->pvalue);										\
	ARDRONE_TOOL_CONFIGURATION_ADDEVENT (KEY, &ardrone_control_config.KEY, commandIn.callback);	\
	break;
#define COMMAND_IN_CONFIG_KEY_STRING(CASE, KEY)													\
case CASE:																						\
	strcpy (ardrone_control_config.KEY, (char *)(param->pvalue));								\
	ARDRONE_TOOL_CONFIGURATION_ADDEVENT (KEY, ardrone_control_config.KEY, commandIn.callback);	\
	break;
#include "ARDroneGeneratedCommandIn.h"
#undef COMMAND_IN_CONFIG_KEY
#undef COMMAND_IN_CONFIG_KEY_STRING
					
				default:
					NSLog(@"The ARDRONE_CONFIG_KEY %d is not implemented !", param->config_key);
					break;
			}
		}	
		break;
		
		default:
			NSLog(@"The ARDRONE_COMMAND_IN %d is not implemented !", commandIn.command);
			break;
	}
	
	if (refresh)
	{
		[menuSettings performSelectorOnMainThread:@selector(configChanged) withObject:nil waitUntilDone:YES];
	}
}

- (void)executeCommandIn:(ARDRONE_COMMAND_IN)commandId withParameter:(void*)parameter fromSender:(id)sender
{
	int32_t i_value;
	switch (commandId) {
		case ARDRONE_COMMAND_ISCLIENT:
        {
            i_value = ((int)parameter == 0) ? ADC_CMD_SELECT_ULTRASOUND_25Hz : ADC_CMD_SELECT_ULTRASOUND_22Hz;
            ARDRONE_TOOL_CONFIGURATION_ADDEVENT(ultrasound_freq, &i_value, NULL);
        }
            break;
			
		case ARDRONE_COMMAND_DRONE_ANIM:
        {
            ARDRONE_ANIMATION_PARAM *param = (ARDRONE_ANIMATION_PARAM*)parameter;
            char str_param[SMALL_STRING_SIZE];
            sprintf(str_param, "%d,%d", param->drone_anim, ((param->timeout == 0) ? MAYDAY_TIMEOUT[param->drone_anim] : param->timeout));
            ARDRONE_TOOL_CONFIGURATION_ADDEVENT(flight_anim, str_param, NULL);
        }
			break;
			
		case ARDRONE_COMMAND_VIDEO_CHANNEL:
			i_value = (int32_t)parameter;
			ARDRONE_TOOL_CONFIGURATION_ADDEVENT(video_channel, &i_value, NULL);
			break;
			
		case ARDRONE_COMMAND_SET_FLY_MODE:
			i_value = (int32_t)parameter;
			ARDRONE_TOOL_CONFIGURATION_ADDEVENT(flying_mode, &i_value, NULL);
			break;
			
		case ARDRONE_COMMAND_CAMERA_DETECTION:
			i_value = (int32_t)parameter;
			ARDRONE_TOOL_CONFIGURATION_ADDEVENT(detect_type, &i_value, NULL);
			break;
			
		case ARDRONE_COMMAND_ENEMY_SET_PARAM:
			i_value = ((ARDRONE_ENEMY_PARAM*)parameter)->color;
			ARDRONE_TOOL_CONFIGURATION_ADDEVENT(enemy_colors, &i_value, NULL);
			i_value = ((ARDRONE_ENEMY_PARAM*)parameter)->outdoor_shell;
			ARDRONE_TOOL_CONFIGURATION_ADDEVENT(enemy_without_shell, &i_value, NULL);
			break;
			
		case ARDRONE_COMMAND_DRONE_LED_ANIM:
		{
			char param[SMALL_STRING_SIZE];
			float_or_int_t freq;
			freq.f = ((ARDRONE_LED_ANIMATION_PARAM*)parameter)->frequency;
			sprintf(param, "%d,%d,%d", ((ARDRONE_LED_ANIMATION_PARAM*)parameter)->led_anim, freq.i, ((ARDRONE_LED_ANIMATION_PARAM*)parameter)->duration);
			ARDRONE_TOOL_CONFIGURATION_ADDEVENT(leds_anim, param, NULL);
		}
			break;
			
		case ARDRONE_COMMAND_ENABLE_COMBINED_YAW:
        {
            bool_t enable = (bool_t)parameter;
            i_value = enable ? (ardrone_control_config.control_level | (1 << CONTROL_LEVEL_COMBINED_YAW)) : (ardrone_control_config.control_level & ~(1 << CONTROL_LEVEL_COMBINED_YAW));
            ARDRONE_TOOL_CONFIGURATION_ADDEVENT(control_level, &i_value, NULL);
            [hud combinedYawValueChanged:enable];
        }
			break;
			
		default:
			NSLog(@"The ARDRONE_COMMAND_IN %d is not implemented !", commandId);
			break;
	}
}

- (void)setDefaultConfigurationForKey:(ARDRONE_CONFIG_KEYS)key withValue:(void *)value
{
	switch (key)
	{
#undef COMMAND_IN_CONFIG_KEY
#undef COMMAND_IN_CONFIG_KEY_STRING
#define COMMAND_IN_CONFIG_KEY(CASE, KEY, TYPE)									\
		case CASE:																\
			ardrone_application_default_config.KEY = *(TYPE *)(value);			\
			break;
#define COMMAND_IN_CONFIG_KEY_STRING(CASE, KEY)									\
		case CASE:																\
			strcpy (ardrone_application_default_config.KEY, (char *)(value));	\
			break;
#include "ARDroneGeneratedCommandIn.h"
#undef COMMAND_IN_CONFIG_KEY
#undef COMMAND_IN_CONFIG_KEY_STRING
		default:
			NSLog(@"The ARDRONE_CONFIG_KEY %d is not implemented !", key);
			break;
	}
}

- (BOOL) shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation
{
	return (toInterfaceOrientation == UIInterfaceOrientationLandscapeRight || toInterfaceOrientation == UIInterfaceOrientationLandscapeLeft);
}

- (void)didReceiveMemoryWarning 
{
	// Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
	
	// Release any cached data, images, etc that aren't in use.
}

- (void)viewDidUnload {
	// Release any retained subviews of the main view.
	// e.g. self.myOutlet = nil;
}


- (void)dealloc {
	[self changeState:NO];
	bContinue = TRUE;
	
	[hud release];
	[menuSettings release];
	
	[super dealloc];
}

+ (void)getConfiguration
{
    if(configurationState == CONFIG_STATE_IDLE)
        configurationState = CONFIG_STATE_NEEDED;
}

+ (void)setGPSInfo:(gps_info_t)gps_info
{
    if(gpsState == CONFIG_STATE_IDLE)
    {
        vp_os_memcpy(&gpsInfo, &gps_info, sizeof(gps_info_t));
        gpsState = CONFIG_STATE_NEEDED;
    }
}

@end
