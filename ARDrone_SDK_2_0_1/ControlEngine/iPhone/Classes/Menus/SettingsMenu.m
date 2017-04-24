#import "SettingsMenu.h"
#import "MainViewController.h"

@implementation ARMenuSettingsButton

- (void)setHighlighted:(BOOL)highlighted
{
    [super setHighlighted:highlighted];
    if (highlighted)
        [self setBackgroundColor:ORANGE(1.f)];
    else
        [self setBackgroundColor:BLACK(1.f)];
}

@end

#define REFRESH_TRIM_TIMEOUT	1
#define ALTITUDE_LIMITED_MIN	(default_altitude_max)
#define ALTITUDE_LIMITED_MAX	(no_altitude_limit)

#define SYSTEM_VERSION_LESS_THAN(v)                 ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] == NSOrderedAscending)

#define MAGNETOCALIB_ALERT_TAG  100

extern ControlData ctrldata;

struct tm *settings_atm = NULL;

#ifdef INTERFACE_WITH_DEBUG
typedef enum _LOGS_STATE_
{
    LOGS_STATE_INIT,
    LOGS_STATE_SUCCESS,
    LOGS_STATE_FAILURE,
    LOGS_STATE_MAX,
} LOGS_STATE;

static LOGS_STATE logs_state = LOGS_STATE_INIT;

void logs_navdata_demo(bool_t result)
{
    if(result)
        logs_state = LOGS_STATE_SUCCESS;
    else
        logs_state = LOGS_STATE_FAILURE;
}
#endif

enum switchStatusEnum
{
    SWITCH_UNCHECKED = 0,
    SWITCH_CHECKED,
};

id <SettingsMenuDelegate> _delegate;
ControlData *controlData;
BOOL ssidChangeInProgress;
int pagesNumber;
@interface SettingsMenu ()

- (void)refresh;
- (BOOL)textFieldShouldReturn:(UITextField *)theTextField;
- (void)saveForDebugSettings;
@end

@implementation SettingsMenu

@synthesize pagesArray;
@synthesize pagesArrayTitle;

- (id)initWithFrame:(CGRect)frame AndHUDConfiguration:(ARDroneHUDConfiguration)configuration withDelegate:(id <SettingsMenuDelegate>)delegate
{
	NSLog(@"SettingsMenu frame => w : %f, h : %f", frame.size.width, frame.size.height);
	NSString *settingsNibName = nil;
	
    settingsNibName = [NSString stringWithFormat:@"SettingsMenu%@-%@", (IS_ARDRONE2 ? @"2" : @""), ((UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) ? @"iPad" : @"iPhone")];

    self = [super initWithNibName:settingsNibName bundle:nil];
    NSLog(@"%@", settingsNibName);
	if(self)
	{
		ssidChangeInProgress = NO;
		_delegate = delegate;
        pagesNumber = 0;
        self.pagesArray = [NSMutableArray array];
        self.pagesArrayTitle = [NSMutableArray array];
	}
	
	return self;
}

