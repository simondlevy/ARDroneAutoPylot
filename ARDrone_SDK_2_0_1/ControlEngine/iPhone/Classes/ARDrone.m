/**
 * @file ARDrone.m
 *
 * Copyright 2009 Parrot SA. All rights reserved.
 * @author D HAEYER Frederic
 * @date 2009/10/26
 */
#import <CommonCrypto/CommonDigest.h>
#import "MainViewController.h"
#import "InternalProtocols.h"
#import "ARDrone.h"
#import "ARDroneMediaManager.h"
#import "TVOut.h"
#include <dlfcn.h>
#include <sys/param.h>
#include <sys/mount.h>
#include <sys/sysctl.h>
#include <ardrone_tool/Navdata/ardrone_general_navdata.h>

//#define DEBUG_ENNEMIES_DETECTON
//#define DEBUG_NAVIGATION_DATA
//#define DEBUG_DETECTION_CAMERA
//#define DEBUG_DRONE_CAMERA

// Implement MD5Addition extension of NSString
@interface NSString (MD5Addition)
- (NSString *) stringFromMD5;
@end

@implementation NSString (MD5Addition)

- (NSString *) stringFromMD5
{
    
    if(self == nil || [self length] == 0)
        return nil;
    
    const char *value = [self UTF8String];
    
    unsigned char outputBuffer[CC_MD5_DIGEST_LENGTH];
    CC_MD5(value, strlen(value), outputBuffer);
    
    NSMutableString *outputString = [[NSMutableString alloc] initWithCapacity:CC_MD5_DIGEST_LENGTH * 2];
    for(NSInteger count = 0; count < CC_MD5_DIGEST_LENGTH; count++){
        [outputString appendFormat:@"%02x",outputBuffer[count]];
    }
    return [outputString autorelease];
}

@end

// Implement IdentifierAddition extension of UIDevice
@interface UIDevice (IdentifierAddition)
- (NSString *) uniqueDeviceIdentifier;
- (NSString *) uniqueGlobalDeviceIdentifier;
@end

@implementation UIDevice (IdentifierAddition)
- (NSString *) uniqueDeviceIdentifier
{
    NSString *macaddress = [NSString stringWithCString:iphone_mac_address encoding:NSUTF8StringEncoding];
    NSString *bundleIdentifier = [[NSBundle mainBundle] bundleIdentifier];  
    NSString *stringToHash = [NSString stringWithFormat:@"%@%@",macaddress, bundleIdentifier];
    NSString *uniqueIdentifier = [stringToHash stringFromMD5];  
    return uniqueIdentifier;
}

- (NSString *) uniqueGlobalDeviceIdentifier
{
    NSString *macaddress = [NSString stringWithCString:iphone_mac_address encoding:NSUTF8StringEncoding];
    NSString *uniqueIdentifier = [macaddress stringFromMD5];    
    return uniqueIdentifier;
}
@end

// Implement ARDrone class
static bool_t threadStarted = false;
/*************************************/
/* ARDroneMediaManager               */
/*************************************/
void ARDroneMediaManagerCallback(const char *mediaPath, bool_t addToQueue)
{
    if (NULL != mediaPath)
    {
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        [[ARDroneMediaManager sharedInstance] performSelectorInBackground:@selector(mediaManagerTransferToCameraRoll:) withObject:[NSString stringWithCString:mediaPath encoding:NSUTF8StringEncoding]];
        [pool release];
    }
}

static void ARDroneCallback(ARDRONE_ENGINE_MESSAGE msg)
{
	switch(msg)
	{
		case ARDRONE_ENGINE_INIT_OK:
			threadStarted = TRUE;
            [MainViewController initDefaultConfig];
			break;
			
		default:
			break;
	}
}