- (void) viewDidLoad
{
    [super viewDidLoad];
    
    /* Mandatory :
     * Let the linker know that ARSlider class can't be optimized away
     */
    [ARSlider class];
    
    [droneSSIDTextField.layer setBorderWidth:2.f];
    [droneSSIDTextField.layer setBorderColor:ORANGE(1.f).CGColor];
    
    [pagesArray addObject:personalSettingsPage];
    [pagesArrayTitle addObject:ARDroneEngineLocalizeString(@"PERSONAL SETTINGS")];
    [pagesArray addObject:flightSettingsPage];
    [pagesArrayTitle addObject:ARDroneEngineLocalizeString(@"FLIGHT SETTINGS")];
    [pagesArray addObject:pilotingModePage];
    [pagesArrayTitle addObject:ARDroneEngineLocalizeString(@"PILOTING MODE")];
    if (IS_ARDRONE1) 
    {
        [pagesArray addObject:videoSettingsPage];
        [pagesArrayTitle addObject:ARDroneEngineLocalizeString(@"VIDEO SETTINGS")];
    }
    [pagesArray addObject:statusPage];
    [pagesArrayTitle addObject:ARDroneEngineLocalizeString(@"STATUS")];

#ifdef INTERFACE_WITH_DEBUG
    [pagesArray addObject:debugPage];
    [pagesArrayTitle addObject:@"DEBUG"];
#endif
    pagesNumber = pagesArray.count;

    CGFloat x = 0.f;
    for (UIView *page in pagesArray)
    {
        CGRect frame = page.frame;
        frame.origin.x = x;
        [page setFrame:frame];
        [scrollView addSubview:page];
        x += page.frame.size.width;
    }
    [scrollView setContentSize:CGSizeMake(x, scrollView.frame.size.height)];
    
    [pageControl setNumberOfPages:pagesNumber];
    [pageControl setCurrentPage:0];
    
    altitudeLimitedSlider.minimumValue = ALTITUDE_LIMITED_MIN / 1000.;
    altitudeLimitedSlider.maximumValue = ALTITUDE_LIMITED_MAX / 1000.;
    
    softwareVersion.text	= [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"];
    appNameLabel.text = [[[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleDisplayName"] uppercaseString];
    
    // Default page
    viewTitleLabel.text = ARDroneEngineLocalizeString(@"PERSONAL SETTINGS");
    
    [clearButton setTitle:ARDroneEngineLocalizeString(@"DEFAULT SETTINGS") forState:UIControlStateNormal];
    [flatTrimButton setTitle:ARDroneEngineLocalizeString(@"FLAT TRIM") forState:UIControlStateNormal];
    
    pairingText.text = ARDroneEngineLocalizeString(@"PAIRING");
    droneSSIDText.text = ARDroneEngineLocalizeString(@"AR.DRONE NETWORK NAME");
    interfaceAlphaText.text = ARDroneEngineLocalizeString(@"INTERFACE OPACITY");
    videoRecordOnUSBText.text = ARDroneEngineLocalizeString(@"USB RECORD");
    loopingEnabledLabel.text = ARDroneEngineLocalizeString(@"FLIP ENABLED");
    
    altitudeLimitedText.text = ARDroneEngineLocalizeString(@"ALTITUDE LIMIT");
    verticalSpeedText.text = ARDroneEngineLocalizeString(@"VERTICAL SPEED MAX");
    yawSpeedText.text = ARDroneEngineLocalizeString(@"ROTATION SPEED MAX");
    droneTiltText.text = ARDroneEngineLocalizeString(@"TILT ANGLE MAX");
    outdoorShellText.text = ARDroneEngineLocalizeString(@"OUTDOOR HULL");
    outdoorFlightText.text = ARDroneEngineLocalizeString(@"OUTDOOR FLIGHT");
    
    acceleroDisabledText.text = ARDroneEngineLocalizeString(@"JOYPAD MODE");
    magnetoText.text = ARDroneEngineLocalizeString(@"ABSOLUTE CONTROL");
    [magnetoCalibButton setTitle:ARDroneEngineLocalizeString(@"CALIBRATION") forState:UIControlStateNormal];
    leftHandedText.text = ARDroneEngineLocalizeString(@"LEFT-HANDED");
    iPhoneTiltText.text = [NSString stringWithFormat:ARDroneEngineLocalizeString(@"%@ TILT MAX"), [[[UIDevice currentDevice] model] uppercaseString]];
    
    softwareVersionText.text = ARDroneEngineLocalizeString(@"Version");
    droneHardVersionText.text = ARDroneEngineLocalizeString(@"Hardware");
    droneSoftVersionText.text = ARDroneEngineLocalizeString(@"Software");
    dronePicVersionText.text = ARDroneEngineLocalizeString(@"INERTIAL");
    droneMotorVersionsText.text = ARDroneEngineLocalizeString(@"MOTORS VERSIONS");
    dronePicHardVersionText.text = ARDroneEngineLocalizeString(@"Hardware");
    dronePicSoftVersionText.text = ARDroneEngineLocalizeString(@"Software");
    droneMotor1HardVersionText.text = ARDroneEngineLocalizeString(@"Hardware");
    droneMotor1SoftVersionText.text = ARDroneEngineLocalizeString(@"Software");
    droneMotor1SupplierVersionText.text = ARDroneEngineLocalizeString(@"Type");
    droneMotor1Text.text = [NSString stringWithFormat:ARDroneEngineLocalizeString(@"MOTOR %d"), 1];
    droneMotor2HardVersionText.text = ARDroneEngineLocalizeString(@"Hardware");
    droneMotor2SoftVersionText.text = ARDroneEngineLocalizeString(@"Software");
    droneMotor2SupplierVersionText.text = ARDroneEngineLocalizeString(@"Type");
    droneMotor2Text.text = [NSString stringWithFormat:ARDroneEngineLocalizeString(@"MOTOR %d"), 2];
    droneMotor3HardVersionText.text = ARDroneEngineLocalizeString(@"Hardware");
    droneMotor3SoftVersionText.text = ARDroneEngineLocalizeString(@"Software");
    droneMotor3SupplierVersionText.text = ARDroneEngineLocalizeString(@"Type");
    droneMotor3Text.text = [NSString stringWithFormat:ARDroneEngineLocalizeString(@"MOTOR %d"), 3];
    droneMotor4HardVersionText.text = ARDroneEngineLocalizeString(@"Hardware");
    droneMotor4SoftVersionText.text = ARDroneEngineLocalizeString(@"Software");
    droneMotor4SupplierVersionText.text = ARDroneEngineLocalizeString(@"Type");
    droneMotor4Text.text = [NSString stringWithFormat:ARDroneEngineLocalizeString(@"MOTOR %d"), 4];
    adaptiveVideoText.text = ARDroneEngineLocalizeString(@"ADAPTATIVE VIDEO");
    videoCodecText.text = ARDroneEngineLocalizeString(@"VIDEO CODEC");
    
	[previous setHidden:YES];


#ifdef INTERFACE_WITH_DEBUG
    [self setSwitch:logsSwitch withValue:NO];
#if USE_THREAD_PRIORITIES
    // Display fields
    videoThreadPriorityCurrentLabel.hidden = NO;
    videoThreadPrioritySlider.hidden = NO;
    videoThreadPriorityText.hidden = NO;
    videoThreadPrioritySlider.value = VIDEO_THREAD_PRIORITY;
    videoThreadPriorityCurrentLabel.text = [NSString stringWithFormat:@"%d", VIDEO_THREAD_PRIORITY];

    atThreadPriorityCurrentLabel.hidden = NO;
    atThreadPrioritySlider.hidden = NO;
    atThreadPriorityText.hidden = NO;
    atThreadPrioritySlider.value = AT_THREAD_PRIORITY;
    atThreadPriorityCurrentLabel.text = [NSString stringWithFormat:@"%d", AT_THREAD_PRIORITY];
#endif
#endif
    [self loadIPhoneSettings];
    [self refresh];
}

- (void)scrollViewDidScroll:(UIScrollView *)_scrollView
{
	int currentPage = (int) (scrollView.contentOffset.x + .5f * scrollView.frame.size.width) / scrollView.frame.size.width;
	
    if (currentPage == 0)
    {
        [previous setHidden:YES];
        [next setHidden:NO];
    }
    else if (currentPage == (pagesNumber - 1))
    {
        [previous setHidden:NO];
        [next setHidden:YES];
    }
    else if (currentPage >= pagesNumber)
    {
        currentPage = pagesNumber - 1;
        [previous setHidden:NO];
        [next setHidden:YES];
    }
    else
    {
        [previous setHidden:NO];
        [next setHidden:NO];
    }
    
    [pageControl setCurrentPage:currentPage];
    [viewTitleLabel setText:[pagesArrayTitle objectAtIndex:currentPage]];
}

- (void)checkDisplay
{
	BOOL enabled = (ctrldata.navdata_connected) ? YES : NO;
    
	float alpha = (ctrldata.navdata_connected) ? 1.0 : 0.5;
	
#ifdef INTERFACE_WITH_DEBUG
	logsSwitch.enabled = enabled;
	logsSwitch.alpha = alpha;
#endif
    
    if(IS_ARDRONE2)
    {
        videoRecordOnUSBSwitch.enabled = enabled;
        videoRecordOnUSBSwitch.alpha = alpha;
    }
    
	adaptiveVideoSwitch.enabled = acceleroDisabledSwitch.enabled = leftHandedSwitch.enabled = videoCodecSwitch.enabled = enabled;
	adaptiveVideoSwitch.alpha = acceleroDisabledSwitch.alpha = leftHandedSwitch.alpha = videoCodecSwitch.alpha = alpha;
    if([CLLocationManager headingAvailable])
    {
        magnetoSwitch.enabled = enabled;
        magnetoSwitch.alpha = alpha;
    }
	pairingSwitch.enabled = enabled;
	pairingSwitch.alpha = alpha;
	outdoorFlightSwitch.enabled = outdoorShellSwitch.enabled = enabled;
	outdoorFlightSwitch.alpha = outdoorShellSwitch.alpha = alpha;
	droneSSIDTextField.enabled = enabled;
	droneSSIDTextField.alpha = alpha;
	altitudeLimitedSlider.enabled = droneTiltSlider.enabled = iPhoneTiltSlider.enabled = verticalSpeedSlider.enabled = yawSpeedSlider.enabled = enabled;
	altitudeLimitedSlider.alpha = droneTiltSlider.alpha = iPhoneTiltSlider.alpha = verticalSpeedSlider.alpha = yawSpeedSlider.alpha = alpha;
	clearButton.enabled = enabled;
	clearButton.alpha = alpha;
	
    [flatTrimButton setEnabled:(!flyingState && enabled)];
    [flatTrimButton setAlpha:(!flyingState && enabled) ? 1.0 : 0.5];
    
    if(IS_ARDRONE2)
    {
        magnetoCalibButton.enabled = (flyingState && enabled);
        magnetoCalibButton.alpha = (flyingState && enabled) ? 1.0 : 0.5;
    }
}

- (void)setFlyingState:(NSNumber *)_flyingState
{
    flyingState = [_flyingState boolValue];
    [self checkDisplay];
}

- (void)configChanged
{
    [self checkDisplay];
	
    [self setSwitch:pairingSwitch withValue:(strcmp(ardrone_control_config.owner_mac, NULL_MAC) != 0 ? YES : NO)];
    [self setSwitch:outdoorFlightSwitch withValue:(ardrone_control_config.outdoor ? YES : NO)];
    [self setSwitch:outdoorShellSwitch withValue:(ardrone_control_config.flight_without_shell ? YES : NO)];
    droneTiltSlider.value = ardrone_control_config.euler_angle_max * RAD_TO_DEG;
	altitudeLimitedSlider.value = ardrone_control_config.altitude_max / 1000.;
	iPhoneTiltSlider.value = ardrone_control_config.control_iphone_tilt * RAD_TO_DEG;
	verticalSpeedSlider.value = ardrone_control_config.control_vz_max;
	yawSpeedSlider.value = ardrone_control_config.control_yaw * RAD_TO_DEG;
    [self setSwitch:adaptiveVideoSwitch withValue:((ARDRONE_VARIABLE_BITRATE_MODE_DYNAMIC == ardrone_control_config.bitrate_ctrl_mode) ? YES : NO)];
   
    if(IS_ARDRONE2)
    {
        [self setSwitch:videoRecordOnUSBSwitch withValue:(ardrone_control_config.video_on_usb ? YES : NO)];
    }
    
    // Refresh the codec switch button
    int segment = 0;
    if (IS_ARDRONE2)
    {
        switch (ardrone_control_config.video_codec)
        {
            case ARDRONE_VIDEO_CODEC_MP4_360P_H264_720P:
                segment = 0;
                break;
            case ARDRONE_VIDEO_CODEC_H264_360P:
                segment = 1;
                break;
            case ARDRONE_VIDEO_CODEC_H264_720P:
                segment = 2;
                break;
            default:
                segment = 0;
                break;
        }
    }
    else
    {
        switch (ardrone_control_config.video_codec)
        {
            case ARDRONE_VIDEO_CODEC_UVLC:
                segment = 0;
                break;
                
            case ARDRONE_VIDEO_CODEC_P264:
                segment = 1;
                break;
                
            default:
                segment = 1;
                break;
        }
    }
    
    if (videoCodecSwitch.selectedSegmentIndex != segment)
    {
        // The removeTarget/addTarget is needed on all iOS before 5.0
        // -> Remove if iOS minimum version is set to 5.0
        [videoCodecSwitch removeTarget:self action:@selector(valueChanged:) forControlEvents:UIControlEventValueChanged];
        videoCodecSwitch.selectedSegmentIndex = segment;
        [videoCodecSwitch addTarget:self action:@selector(valueChanged:) forControlEvents:UIControlEventValueChanged];
    }
	
	// Update SSID AR.Drone network
	if(!ssidChangeInProgress && (strcmp(ardrone_control_config.ssid_single_player, "") != 0))
		droneSSIDTextField.text = [NSString stringWithCString:ardrone_control_config.ssid_single_player encoding:NSUTF8StringEncoding];
	
	// Update pic version number
	if(ardrone_control_config.pic_version != 0)
	{
        uint32_t hard_major = (ardrone_control_config.pic_version >> 27) + 1;
        uint32_t hard_minor = (ardrone_control_config.pic_version >> 24) & 0x7;
		dronePicHardVersion.text = [NSString stringWithFormat:@"%x.%x", hard_major, hard_minor];
		dronePicSoftVersion.text = [NSString stringWithFormat:@"%d.%d", (int)((ardrone_control_config.pic_version & 0xFFFFFF) >> 16),(int)(ardrone_control_config.pic_version & 0xFFFF)];
	}
	else
	{
		dronePicHardVersion.text = @"none";
		dronePicSoftVersion.text = @"none";
	}
	
	// update AR.Drone software version 
	if(strcmp(ardrone_control_config.num_version_soft, "") != 0)
		droneSoftVersion.text = [NSString stringWithFormat:@"%s", ardrone_control_config.num_version_soft];
	else
		droneSoftVersion.text = @"none";
	
	// update AR.Drone hardware version 
	if(ardrone_control_config.num_version_mb != 0)
		droneHardVersion.text = [NSString stringWithFormat:@"%x.%x", ardrone_control_config.num_version_mb >> 4, ardrone_control_config.num_version_mb & 0x0f];
	else
		droneHardVersion.text = @"none";

	// Update motor 1 version (soft / hard / supplier)
	if(strcmp(ardrone_control_config.motor1_soft, "") != 0)
		droneMotor1SoftVersion.text = [NSString stringWithFormat:@"%s", ardrone_control_config.motor1_soft];
	else
		droneMotor1SoftVersion.text = [NSString stringWithString:@"none"];

	if(strcmp(ardrone_control_config.motor1_hard, "") != 0)
		droneMotor1HardVersion.text = [NSString stringWithFormat:@"%s", ardrone_control_config.motor1_hard];
	else
		droneMotor1HardVersion.text = [NSString stringWithString:@"none"];
	
	if(strcmp(ardrone_control_config.motor1_supplier, "") != 0)
		droneMotor1SupplierVersion.text = [NSString stringWithFormat:@"%s", ardrone_control_config.motor1_supplier];
	else
		droneMotor1SupplierVersion.text = [NSString stringWithString:@"none"];
	
	// Update motor 2 version (soft / hard / supplier)
	if(strcmp(ardrone_control_config.motor2_soft, "") != 0)
		droneMotor2SoftVersion.text = [NSString stringWithFormat:@"%s", ardrone_control_config.motor2_soft];
	else
		droneMotor2SoftVersion.text = [NSString stringWithString:@"none"];
	
	if(strcmp(ardrone_control_config.motor2_hard, "") != 0)
		droneMotor2HardVersion.text = [NSString stringWithFormat:@"%s", ardrone_control_config.motor2_hard];
	else
		droneMotor2HardVersion.text = [NSString stringWithString:@"none"];
	
	if(strcmp(ardrone_control_config.motor2_supplier, "") != 0)
		droneMotor2SupplierVersion.text = [NSString stringWithFormat:@"%s", ardrone_control_config.motor2_supplier];
	else
		droneMotor2SupplierVersion.text = [NSString stringWithString:@"none"];
	
	// Update motor 3 version (soft / hard / supplier)
	if(strcmp(ardrone_control_config.motor3_soft, "") != 0)
		droneMotor3SoftVersion.text = [NSString stringWithFormat:@"%s", ardrone_control_config.motor3_soft];
	else
		droneMotor3SoftVersion.text = [NSString stringWithString:@"none"];
	
	if(strcmp(ardrone_control_config.motor3_hard, "") != 0)
		droneMotor3HardVersion.text = [NSString stringWithFormat:@"%s", ardrone_control_config.motor3_hard];
	else
		droneMotor3HardVersion.text = [NSString stringWithString:@"none"];
	
	if(strcmp(ardrone_control_config.motor3_supplier, "") != 0)
		droneMotor3SupplierVersion.text = [NSString stringWithFormat:@"%s", ardrone_control_config.motor3_supplier];
	else
		droneMotor3SupplierVersion.text = [NSString stringWithString:@"none"];
	
	// Update motor 4 version (soft / hard / supplier)
	if(strcmp(ardrone_control_config.motor4_soft, "") != 0)
		droneMotor4SoftVersion.text = [NSString stringWithFormat:@"%s", ardrone_control_config.motor4_soft];
	else
		droneMotor4SoftVersion.text = [NSString stringWithString:@"none"];
	
	if(strcmp(ardrone_control_config.motor4_hard, "") != 0)
		droneMotor4HardVersion.text = [NSString stringWithFormat:@"%s", ardrone_control_config.motor4_hard];
	else
		droneMotor4HardVersion.text = [NSString stringWithString:@"none"];
	
	if(strcmp(ardrone_control_config.motor4_supplier, "") != 0)
		droneMotor4SupplierVersion.text = [NSString stringWithFormat:@"%s", ardrone_control_config.motor4_supplier];
	else
		droneMotor4SupplierVersion.text = [NSString stringWithString:@"none"];

	if(ctrldata.navdata_connected)
	{
		outdoorFlightSwitch.enabled = YES;
		outdoorFlightSwitch.alpha = 1.0;
	}
	
	[self refresh];
}

- (void)refresh
{
#ifdef INTERFACE_WITH_DEBUG
	if(logsSwitch.tag == SWITCH_CHECKED)
	{
		clearLogsButton.enabled = NO;
		clearLogsButton.alpha = 0.50;
	}
	else 
	{
		clearLogsButton.enabled = YES;
		clearLogsButton.alpha = 1.0;
	}
#endif
	    
	yawSpeedCurrentLabel.text = [NSString stringWithFormat:@"%0.2f %@", yawSpeedSlider.value, ARDroneEngineLocalizeString(@"°/s")];
	verticalSpeedCurrentLabel.text = [NSString stringWithFormat:@"%0.1f %@", verticalSpeedSlider.value, ARDroneEngineLocalizeString(@"mm/s")];
	droneTiltCurrentLabel.text = [NSString stringWithFormat:@"%0.2f %@", droneTiltSlider.value, ARDroneEngineLocalizeString(@"°")];
	altitudeLimitedCurrentLabel.text = [NSString stringWithFormat:@"%d %@", (int)(altitudeLimitedSlider.value), ARDroneEngineLocalizeString(@"m")];
	iPhoneTiltCurrentLabel.text = [NSString stringWithFormat:@"%0.2f %@", iPhoneTiltSlider.value, ARDroneEngineLocalizeString(@"°")];
	interfaceAlphaCurrentLabel.text = [NSString stringWithFormat:@"%d %%", (int)interfaceAlphaSlider.value];
    // Debug
    cocardeRangeCurrent.text = [NSString stringWithFormat:@"%.2f %@", cocardeRangeSlider.value, ARDroneEngineLocalizeString(@"m")];
#if USE_THREAD_PRIORITIES
    videoThreadPriorityCurrentLabel.text = [NSString stringWithFormat:@"%d", (int)videoThreadPrioritySlider.value];
    atThreadPriorityCurrentLabel.text = [NSString stringWithFormat:@"%d", (int)atThreadPrioritySlider.value];
#endif
}

- (IBAction)switchClick:(id)sender
{
    if(sender == magnetoSwitch)
    {
        if([CLLocationManager locationServicesEnabled])
        {
            [self toggleSwitch:sender];
            [_delegate magnetoValueChanged:(magnetoSwitch.tag == SWITCH_CHECKED)];
            [self saveIPhoneSettings];
        }
        else
        {
            UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:ARDroneEngineLocalizeString(@"Location Services Disabled") 
                                                                message:ARDroneEngineLocalizeString(@"You need to enable this service to use absolute control.")
                                                               delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil, nil];
            [alertView show];
            [alertView release];
        }
    }
    else
    {
    [self toggleSwitch:sender];
    if(sender == acceleroDisabledSwitch)
    {
        [_delegate acceleroValueChanged:(acceleroDisabledSwitch.tag == SWITCH_UNCHECKED)];
        [self saveIPhoneSettings];
    }
    else if(sender == leftHandedSwitch)
    {
        [_delegate controlModeChanged:(leftHandedSwitch.tag == SWITCH_CHECKED) ? CONTROL_MODE2 : CONTROL_MODE3];
        [self saveIPhoneSettings];
    }
    else if(sender == pairingSwitch)
    {
        strcpy(ardrone_control_config.owner_mac, (pairingSwitch.tag == SWITCH_CHECKED) ? iphone_mac_address : NULL_MAC);
        ARDRONE_TOOL_CONFIGURATION_ADDEVENT(owner_mac, ardrone_control_config.owner_mac, NULL);
    }
    else if(sender == outdoorFlightSwitch)
    {
        bool_t enabled = (outdoorFlightSwitch.tag == SWITCH_CHECKED);
        ardrone_control_config.outdoor = enabled;
        ARDRONE_TOOL_CONFIGURATION_ADDEVENT(outdoor, &ardrone_control_config.outdoor, NULL);
        outdoorFlightSwitch.enabled = NO;
        outdoorFlightSwitch.alpha = 0.5;
        [MainViewController getConfiguration];
    }
    else if(sender == outdoorShellSwitch)
    {
        bool_t enabled = (outdoorShellSwitch.tag == SWITCH_CHECKED);
        ardrone_control_config.flight_without_shell = enabled;
        ARDRONE_TOOL_CONFIGURATION_ADDEVENT(flight_without_shell, &ardrone_control_config.flight_without_shell, NULL);
    }
    else if(sender == adaptiveVideoSwitch)
    {
        if (IS_ARDRONE2)
        {
            ARDRONE_VARIABLE_BITRATE enabled = (adaptiveVideoSwitch.tag == SWITCH_CHECKED) ? ARDRONE_VARIABLE_BITRATE_MODE_DYNAMIC : ARDRONE_VARIABLE_BITRATE_MODE_DISABLED;
            ardrone_control_config.bitrate_ctrl_mode = enabled;
            ARDRONE_TOOL_CONFIGURATION_ADDEVENT(bitrate_ctrl_mode, &ardrone_control_config.bitrate_ctrl_mode, NULL);
        }
        else
        {
            ARDRONE_VARIABLE_BITRATE enabled = (adaptiveVideoSwitch.tag == SWITCH_CHECKED) ? ARDRONE_VARIABLE_BITRATE_MODE_DYNAMIC : ARDRONE_VARIABLE_BITRATE_MANUAL;
            uint32_t constantBitrate = (ARDRONE_VIDEO_CODEC_UVLC == ardrone_control_config.video_codec) ? 20000 : 15000;
            ardrone_control_config.bitrate_ctrl_mode = enabled;
            ardrone_control_config.bitrate = constantBitrate;
            ARDRONE_TOOL_CONFIGURATION_ADDEVENT(bitrate_ctrl_mode, &ardrone_control_config.bitrate_ctrl_mode, NULL);
            ARDRONE_TOOL_CONFIGURATION_ADDEVENT(bitrate, &ardrone_control_config.bitrate, NULL);
        }
    }
    else if(IS_ARDRONE2 && (sender == videoRecordOnUSBSwitch))
    {
        ardrone_control_config.video_on_usb = (videoRecordOnUSBSwitch.tag == SWITCH_CHECKED) ? TRUE : FALSE;
        ARDRONE_TOOL_CONFIGURATION_ADDEVENT(video_on_usb, &ardrone_control_config.video_on_usb, NULL);
    }
    else if(IS_ARDRONE2 && (sender == enableLoopingSwitch))
    {
        [_delegate loopingActiveValueChanged:(bool_t)(SWITCH_CHECKED == enableLoopingSwitch.tag)];
        [self saveIPhoneSettings];
    }
    else
    {
        [self refresh];
    }
}
}

- (IBAction)valueChanged:(id)sender
{
    if(sender == videoCodecSwitch)
    {
        if (IS_ARDRONE2)
        {
            ARDRONE_VIDEO_CODEC _codec = ARDRONE_VIDEO_CODEC_MP4_360P;
            switch (videoCodecSwitch.selectedSegmentIndex)
            {
                case 0:
                    _codec = ARDRONE_VIDEO_CODEC_MP4_360P_H264_720P;
                    break;
                case 1:
                    _codec = ARDRONE_VIDEO_CODEC_H264_360P;
                    break;
                case 2:
                    _codec = ARDRONE_VIDEO_CODEC_H264_720P;
                    break;
                default:
                    break;
            }
            ardrone_control_config.video_codec = _codec;
            ARDRONE_TOOL_CONFIGURATION_ADDEVENT(video_codec, &ardrone_control_config.video_codec, NULL);
        }
        else
        {
            ARDRONE_VIDEO_CODEC _codec = (videoCodecSwitch.selectedSegmentIndex == 0) ? ARDRONE_VIDEO_CODEC_UVLC : ARDRONE_VIDEO_CODEC_P264;
            ardrone_control_config.video_codec = _codec;
            ARDRONE_TOOL_CONFIGURATION_ADDEVENT(video_codec, &ardrone_control_config.video_codec, NULL);
            ardrone_control_config.bitrate = (ARDRONE_VIDEO_CODEC_UVLC == ardrone_control_config.video_codec) ? 20000 : 15000;
            ARDRONE_TOOL_CONFIGURATION_ADDEVENT(bitrate, &ardrone_control_config.bitrate, NULL);
        }
    }
	else
	{
		[self refresh];		
	}
}

- (IBAction)sliderRelease:(id)sender
{
	if(sender == droneTiltSlider)
	{
		float value = droneTiltSlider.value;
		ardrone_control_config.euler_angle_max = value * DEG_TO_RAD;
		ARDRONE_TOOL_CONFIGURATION_ADDEVENT(euler_angle_max, &ardrone_control_config.euler_angle_max, NULL);
	}
	else if(sender == altitudeLimitedSlider)
	{
		float value = (float)(((int)altitudeLimitedSlider.value) * 1000);
		ardrone_control_config.altitude_max = value;
		ARDRONE_TOOL_CONFIGURATION_ADDEVENT(altitude_max, &ardrone_control_config.altitude_max, NULL);
	}
	else if(sender == iPhoneTiltSlider)
	{
		float value = iPhoneTiltSlider.value;
		ardrone_control_config.control_iphone_tilt = value * DEG_TO_RAD;
		ARDRONE_TOOL_CONFIGURATION_ADDEVENT(control_iphone_tilt, &ardrone_control_config.control_iphone_tilt, NULL);
	}
	else if(sender == verticalSpeedSlider)
	{
		float value = verticalSpeedSlider.value;
		ardrone_control_config.control_vz_max = value;
		ARDRONE_TOOL_CONFIGURATION_ADDEVENT(control_vz_max, &ardrone_control_config.control_vz_max, NULL);
	}
	else if(sender == yawSpeedSlider)
	{
		float value = yawSpeedSlider.value;
		ardrone_control_config.control_yaw = value * DEG_TO_RAD;
		ARDRONE_TOOL_CONFIGURATION_ADDEVENT(control_yaw, &ardrone_control_config.control_yaw, NULL);
	}
	else if(sender == interfaceAlphaSlider)
	{
		CGFloat value = interfaceAlphaSlider.value / 100.0f;
		[_delegate interfaceAlphaValueChanged:value];
		[self saveIPhoneSettings];
	}
    // Debug slider
    else if(sender == cocardeRangeSlider)
	{
		int value = (int)(cocardeRangeSlider.value * 1000.0);
		ardrone_control_config.hovering_range = value;
		ARDRONE_TOOL_CONFIGURATION_ADDEVENT(hovering_range, &ardrone_control_config.hovering_range, NULL);
	}
#if USE_THREAD_PRIORITIES
    else if(sender == videoThreadPrioritySlider)
	{
        CHANGE_THREAD_PRIO (mobile_main, (int)videoThreadPrioritySlider.value);
	}
    else if(sender == atThreadPrioritySlider)
	{
        CHANGE_THREAD_PRIO (mobile_main, (int)atThreadPrioritySlider.value);
	}
#endif
}

#ifdef INTERFACE_WITH_DEBUG
- (void) checkLogsEnable
{
    bool_t b_refresh = FALSE;
    switch(logs_state)
    {
        case LOGS_STATE_INIT:
            [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(checkLogsEnable) userInfo:nil repeats:NO];
            break;
            
        case LOGS_STATE_SUCCESS:
            navdata_write_to_file(logsSwitch.tag == SWITCH_CHECKED);
            b_refresh = TRUE;
            break;
            
        case LOGS_STATE_FAILURE:
            [self toggleSwitch:logsSwitch];
            b_refresh = TRUE;
            break;
            
        default:
            break;
    }

    if(b_refresh)
    {
     	logsSwitch.enabled = YES;
        logsSwitch.alpha = 1.0;
        [self refresh];
    }
}
#endif

- (IBAction)logsChanged:(id)sender
{
#ifdef INTERFACE_WITH_DEBUG
    [self toggleSwitch:sender];
	bool_t b_value;
    
	if(logsSwitch.tag == SWITCH_CHECKED)
		[self saveForDebugSettings];
    
	b_value = (logsSwitch.tag == SWITCH_UNCHECKED);
	
    // Missing callback to wait navdata demo is active.
    logs_state = LOGS_STATE_INIT;
	logsSwitch.enabled = NO;
	logsSwitch.alpha = 0.5;
    ARDRONE_TOOL_CONFIGURATION_ADDEVENT(navdata_demo, &b_value, logs_navdata_demo);

    [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(checkLogsEnable) userInfo:nil repeats:NO];
#endif
}

- (void)clearSettings
{
//	NSLog(@"%s", __FUNCTION__);
	ardrone_control_config.indoor_euler_angle_max = ardrone_application_default_config.indoor_euler_angle_max;
	ARDRONE_TOOL_CONFIGURATION_ADDEVENT(indoor_euler_angle_max, &ardrone_control_config.indoor_euler_angle_max, NULL);

	ardrone_control_config.indoor_control_vz_max = ardrone_application_default_config.indoor_control_vz_max;
	ARDRONE_TOOL_CONFIGURATION_ADDEVENT(indoor_control_vz_max, &ardrone_control_config.indoor_control_vz_max, NULL);
	
	ardrone_control_config.indoor_control_yaw = ardrone_application_default_config.indoor_control_yaw;
	ARDRONE_TOOL_CONFIGURATION_ADDEVENT(indoor_control_yaw, &ardrone_control_config.indoor_control_yaw, NULL);
	
	ardrone_control_config.outdoor_euler_angle_max = ardrone_application_default_config.outdoor_euler_angle_max;
	ARDRONE_TOOL_CONFIGURATION_ADDEVENT(outdoor_euler_angle_max, &ardrone_control_config.outdoor_euler_angle_max, NULL);
	
	ardrone_control_config.outdoor_control_vz_max = ardrone_application_default_config.outdoor_control_vz_max;
	ARDRONE_TOOL_CONFIGURATION_ADDEVENT(outdoor_control_vz_max, &ardrone_control_config.outdoor_control_vz_max, NULL);
	
	ardrone_control_config.outdoor_control_yaw = ardrone_application_default_config.outdoor_control_yaw;
	ARDRONE_TOOL_CONFIGURATION_ADDEVENT(outdoor_control_yaw, &ardrone_control_config.outdoor_control_yaw, NULL);
	
	ardrone_control_config.outdoor = ardrone_application_default_config.outdoor;
    [self setSwitch:outdoorFlightSwitch withValue:(ardrone_control_config.outdoor ? YES : NO)];
	ARDRONE_TOOL_CONFIGURATION_ADDEVENT(outdoor, &ardrone_control_config.outdoor, NULL);
	
	ardrone_control_config.euler_angle_max = ardrone_application_default_config.euler_angle_max;
	droneTiltSlider.value = ardrone_control_config.euler_angle_max * RAD_TO_DEG;
	ARDRONE_TOOL_CONFIGURATION_ADDEVENT(euler_angle_max, &ardrone_control_config.euler_angle_max, NULL);
	
	ardrone_control_config.altitude_max = ardrone_application_default_config.altitude_max;
	altitudeLimitedSlider.value = ardrone_control_config.altitude_max / 1000;
	ARDRONE_TOOL_CONFIGURATION_ADDEVENT(altitude_max, &ardrone_control_config.altitude_max, NULL);
    
    ardrone_control_config.control_vz_max = ardrone_application_default_config.control_vz_max;
	verticalSpeedSlider.value = ardrone_control_config.control_vz_max;
	ARDRONE_TOOL_CONFIGURATION_ADDEVENT(control_vz_max, &ardrone_control_config.control_vz_max, NULL);
	
	ardrone_control_config.control_yaw = ardrone_application_default_config.control_yaw;
	yawSpeedSlider.value = ardrone_control_config.control_yaw * RAD_TO_DEG;
	ARDRONE_TOOL_CONFIGURATION_ADDEVENT(control_yaw, &ardrone_control_config.control_yaw, NULL);
	
	ardrone_control_config.outdoor_euler_angle_max = ardrone_application_default_config.outdoor_euler_angle_max;
	droneTiltSlider.value = ardrone_control_config.euler_angle_max * RAD_TO_DEG;
	ARDRONE_TOOL_CONFIGURATION_ADDEVENT(euler_angle_max, &ardrone_control_config.euler_angle_max, NULL);
	
	ardrone_control_config.control_vz_max = ardrone_application_default_config.control_vz_max;
	verticalSpeedSlider.value = ardrone_control_config.control_vz_max;
	ARDRONE_TOOL_CONFIGURATION_ADDEVENT(control_vz_max, &ardrone_control_config.control_vz_max, NULL);
	
	ardrone_control_config.control_yaw = ardrone_application_default_config.control_yaw;
	yawSpeedSlider.value = ardrone_control_config.control_yaw * RAD_TO_DEG;
	ARDRONE_TOOL_CONFIGURATION_ADDEVENT(control_yaw, &ardrone_control_config.control_yaw, NULL);

	ardrone_control_config.control_iphone_tilt = ardrone_application_default_config.control_iphone_tilt;
	iPhoneTiltSlider.value = ardrone_control_config.control_iphone_tilt * RAD_TO_DEG;
	ARDRONE_TOOL_CONFIGURATION_ADDEVENT(control_iphone_tilt, &ardrone_control_config.control_iphone_tilt, NULL);
	
	ardrone_control_config.flight_without_shell = ardrone_application_default_config.flight_without_shell;
    [self setSwitch:outdoorShellSwitch withValue:(ardrone_control_config.flight_without_shell ? YES : NO)];
	ARDRONE_TOOL_CONFIGURATION_ADDEVENT(flight_without_shell, &ardrone_control_config.flight_without_shell, NULL);
    
    ardrone_control_config.video_codec = ardrone_application_default_config.video_codec;
    videoCodecSwitch.selectedSegmentIndex = (ARDRONE_VIDEO_CODEC_UVLC == ardrone_control_config.video_codec) ? 0 : 1;
    ARDRONE_TOOL_CONFIGURATION_ADDEVENT(video_codec, &ardrone_control_config.video_codec, NULL);

	ardrone_control_config.bitrate_ctrl_mode = ardrone_application_default_config.bitrate_ctrl_mode;
    [self setSwitch:adaptiveVideoSwitch withValue:(ardrone_control_config.bitrate_ctrl_mode ? YES : NO)];
	ARDRONE_TOOL_CONFIGURATION_ADDEVENT(bitrate_ctrl_mode, &ardrone_control_config.bitrate_ctrl_mode, NULL);
	
     ardrone_control_config.video_on_usb = ardrone_application_default_config.video_on_usb;
    [self setSwitch:videoRecordOnUSBSwitch withValue:ardrone_control_config.video_on_usb ? YES : NO];
	ARDRONE_TOOL_CONFIGURATION_ADDEVENT(bitrate_ctrl_mode, &ardrone_control_config.bitrate_ctrl_mode, NULL);
    
	[self setSwitch:acceleroDisabledSwitch withValue:NO];
	[_delegate acceleroValueChanged:YES];

	[self setSwitch:magnetoSwitch withValue:NO];
	[_delegate magnetoValueChanged:NO];
    
	[self setSwitch:leftHandedSwitch withValue:NO];
	[_delegate controlModeChanged:CONTROL_MODE3];
	
	interfaceAlphaSlider.value = 50.0;
	[_delegate interfaceAlphaValueChanged: (interfaceAlphaSlider.value / 100.0)];

	[self saveIPhoneSettings];
	
	[self refresh];
}

- (IBAction)buttonClick:(id)sender
{
    if(sender == okButton)
    {
        self.view.hidden = YES;        
    }
    else if(sender == flatTrimButton)
    {
        ardrone_at_set_flat_trim();        
    }
    else if(sender == clearButton)
    {
        [self clearSettings];
    }
    else if(sender == magnetoCalibButton)
    {
        UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:ARDroneEngineLocalizeString(@"Calibration Warning") 
                                                            message:ARDroneEngineLocalizeString(@"Keep your distance with your AR.Drone. It will now spin once on itself to calibrate its compass.") 
                                                           delegate:self cancelButtonTitle:ARDroneEngineLocalizeString(@"Cancel") 
                                                  otherButtonTitles:@"OK", nil];
        [alertView setTag:MAGNETOCALIB_ALERT_TAG];
        [alertView show];
        [alertView release];
    }
    else if(sender == previous)
    {
        int nextPage = ((int) (scrollView.contentOffset.x + .5f * scrollView.frame.size.width) / scrollView.frame.size.width) - 1;
        if (0 > nextPage)
            nextPage = 0;
        CGFloat nextOffset = nextPage * scrollView.frame.size.width;
        
        [UIView beginAnimations:nil context:NULL];
        [UIView setAnimationDuration:0.3f];
        [scrollView setContentOffset:CGPointMake(nextOffset, 0.f) animated:NO];
        [UIView commitAnimations];
    }
    else if(sender == next)
    {
        int nextPage = ((int) (scrollView.contentOffset.x + .5f * scrollView.frame.size.width) / scrollView.frame.size.width) + 1;
        if (pagesNumber <= nextPage)
            nextPage = pagesNumber - 1;
        CGFloat nextOffset = nextPage * scrollView.frame.size.width;
        
        [UIView beginAnimations:nil context:NULL];
        [UIView setAnimationDuration:0.3f];
        [scrollView setContentOffset:CGPointMake(nextOffset, 0.f) animated:NO];
        [UIView commitAnimations];
    }
    else if(sender == clearLogsButton)
    {
#ifdef INTERFACE_WITH_DEBUG
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask, YES);
        if([paths count] > 0)
        {
            NSString *documentsDirectory = [paths objectAtIndex:0];
            NSFileManager *fileManager = [[NSFileManager alloc] init];
            NSArray *documentsDirectoryContents = [fileManager contentsOfDirectoryAtPath:documentsDirectory error:nil];
            for(int i = 0 ; i < [documentsDirectoryContents count] ; i++)
            {
                if([[documentsDirectoryContents objectAtIndex:i] hasPrefix:@"mesures"] || [[documentsDirectoryContents objectAtIndex:i] hasPrefix:@"settings_"])
                {
                    char filename[256];
                    sprintf(filename, "%s/%s", [documentsDirectory cStringUsingEncoding:NSUTF8StringEncoding], [[documentsDirectoryContents objectAtIndex:i] cStringUsingEncoding:NSUTF8StringEncoding]);
                    NSLog(@"- Remove %s", filename);
                    remove(filename);
                }
            }
            [fileManager release];
        }
#endif
    }
}

- (void)switchDisplay
{
	self.view.hidden = !self.view.hidden;
    if (NO == self.view.hidden)
    {
        [self configChanged];
    }
}

- (void)textFieldDidBeginEditing:(UITextField *)theTextField
{
	if(theTextField == droneSSIDTextField)
	{
        theTextField.keyboardType = UIKeyboardTypeASCIICapable;
		ssidChangeInProgress = NO;
	}
}

- (BOOL)textFieldShouldReturn:(UITextField *)theTextField 
{
	if(theTextField == droneSSIDTextField)
	{        
        BOOL SSIDIsCorrect = YES;
        const char *newSSID = [droneSSIDTextField.text cStringUsingEncoding:NSASCIIStringEncoding];
        if (NULL == newSSID)
        {
            SSIDIsCorrect = NO;
        }
        else
        {
            int nameLen = strlen(newSSID);
            if (32 <= nameLen || 0 == nameLen)
            {
                SSIDIsCorrect = NO;
            } // NO ELSE
            int i;
            for (i = 0; (i < nameLen) && (YES == SSIDIsCorrect); i++)
            {
                char testedChar = newSSID[i];
                if (('a' <= testedChar && 'z' >= testedChar) ||
                    ('A' <= testedChar && 'Z' >= testedChar) ||
                    ('0' <= testedChar && '9' >= testedChar) ||
                    ('_' == testedChar))
                {
                    // Nothing, SSID is still correct
                }
                else
                {
                    SSIDIsCorrect = NO;
                }
            }
        }
        
        if (SSIDIsCorrect)
        {
            strcpy(ardrone_control_config.ssid_single_player, newSSID);
		ARDRONE_TOOL_CONFIGURATION_ADDEVENT(ssid_single_player, ardrone_control_config.ssid_single_player, NULL);
		
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:ARDroneEngineLocalizeString(@"New AR.Drone network name")
                                                            message:[NSString stringWithFormat:ARDroneEngineLocalizeString(@"Please quit the application and restart your AR.Drone. Connect to %s network and relaunch AR.FreeFlight to apply changes."), newSSID]
                                                           delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil, nil];
		[alert show];
		[alert release];
        }
        else
        {
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:ARDroneEngineLocalizeString(@"Bad network name")
                                                         message:ARDroneEngineLocalizeString(@"The network name can only contain alphanumeric characters and underscores, and must not be longer than 32 characters.")
                                                        delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil, nil];
            [alert show];
            [alert release];
			theTextField.text = [NSString stringWithCString:ardrone_control_config.ssid_single_player encoding:NSUTF8StringEncoding];
        }
	}

	[theTextField resignFirstResponder];
	return YES;
}

- (BOOL)textFieldShouldEndEditing:(UITextField *)theTextField
{
	if(theTextField == droneSSIDTextField)
	{
		if(!ssidChangeInProgress && (strcmp(ardrone_control_config.ssid_single_player, "") != 0))
			droneSSIDTextField.text = [NSString stringWithCString:ardrone_control_config.ssid_single_player encoding:NSUTF8StringEncoding];

	}
	return YES;
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
	NSLog(@"%s", __FUNCTION__);
	ssidChangeInProgress = YES;
    
    if (alertView.tag == MAGNETOCALIB_ALERT_TAG)
    {
        // if user presses OK
        if (buttonIndex == 1) ardrone_at_set_calibration (ARDRONE_CALIBRATION_DEVICE_MAGNETOMETER);
    }
}


- (void)saveIPhoneSettings
{
	NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
	NSString *documentDirectory = [paths objectAtIndex:0];
	const char *filename = [[documentDirectory stringByAppendingFormat:@"/settings.txt"] cStringUsingEncoding:NSUTF8StringEncoding];
	FILE *file = fopen(filename, "w+");
	if(file)
	{
		fprintf(file, "Interface Alpha : %d\n", (int)interfaceAlphaSlider.value);
		fprintf(file, "Accelero Disabled : %d\n", (int)acceleroDisabledSwitch.tag);
		fprintf(file, "Left Handed : %d\n", (int)leftHandedSwitch.tag);
		fprintf(file, "Absolute Control : %d\n", (int)magnetoSwitch.tag);
        fprintf(file, "Looping : %d\n", (int)enableLoopingSwitch.tag);
		fclose(file);
	}
}