@interface ARDrone (private) <NavdataProtocol, CLLocationManagerDelegate, UIAlertViewDelegate>
- (void) parrotNavdata:(navdata_unpacked_t*)data;
- (void) checkThreadStatus;
- (float) availableDiskSpace;
- (void)encoderResume:(NSNotification*)notification;
- (void)encoderSuspend:(NSNotification*)notification;
- (void)encoderDidFinish:(NSNotification *)notification;
@end

/**
 * Define a few methods to make it possible for the game engine to control the Parrot drone
 */
@implementation ARDrone
@synthesize running;
@synthesize view;
	MainViewController *mainviewctrl;
	BOOL inGameOnDemand;
	CGRect screenFrame;
	id <ARDroneProtocolOut> _uidelegate;
	ARDroneHUDConfiguration *hudconfig;
	CLLocationManager *locationManager;
	CLLocation *bestEffortAtLocation;

/**
 * Initialize the Parrot library.<br/>
 * Note: the library will clean-up everything it allocates by itself, when being destroyed (i.e. when its retain count reaches 0).
 *
 * @param frame Frame of parent view, used to create the library view (which shall cover the whole screen).
 * @param inGame Initial state of the game at startup.
 * @param uidelegate Pointer to the object that implements the Parrot protocol ("ARDroneProtocol"), which will be called whenever the library needs the game engine to change its state.
 * @return Pointer to the newly initialized Parrot library instance.
 */
- (id) initWithFrame:(CGRect)frame withState:(BOOL)inGame withDelegate:(id <ARDroneProtocolOut>)uidelegate withHUDConfiguration:(ARDroneHUDConfiguration*)hudconfiguration  percentageMemorySpace:(NSUInteger)percentageMemorySpace
{
	if((self = [super init]) != nil)
	{
		NSLog(@"Frame ARDrone Engine : %f, %f", frame.size.width, frame.size.height);

#ifdef ENABLE_AUTO_TVOUT
		[[[TVOut alloc] init] setupScreenMirroringWithFramesPerSecond:10];
#endif
        
		running = NO;
		inGameOnDemand = inGame;
		threadStarted = FALSE;
		_uidelegate = uidelegate;
		bestEffortAtLocation = nil;
		locationManager = nil;

		// Update user path
		[[NSFileManager defaultManager]changeCurrentDirectoryPath:[[NSBundle mainBundle]resourcePath]];
		NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES); //creates paths so that you can pull the app's path from it
		
        // Create thread to refresh media Manager 
        [[ARDroneMediaManager sharedInstance] mediaManagerInit];

        // Get iphone_mac_address
        get_iphone_mac_address(WIFI_ITFNAME);
        PRINT("Iphone MAC Address %s\n", iphone_mac_address);
		
		// Create main view controller
		mainviewctrl = [[MainViewController alloc] initWithFrame:frame withState:inGame withDelegate:uidelegate withNavdataDelegate:self withHUDConfiguration:hudconfiguration];
		view = mainviewctrl.view;
		
		NSString *bundleName = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleIdentifier"];
        NSString *username = [NSString stringWithFormat:@".%@:%@", [[UIDevice currentDevice] model], [[UIDevice currentDevice] uniqueGlobalDeviceIdentifier]];
        
        quicktime_encoder_stage_init();
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(encoderDidFinish:)
                                                     name:QuicktimeEncoderStageDidFinishEncoding object:nil]; 

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(encoderResume:)
                                                     name:QuicktimeEncoderStageDidResume 
                                                   object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(encoderSuspend:)
                                                     name:QuicktimeEncoderStageDidSuspend 
                                                                object:nil];
        
        // Start ardrone engine
 		ardroneEngineStart(ARDroneCallback, [bundleName cStringUsingEncoding:NSUTF8StringEncoding], [username cStringUsingEncoding:NSUTF8StringEncoding], [[paths objectAtIndex:0] cStringUsingEncoding:NSUTF8StringEncoding], [[paths objectAtIndex:0] cStringUsingEncoding:NSUTF8StringEncoding], [self availableDiskSpace] * percentageMemorySpace / 100, ARDroneMediaManagerCallback, &videoTexture);
        
        [self checkThreadStatus];
        
		// Create a location manager instance to determine if location services are enabled. This manager instance will be immediately released afterwards.
		locationManager = [[[CLLocationManager alloc] init] retain];
        locationManager.delegate = self;
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters;
        [locationManager startUpdatingLocation];
        [self performSelector:@selector(stopUpdatingLocation:) withObject:nil afterDelay:GPS_TIMEOUT];
	}
	
	return( self );
}