- (void)loadIPhoneSettings
{
	NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
	NSString *documentDirectory = [paths objectAtIndex:0];
	const char *filename = [[documentDirectory stringByAppendingFormat:@"/settings.txt"] cStringUsingEncoding:NSUTF8StringEncoding];
	FILE *file = fopen(filename, "r");
	int alpha = 50;
	int acceleroDisabled = SWITCH_UNCHECKED;
    int magnetoEnabled = SWITCH_UNCHECKED;
	int leftHanded = SWITCH_UNCHECKED;
    int loopingEnabled = SWITCH_UNCHECKED;
    
	if(file)
	{
		fscanf(file,"Interface Alpha : %d\n",&alpha);
		fscanf(file,"Accelero Disabled : %d\n", &acceleroDisabled);
		fscanf(file,"Left Handed : %d\n", &leftHanded);
		fscanf(file,"Absolute Control : %d\n", &magnetoEnabled);
        fscanf(file,"Looping : %d\n", &loopingEnabled);
		fclose(file);
	}

    if([CLLocationManager locationServicesEnabled])
    {
       if ([CLLocationManager authorizationStatus] != kCLAuthorizationStatusAuthorized)
       {
           magnetoEnabled = SWITCH_UNCHECKED;
       }
    }
    else
    {
        magnetoEnabled = SWITCH_UNCHECKED;
    }
    
    if(![CLLocationManager locationServicesEnabled])
    {
        magnetoEnabled = SWITCH_UNCHECKED;
    }
    else if(![CLLocationManager headingAvailable] || IS_ARDRONE1)
    {
        magnetoEnabled = SWITCH_UNCHECKED;
        [magnetoText setEnabled:NO];
        [magnetoText setAlpha:0.5];
        [magnetoSwitch setEnabled:NO];
        [magnetoSwitch setAlpha:0.5];
    }
    
	CGFloat alpha_value = (float)alpha / 100.0f;
	[_delegate interfaceAlphaValueChanged:alpha_value];
	interfaceAlphaSlider.value = (float)alpha;

	[_delegate acceleroValueChanged:!(bool_t)(acceleroDisabled == SWITCH_CHECKED)];
    [self setSwitch:acceleroDisabledSwitch withValue:(acceleroDisabled == SWITCH_CHECKED)];

    [_delegate magnetoValueChanged:(bool_t)(magnetoEnabled == SWITCH_CHECKED)];
    [self setSwitch:magnetoSwitch withValue:(magnetoEnabled == SWITCH_CHECKED)];
    
	[_delegate controlModeChanged:(leftHanded == SWITCH_CHECKED) ? CONTROL_MODE2 : CONTROL_MODE3];
    [self setSwitch:leftHandedSwitch withValue:(leftHanded == SWITCH_CHECKED)];
    
    [_delegate loopingActiveValueChanged:(bool_t)(loopingEnabled == SWITCH_CHECKED)];
    [self setSwitch:enableLoopingSwitch withValue:(loopingEnabled == SWITCH_CHECKED)];

    [self saveIPhoneSettings];
}