- (void)encoderResume:(NSNotification *)notification
{
    if(IS_ARDRONE1)
    {
        quicktime_encoder_stage_resume();
    }
}

- (void)encoderSuspend:(NSNotification *)notification
{
    if(IS_ARDRONE1)
    {
        quicktime_encoder_stage_suspend();
    }
}

- (void)encoderDidFinish:(NSNotification *)notification
{
    if(IS_ARDRONE1)
    {
        [[ARDroneMediaManager sharedInstance] mediaManagerTransferToCameraRoll:[notification object]];
    }
}

- (float) availableDiskSpace
{
    NSString *sizeType;
    float availableDisk;
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    
    struct statfs tStats;
    statfs([[paths lastObject] cString], &tStats);
    availableDisk = (float)(tStats.f_bavail * tStats.f_bsize);
    
    //Megabytes
    availableDisk = BYTE_TO_MBYTE(availableDisk);
    sizeType = @" MB";

    return availableDisk;
}

- (BOOL)locationServicesAlertDidAppear
{
    BOOL retVal = NO;
    
    if (![CLLocationManager locationServicesEnabled] || [CLLocationManager authorizationStatus] != kCLAuthorizationStatusAuthorized)   
    {
        retVal = YES;
        UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:ARDroneEngineLocalizeString(@"Location Services Disabled") 
                                                            message:ARDroneEngineLocalizeString(@"If you want to store your location and access your media gallery, enable it in your device's settings.")
                                                           delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil, nil];
        [alertView show];
        [alertView release];
    }
    return retVal;
}
                                                                                                  
- (void)stopUpdatingLocation:(NSString *)state 
{
	[locationManager stopUpdatingLocation];
	locationManager.delegate = nil;
    
	if (state == nil)
	{
        NSLog(@"Location not found");
        if (![self locationServicesAlertDidAppear])
        {
            UIAlertView *locationServicesAlert = [[UIAlertView alloc] initWithTitle:ARDroneEngineLocalizeString(@"Location Services Alert") 
                                                                            message:ARDroneEngineLocalizeString(@"Location services request timeout.\nYour location won't be stored in your AR.Drone.") 
                                                                           delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
            [locationServicesAlert show];
            [locationServicesAlert release];
        }
	}
	else
	{
		printf("Location found !!!");
        gps_info_t gps_info = {
            (float64_t)[bestEffortAtLocation coordinate].latitude,
            (float64_t)[bestEffortAtLocation coordinate].longitude,
            (float64_t)[bestEffortAtLocation altitude]
        };

        [MainViewController setGPSInfo:gps_info];
	}
}

/*
 * We want to get and store a location measurement that meets the desired accuracy. For this example, we are
 *      going to use horizontal accuracy as the deciding factor. In other cases, you may wish to use vertical
 *      accuracy, or both together.
 */
- (void)locationManager:(CLLocationManager *)manager didUpdateToLocation:(CLLocation *)newLocation fromLocation:(CLLocation *)oldLocation {

    // test the age of the location measurement to determine if the measurement is cached
    // in most cases you will not want to rely on cached measurements
    NSTimeInterval locationAge = -[newLocation.timestamp timeIntervalSinceNow];
    if (locationAge > 5.0) 
		return;
    
	// test that the horizontal accuracy does not indicate an invalid measurement
    if (newLocation.horizontalAccuracy < 0) 
		return;

    // test the measurement to see if it is more accurate than the previous measurement
    if (bestEffortAtLocation == nil || bestEffortAtLocation.horizontalAccuracy > newLocation.horizontalAccuracy) 
	{
        // store the location as the "best effort"
		[newLocation retain];
		[bestEffortAtLocation release];
		bestEffortAtLocation = newLocation;
		
        // test the measurement to see if it meets the desired accuracy
        // IMPORTANT!!! kCLLocationAccuracyBest should not be used for comparison with location coordinate or altitidue 
        // accuracy because it is a negative value. Instead, compare against some predetermined "real" measure of 
        // acceptable accuracy, or depend on the timeout to stop updating. This sample depends on the timeout.
		if (newLocation.horizontalAccuracy <= locationManager.desiredAccuracy) 
		{
            // we have a measurement that meets our requirements, so we can stop updating the location
			// IMPORTANT!!! Minimize power usage by stopping the location manager as soon as possible.
            [self stopUpdatingLocation:@"Acquired Location"];
			// we can also cancel our previous performSelector:withObject:afterDelay: - it's no longer necessary
            [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(stopUpdatingLocation:) object:nil];
		}
    }
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error
{    
    NSLog(@"%s", __func__);
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(stopUpdatingLocation:) object:nil];
    [self locationServicesAlertDidAppear];
    locationManager.delegate = nil;
}

- (void)checkThreadStatus
{
    NSLog(@"%s", __FUNCTION__);
	[mainviewctrl setWifiReachabled:threadStarted];
    
    if (threadStarted)
	{
		running = YES;
		[_uidelegate executeCommandOut:ARDRONE_COMMAND_RUN withParameter:(void*)&ardrone_info fromSender:self];
		[self changeState:inGameOnDemand];
	}
	else
	{
		[NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(checkThreadStatus) userInfo:nil repeats:NO];
	}
}

/*
 * Render a frame. Basically, the Parrot Library renders:<ul>
 * <li> A full screen textured quad in the background (= the video sent by the drone);</li>
 * <li> A set of elements in the foreground (=HUD).</li>
 * </ul>
 */

- (void) dealloc
{
	[self changeState:NO];
	
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
	[mainviewctrl release];
	[locationManager release];
    
    [[ARDroneMediaManager sharedInstance] mediaManagerShutdown];
    
    ardroneEngineStop();
    
    academy_shutdown();
    [super dealloc];
}

/**
 * Set what shall be the orientation of the screen when rendering a frame.
 *
 * @param right Orientation of the screen: FALSE for "landscape left", TRUE for "landscape right".
 */
- (void)setScreenOrientationRight:(BOOL)right
{
	NSLog(@"Screen orientation right : %d", right);
	if(mainviewctrl != nil)
		[mainviewctrl setScreenOrientationRight:right];
}

- (void)parrotNavdata:(navdata_unpacked_t*)data
{
	navdata_get(data);
}

/**
 * Get the latest drone's navigation data.
 *
 * @param data Pointer to a navigation data structure.
 */
- (void)navigationData:(ARDroneNavigationData*)data
{
	if(view != nil)
	{
		vp_os_memcpy(data, [mainviewctrl navigationData], sizeof(ARDroneNavigationData));
#ifdef DEBUG_NAVIGATION_DATA
		static int numsamples = 0;
		if(numsamples++ > 64)
		{
			NSLog(@"x : %f, y : %f, z : %f, flying state : %d, navdata video num frame : %d, video num frames : %d", data->angularPosition.x, data->angularPosition.y, data->angularPosition.z, data->flyingState, data->navVideoNumFrames, data->videoNumFrames);		
			numsamples = 0;
		}
#endif
	}
}

/**
 * Get the latest detection camera structure (rotation and translation).
 *
 * @param data Pointer to a detection camera structure.
 */
- (void)detectionCamera:(ARDroneDetectionCamera*)camera
{
	if(view != nil)
	{
		vp_os_memcpy(camera, [mainviewctrl detectionCamera], sizeof(ARDroneDetectionCamera));
#ifdef DEBUG_DETECTION_CAMERA
		static int numsamples = 0;
		if(numsamples++ > 64)
		{
			NSLog(@"Detection Camera Rotation : %f %f %f %f %f %f %f %f %f",
					camera->rotation[0][0], camera->rotation[0][1], camera->rotation[0][2],
					camera->rotation[1][0], camera->rotation[1][1], camera->rotation[1][2],
					camera->rotation[2][0], camera->rotation[2][1], camera->rotation[2][2]);
			NSLog(@"Detection Camera Translation : %f %f %f", camera->translation[0], camera->translation[1], camera->translation[2]);
			NSLog(@"Detection Camera Tag Index : %d", camera->tag_index);
			
			numsamples = 0;
		}
#endif
	}
}

/**
 * Get the latest drone camera structure (rotation and translation).
 *
 * @param data Pointer to a drone camera structure.
 */
- (void)droneCamera:(ARDroneCamera*)camera
{
	if(view != nil)
	{
		vp_os_memcpy(camera, [mainviewctrl droneCamera], sizeof(ARDroneCamera));
#ifdef DEBUG_DRONE_CAMERA
		static int numsamples = 0;
		if(numsamples++ > 64)
		{
			NSLog(@"Drone Camera Rotation : %f %f %f %f %f %f %f %f %f",
				  camera->rotation[0][0], camera->rotation[0][1], camera->rotation[0][2],
				  camera->rotation[1][0], camera->rotation[1][1], camera->rotation[1][2],
				  camera->rotation[2][0], camera->rotation[2][1], camera->rotation[2][2]);
			NSLog(@"Drone Camera Translation : %f %f %f", camera->translation[0], camera->translation[1], camera->translation[2]);
			numsamples = 0;
		}
#endif
	}
}

/**
 * Exchange enemies data.<br/>
 * Note: basically, data should be provided by the Parrot library when in multiplayer mode (enemy type = "HUMAN"), and by the game controller when in single player mode (enemy type = "AI").
 *
 * @param data Pointer to an enemies data structure.
 */
- (void)humanEnemiesData:(ARDroneEnemiesData*)data
{
	if(view != nil)
	{
		vp_os_memcpy(data, [mainviewctrl humanEnemiesData], sizeof(ARDroneEnemiesData));
#ifdef DEBUG_ENNEMIES_DETECTON
		static int old_value = 0;
		if(old_value != data->count) 
			NSLog(@"enemies detected : %d", data->count);
		old_value = data->count;
#endif
	}
}

- (void)changeState:(BOOL)inGame
{
	// Check whether there is a change of state
	if(threadStarted)
	{
		// Change the state of the library
		if(inGame)
			ardroneEngineResume();
		else
            ardroneEnginePause();

		running = inGame;
	}
	else
	{
		inGameOnDemand = inGame;
	}
	
	// Change state of view
	[mainviewctrl changeState:inGame];

}

- (void)executeCommandIn:(ARDRONE_COMMAND_IN_WITH_PARAM)commandIn fromSender:(id)sender refreshSettings:(BOOL)refresh
{
	[mainviewctrl executeCommandIn:commandIn fromSender:sender refreshSettings:refresh];	
}

- (void)executeCommandIn:(ARDRONE_COMMAND_IN)commandId withParameter:(void*)parameter fromSender:(id)sender
{
	[mainviewctrl executeCommandIn:commandId withParameter:parameter fromSender:sender];	
}

- (void)setDefaultConfigurationForKey:(ARDRONE_CONFIG_KEYS)key withValue:(void *)value
{
	[mainviewctrl setDefaultConfigurationForKey:key withValue:value];
}

- (BOOL)checkState
{
	return running;
}
- (ARDroneOpenGLTexture *)videoTexture;
{
    return &videoTexture;
}
@end