- (void)saveForDebugSettings
{
	struct timeval tv;
	// Save backups of Settings in text
	gettimeofday(&tv,NULL);
	settings_atm = localtime(&tv.tv_sec);
	NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES); //creates paths so that you can pull the app's path from it
	NSString *documentsDirectory = [paths objectAtIndex:0]; // gets the applications directory on the users iPhone
	
	const char *filename = [[documentsDirectory stringByAppendingFormat:@"/settings_%04d%02d%02d_%02d%02d%02d.txt",
							 settings_atm->tm_year+1900, settings_atm->tm_mon+1, settings_atm->tm_mday,
							 settings_atm->tm_hour, settings_atm->tm_min, settings_atm->tm_sec] cStringUsingEncoding:NSUTF8StringEncoding];
	FILE *file = fopen(filename, "w");
	if(file)
	{
		fprintf(file, "iPhone section\n");
		fprintf(file, "Accelero Disabled  : %s\n", (int)acceleroDisabledSwitch.tag ? "YES" : "NO");
		fprintf(file, "Combined yaw       : %s\n", ((ardrone_control_config.control_level >> CONTROL_LEVEL_COMBINED_YAW) & 0x1) ? "ON" : "OFF");
		fprintf(file, "Left Handed		  : %s\n", (int)leftHandedSwitch.tag ? "YES" : "NO");
		fprintf(file, "Absolute Control   : %s\n", (int)magnetoSwitch.tag ? "YES" : "NO");
		fprintf(file, "Iphone Tilt        : %0.2f\n", ardrone_control_config.control_iphone_tilt * RAD_TO_DEG);
		fprintf(file, "Interface Alpha    : %d\n", (int)interfaceAlphaSlider.value);
		fprintf(file, "\n");
		fprintf(file, "AR.Drone section\n");
        fprintf(file, "Auto record on USB : %s\n", ardrone_control_config.video_on_usb ? "ON" : "OFF");
        fprintf(file, "Video codec        : %s\n", (ARDRONE_VIDEO_CODEC_UVLC == ardrone_control_config.video_codec) ? "VLIB" : "P264");
        fprintf(file, "Adaptive video	  : %s\n", ardrone_control_config.bitrate_ctrl_mode ? "ON" : "OFF");
        fprintf(file, "Looping            : %s\n", (int)enableLoopingSwitch.tag ? "ON" : "OFF");
		fprintf(file, "Pairing            : %s\n", strcmp(ardrone_control_config.owner_mac, NULL_MAC) != 0 ? "ON" : "OFF");
		fprintf(file, "Drone Network SSID : %s\n", ardrone_control_config.ssid_single_player);
		fprintf(file, "Altitude Limited   : %d\n", ardrone_control_config.altitude_max / 1000);
		fprintf(file, "Outdoor Shell      : %s\n", ardrone_control_config.flight_without_shell ? "ON" : "OFF");
		fprintf(file, "Outdoor Flight     : %s\n", ardrone_control_config.outdoor ? "ON" : "OFF");
		fprintf(file, "Yaw Speed          : %0.2f\n", ardrone_control_config.control_yaw * RAD_TO_DEG);
		fprintf(file, "Vertical Speed     : %0.2f\n", (float)ardrone_control_config.control_vz_max);
		fprintf(file, "Drone Tilt         : %0.2f\n", ardrone_control_config.euler_angle_max * RAD_TO_DEG);
        
		fclose(file);
	}
	else 
	{
		NSLog(@"%s not found", filename);
	}		
}

- (void)dealloc
{
    [pagesArray release];
    [pagesArrayTitle release];
	[super dealloc];	
}

- (void)setSwitch:(UIButton *)switchButton withValue:(BOOL)active
{
    if (active)
    {
        switchButton.tag = SWITCH_CHECKED;
        [switchButton setImage:[UIImage imageNamed:@"Btn_ON.png"] forState:UIControlStateNormal];
    }
    else
    {
        switchButton.tag = SWITCH_UNCHECKED;
        [switchButton setImage:[UIImage imageNamed:@"Btn_OFF.png"] forState:UIControlStateNormal];
    }
}

- (void)toggleSwitch:(UIButton *)switchButton
{
    [self setSwitch:switchButton withValue:(SWITCH_UNCHECKED == switchButton.tag) ? YES : NO];
}

@end
