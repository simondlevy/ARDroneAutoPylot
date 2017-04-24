#import "HUD.h"
#import <CoreMotion/CoreMotion.h>
#import <CoreLocation/CoreLocation.h>
#import <mach/mach_time.h>
#import "ARDroneMotionManager.h"
#import <ardrone_tool/Video/video_stage_encoded_recorder.h>

// Ratio to activate control yaw and gaz
#define CONTROL_RATIO	(1.0 / 3.0)
#define CONTROL_RATIO_IPAD (1.0 / 6.0)

#define ACCELERO_THRESHOLD          0.2
#define ACCELERO_FASTMOVE_THRESHOLD	1.3

#define DELAY_BETWEEN_TWO_LOOPINGS_MS (3000)

// YES or NO (BOOL values)
#define DISPLAY_RECORD_POPUP_DRONE2 NO 

extern vp_stages_latency_estimation_config_t vlat;

// Determine if a point within the boundaries of the joystick.
static bool_t isPointInCircle(CGPoint point, CGPoint center, float radius) {
	float dx = (point.x - center.x);
	float dy = (point.y - center.y);
	return (radius >= sqrt( (dx * dx) + (dy * dy) ));
}

static inline float sign(float value)
{
	float result = 1.0;
	if(value < 0)
		result = -1.0;
	
	return result;
}

static inline float Normalize(float x, float y, float z)
{
	return sqrt(x * x + y * y + z * z);
}

static inline float Clamp(float v, float min, float max)
{
	float result = v;
	if(v > max)
		result = max;
	else if(v < min)
		result = min;

	return result;
}

static CONTROLS controls_table[CONTROL_MODE_MAX] = 
{
	[CONTROL_MODE1] = { {FALSE, inputPitch, inputYaw}, {FALSE, inputGaz, inputRoll} },
	[CONTROL_MODE2] = { {FALSE, inputGaz, inputYaw}, {TRUE, inputPitch, inputRoll} },
	[CONTROL_MODE3] = { {TRUE, inputPitch, inputRoll}, {FALSE, inputGaz, inputYaw} },
	[CONTROL_MODE4] = { {FALSE, inputGaz, inputRoll}, {FALSE, inputPitch, inputYaw} }
};

extern PIPELINE_HANDLE video_pipeline_handle;
extern ControlData ctrldata;

/**
 * DEBUG AREA EXTERN VARIABLES
 */
extern float DEBUG_nbSlices;
extern float DEBUG_totalSlices;
extern int DEBUG_missed;
extern float DEBUG_fps;
extern float DEBUG_bitrate;
extern float DEBUG_latency;
extern int DEBUG_isTcp;
extern float DEBUG_decodingTimeUsec;

ARDroneHUDConfiguration config;
CONTROL_MODE controlMode;
float accelero[3];
float accelero_rotation[3][3];
UIAccelerationValue lastX, lastY, lastZ;
bool_t acceleroEnabled, combinedYawEnabled, magnetoEnabled;
bool_t loopingEnabled;
double lowPassFilterConstant, highPassFilterConstant;
BOOL accelerometer_started;
CGPoint joystickRightCurrentPosition, joystickLeftCurrentPosition;
CGPoint joystickRightInitialPosition, joystickLeftInitialPosition;
BOOL buttonRightPressed, buttonLeftPressed;
CGPoint rightCenter, leftCenter;
float tmp_phi, tmp_theta;
float alpha;
SystemSoundID plop_id, batt_id;
FILE *mesures_file;
BOOL running;
CMAccelerometerData * accelerometerData;
//CMMotionManager*    motionManager; // A virer si le ARDroneMotionManager est stable
NSMutableArray *loadingViewsArray;
BOOL leftButtonIsJs, rightButtonIsJs;
BOOL isConnectedToARDrone;

@interface HUD ()
- (void)motionDataHandler;
- (void)setAcceleroRotationWithPhi:(float)phi withTheta:(float)theta withPsi:(float)psi;
- (void)refreshJoystickRight;
- (void)refreshJoystickLeft;
- (void)updateVelocity:(CGPoint)point isRight:(BOOL)isRight;
- (void)hideInfos;
- (void)showInfos;
- (void)refreshControlInterface;
@end

@implementation HUD
@synthesize firePressed;
@synthesize settingsPressed;
@synthesize mainMenuPressed;
@synthesize screenOrientationRight;
@synthesize locationManager;

- (id)initWithFrame:(CGRect)frame withState:(BOOL)inGame withHUDConfiguration:(ARDroneHUDConfiguration)hudconfiguration
{
	if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
	{
		self = [super initWithNibName:@"HUD-iPad" bundle:nil];
	}
	else
	{
		self = [super initWithNibName:@"HUD" bundle:nil];
	}
    
	NSLog(@"HUD frame => %@", NSStringFromCGRect(frame));
    
	if (self)
	{
        srandom(time(NULL));
        
		running = inGame;
		firePressed = NO;
		settingsPressed = NO;
		mainMenuPressed = NO;
        leftButtonIsJs = NO;
        rightButtonIsJs = YES;
        isConnectedToARDrone = NO;
        mainMenuButtonHidden = NO;
        
        ardrone_timer_reset (&loopingTimer);
        ardrone_timer_reset (&popUpTimer);
        currentPopUp = firstPopUp = lastPopUp = NULL;
		
		vp_os_memcpy(&config, &hudconfiguration, sizeof(ARDroneHUDConfiguration));
		
		acceleroEnabled = TRUE;
		combinedYawEnabled = FALSE;
		controlMode = CONTROL_MODE3;
		buttonRightPressed = buttonLeftPressed = NO;
		
		rightCenter = CGPointZero;	
		leftCenter = CGPointZero;
		lowPassFilterConstant = ACCELERO_THRESHOLD;
		highPassFilterConstant = (1.0 / 5.0) / ((1.0 / kAPS) + (1.0 / 5.0));
		
		joystickRightInitialPosition = CGPointZero;
		joystickRightCurrentPosition = CGPointZero;
		joystickLeftInitialPosition = CGPointZero;
		joystickLeftCurrentPosition = CGPointZero;
		
		accelero[0] = 0.0;
		accelero[1] = 0.0;
		accelero[2] = 0.0;
		
		tmp_phi = 0.0;
		tmp_theta = 0.0;
		
		accelerometer_started = NO;
        
        locationManager = [[CLLocationManager alloc] init];
        
        if([CLLocationManager locationServicesEnabled] && [CLLocationManager headingAvailable])
        {
            locationManager.delegate = self;
            [locationManager startUpdatingHeading];
            NSLog(@"MAGNETO      [OK]");
        }
        
        //motionManager = [[CMMotionManager alloc] init];
        CMMotionManager *motionManager = [ARDroneMotionManager sharedInstance].motionManager;

        if(motionManager.gyroAvailable == 0 && motionManager.accelerometerAvailable == 1)
        {
            //Only accelerometer
            motionManager.accelerometerUpdateInterval = 1.0 / kAPS;
            [motionManager startAccelerometerUpdates];
            NSLog(@"ACCELERO     [OK]");
        } else if (motionManager.deviceMotionAvailable == 1){
            //Accelerometer + gyro
            motionManager.deviceMotionUpdateInterval = 1.0 / kAPS;
            [motionManager startDeviceMotionUpdates];
            NSLog(@"ACCELERO     [OK]");
            NSLog(@"GYRO         [OK]");
        } else {
            NSLog(@"DEVICE MOTION ERROR - DISABLE");
            acceleroEnabled = FALSE;
        }

        [self setAcceleroRotationWithPhi:0.0 withTheta:0.0 withPsi:0.0];
        [NSTimer scheduledTimerWithTimeInterval:(NSTimeInterval)(1.0 / kAPS) target:self selector:@selector(motionDataHandler) userInfo:nil repeats:YES];
        
#ifdef WRITE_DEBUG_ACCELERO	
		char filename[128];
		NSString *documentsDirectory = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask, YES) objectAtIndex:0];
		sprintf(filename, "%s/accelero_iphones_mesures.txt",
				[documentsDirectory cStringUsingEncoding:NSUTF8StringEncoding]);
		mesures_file = fopen(filename, "wb");
		fprintf(mesures_file, "ARDrone\nNumSamples;AccEnable;AccXbrut;AccYbrut;AccZbrut;AccX;AccY;AccZ;PhiAngle;ThetaAngle;AlphaAngle\n");
#endif
	}

	return self;
}

- (void) setAcceleroRotationWithPhi:(float)phi withTheta:(float)theta withPsi:(float)psi
{	
	accelero_rotation[0][0] = cosf(psi)*cosf(theta);
	accelero_rotation[0][1] = -sinf(psi)*cosf(phi) + cosf(psi)*sinf(theta)*sinf(phi);
	accelero_rotation[0][2] = sinf(psi)*sinf(phi) + cosf(psi)*sinf(theta)*cosf(phi);
	accelero_rotation[1][0] = sinf(psi)*cosf(theta);
	accelero_rotation[1][1] = cosf(psi)*cosf(phi) + sinf(psi)*sinf(theta)*sinf(phi);
	accelero_rotation[1][2] = -cosf(psi)*sinf(phi) + sinf(psi)*sinf(theta)*cosf(phi);
	accelero_rotation[2][0] = -sinf(theta);
	accelero_rotation[2][1] = cosf(theta)*sinf(phi);
	accelero_rotation[2][2] = cosf(theta)*cosf(phi);

#ifdef WRITE_DEBUG_ACCELERO	
	NSLog(@"Accelero rotation matrix changed :"); 
	NSLog(@"%0.1f %0.1f %0.1f", accelero_rotation[0][0], accelero_rotation[0][1], accelero_rotation[0][2]);
	NSLog(@"%0.1f %0.1f %0.1f", accelero_rotation[1][0], accelero_rotation[1][1], accelero_rotation[1][2]);
	NSLog(@"%0.1f %0.1f %0.1f", accelero_rotation[2][0], accelero_rotation[2][1], accelero_rotation[2][2]);	
#endif
}

- (BOOL)locationManagerShouldDisplayHeadingCalibration:(CLLocationManager *)_locationManager 
{
    return (magnetoEnabled ? YES : NO);
}

- (void)locationManager:(CLLocationManager *)manager didUpdateHeading:(CLHeading *)heading
{
    if(magnetoEnabled)
    {
        if(screenOrientationRight)
        {
            ctrldata.iphone_psi = heading.magneticHeading + 90.0;
        } 
        else 
        {
            ctrldata.iphone_psi = heading.magneticHeading - 90.0;
        }
        if(ctrldata.iphone_psi > 180)
        {
            ctrldata.iphone_psi -= 360;
        }

        ctrldata.iphone_psi /= 180;
        ctrldata.iphone_psi_accuracy = heading.headingAccuracy;
        
        if(ctrldata.iphone_psi_accuracy >= 0)
            ctrldata.command_flag |= (1 << ARDRONE_MAGNETO_CMD_ENABLE);
        else
            ctrldata.command_flag = 0;
        // NSLog(@"Magneto enabled     angle = %.4f, accuracy = %.4f",ctrldata.iphone_psi,ctrldata.iphone_psi_accuracy);
    } 
    else 
    {
        ctrldata.command_flag &= ~(1 << ARDRONE_MAGNETO_CMD_ENABLE);
        ctrldata.iphone_psi          = 0;
        ctrldata.iphone_psi_accuracy = 0;
        
        // NSLog(@"Magneto disabled    angle = %.4f, accuracy = %.4f",ctrldata.iphone_psi,ctrldata.iphone_psi_accuracy);
        
    }
}

- (void)motionDataHandler
{    
    static uint64_t previous_time = 0;
    if(previous_time == 0) previous_time = mach_absolute_time();
    
    uint64_t current_time = mach_absolute_time();
    static mach_timebase_info_data_t sTimebaseInfo;
    uint64_t elapsedNano;
    float dt = 0;
    
    static float highPassFilterX = 0.0, highPassFilterY = 0.0, highPassFilterZ = 0.0;
    
    CMAcceleration current_acceleration = { 0.0, 0.0, 0.0 };
    static CMAcceleration last_acceleration = { 0.0, 0.0, 0.0 };
    
    static bool first_time_accelero = TRUE;
    static bool first_time_gyro = TRUE;
    
    static float angle_gyro_x, angle_gyro_y, angle_gyro_z;
    float current_angular_rate_x, current_angular_rate_y, current_angular_rate_z;
    
    static float hpf_gyro_x, hpf_gyro_y, hpf_gyro_z;
    static float last_angle_gyro_x, last_angle_gyro_y, last_angle_gyro_z;
    
    float phi, theta;
    
    //dt calculus function of real elapsed time
    if(sTimebaseInfo.denom == 0) (void) mach_timebase_info(&sTimebaseInfo);
    elapsedNano = (current_time-previous_time)*(sTimebaseInfo.numer / sTimebaseInfo.denom);
    previous_time = current_time;
    dt = elapsedNano/1000000000.0;
    
    //Execute this part of code only on the joystick button pressed
    if(running)// && (((ctrldata.command_flag) & (1 << (ARDRONE_PROGRESSIVE_CMD_ENABLE))) == 1))
    {
        /***************************************************************************************************************
         ACCELEROMETER HANDLE
         **************************************************************************************************************/

        CMMotionManager *motionManager = [ARDroneMotionManager sharedInstance].motionManager;
        
        //Get ACCELERO values
        if(motionManager.gyroAvailable == 0 && motionManager.accelerometerAvailable == 1)
        {
            //Only accelerometer (iphone 3GS)
            current_acceleration.x = motionManager.accelerometerData.acceleration.x;
            current_acceleration.y = motionManager.accelerometerData.acceleration.y;
            current_acceleration.z = motionManager.accelerometerData.acceleration.z;
        } 
        else if (motionManager.deviceMotionAvailable == 1)
        {
            //Accelerometer + gyro (iphone 4)
            current_acceleration.x = motionManager.deviceMotion.gravity.x + motionManager.deviceMotion.userAcceleration.x;
            current_acceleration.y = motionManager.deviceMotion.gravity.y + motionManager.deviceMotion.userAcceleration.y;
            current_acceleration.z = motionManager.deviceMotion.gravity.z + motionManager.deviceMotion.userAcceleration.z;
        }
        
        //NSLog(@"Before Shake %f %f %f",current_acceleration.x, current_acceleration.y, current_acceleration.z);
        
        if( isnan(current_acceleration.x) || isnan(current_acceleration.y) || isnan(current_acceleration.z)
           || fabs(current_acceleration.x) > 10 || fabs(current_acceleration.y) > 10 || fabs(current_acceleration.z)>10)
        {
            static uint32_t count = 0;
            static BOOL popUpWasDisplayed = NO;
            NSLog (@"Accelero errors : %f, %f, %f (count = %d)", current_acceleration.x, current_acceleration.y, current_acceleration.z, count);
            NSLog (@"Accelero raw : %f/%f, %f/%f, %f/%f", motionManager.deviceMotion.gravity.x, motionManager.deviceMotion.userAcceleration.x, motionManager.deviceMotion.gravity.y, motionManager.deviceMotion.userAcceleration.y, motionManager.deviceMotion.gravity.z, motionManager.deviceMotion.userAcceleration.z);
            NSLog (@"Attitude : %f / %f / %f", motionManager.deviceMotion.attitude.roll, motionManager.deviceMotion.attitude.pitch, motionManager.deviceMotion.attitude.yaw);
            if (30 < ++count &&
                NO == popUpWasDisplayed)
            {
                [self addPopUpWithMessage:[NSString stringWithFormat:ARDroneEngineLocalizeString(@"Please reboot your %@ to enable full piloting capabilities"), [[UIDevice currentDevice] model]] maxDisplayTime:0 callback:nil priority:POPUP_PRIO_ERROR useProgress:NO];
                popUpWasDisplayed = YES;
            }
            return;
        }
        
        //INIT accelero variables
        if(first_time_accelero == TRUE)
        {
            first_time_accelero = FALSE;
            last_acceleration.x = current_acceleration.x;
            last_acceleration.y = current_acceleration.y;
            last_acceleration.z = current_acceleration.z;            
        }
        
        //HPF on the accelero
        highPassFilterX = highPassFilterConstant * (highPassFilterX + current_acceleration.x - last_acceleration.x);
        highPassFilterY = highPassFilterConstant * (highPassFilterY + current_acceleration.y - last_acceleration.y);
        highPassFilterZ = highPassFilterConstant * (highPassFilterZ + current_acceleration.z - last_acceleration.z);
        
        //Save the previous values
        last_acceleration.x = current_acceleration.x;
        last_acceleration.y = current_acceleration.y;
        last_acceleration.z = current_acceleration.z; 
        
        if(fabs(highPassFilterX) > ACCELERO_FASTMOVE_THRESHOLD || 
           fabs(highPassFilterY) > ACCELERO_FASTMOVE_THRESHOLD || 
           fabs(highPassFilterZ) > ACCELERO_FASTMOVE_THRESHOLD)
        {
            //Send event to games
            firePressed = YES;
            //NSLog(@"Shake : %f, %f, %f", current_acceleration.x, current_acceleration.y, current_acceleration.z);
        }
        else
        {
            //If no fire detected, execute piloting algo
            firePressed = NO;
            
            if(acceleroEnabled)
            {
                CMAcceleration current_acceleration_rotate;
                float angle_acc_x;
                float angle_acc_y;
                
                //LPF on the accelero
                current_acceleration.x = 0.9 * last_acceleration.x + 0.1 * current_acceleration.x;
                current_acceleration.y = 0.9 * last_acceleration.y + 0.1 * current_acceleration.y;
                current_acceleration.z = 0.9 * last_acceleration.z + 0.1 * current_acceleration.z;
                
                //Save the previous values
                last_acceleration.x = current_acceleration.x;
                last_acceleration.y = current_acceleration.y;
                last_acceleration.z = current_acceleration.z;    
                
                //Rotate the accelerations vectors (see the - (IBAction)buttonPress:(id)sender forEvent:(UIEvent *)event function)
                current_acceleration_rotate.x =
                (accelero_rotation[0][0] * current_acceleration.x)
                + (accelero_rotation[0][1] * current_acceleration.y)
                + (accelero_rotation[0][2] * current_acceleration.z);
                current_acceleration_rotate.y =
                (accelero_rotation[1][0] * current_acceleration.x)
                + (accelero_rotation[1][1] * current_acceleration.y)
                + (accelero_rotation[1][2] * current_acceleration.z);
                current_acceleration_rotate.z =
                (accelero_rotation[2][0] * current_acceleration.x)
                + (accelero_rotation[2][1] * current_acceleration.y)
                + (accelero_rotation[2][2] * current_acceleration.z);
                
                //IF sequence to remove the angle jump problem when accelero mesure X angle AND Y angle AND Z change of sign
                if(current_acceleration_rotate.y > -ACCELERO_THRESHOLD && current_acceleration_rotate.y < ACCELERO_THRESHOLD)
                {
                    angle_acc_x = atan2f(current_acceleration_rotate.x,
                                         sign(-current_acceleration_rotate.z)*sqrtf(current_acceleration_rotate.y*current_acceleration_rotate.y+current_acceleration_rotate.z*current_acceleration_rotate.z));
                } 
                else 
                {
                    angle_acc_x = atan2f(current_acceleration_rotate.x,
                                         sqrtf(current_acceleration_rotate.y*current_acceleration_rotate.y+current_acceleration_rotate.z*current_acceleration_rotate.z));
                }
                
                //IF sequence to remove the angle jump problem when accelero mesure X angle AND Y angle AND Z change of sign
                if(current_acceleration_rotate.x > -ACCELERO_THRESHOLD && current_acceleration_rotate.x < ACCELERO_THRESHOLD)
                {
                    angle_acc_y = atan2f(current_acceleration_rotate.y,
                                         sign(-current_acceleration_rotate.z)*sqrtf(current_acceleration_rotate.x*current_acceleration_rotate.x+current_acceleration_rotate.z*current_acceleration_rotate.z));
                } 
                else 
                {
                    angle_acc_y = atan2f(current_acceleration_rotate.y,
                                         sqrtf(current_acceleration_rotate.x*current_acceleration_rotate.x+current_acceleration_rotate.z*current_acceleration_rotate.z));
                }
                
                //NSLog(@"Accelero   %d",motionManager.accelerometerAvailable);
                //NSLog(@"AccX %2.2f   AccY %2.2f   AccZ %2.2f",current_acceleration.x,current_acceleration.y,current_acceleration.z);
                
                
                /***************************************************************************************************************
                 GYRO HANDLE IF AVAILABLE
                 **************************************************************************************************************/
                if (motionManager.deviceMotionAvailable == 1)
                {
                    current_angular_rate_x = motionManager.deviceMotion.rotationRate.x;
                    current_angular_rate_y = motionManager.deviceMotion.rotationRate.y;
                    current_angular_rate_z = motionManager.deviceMotion.rotationRate.z;
                    
                    angle_gyro_x += -current_angular_rate_x * dt;
                    angle_gyro_y += current_angular_rate_y * dt;
                    angle_gyro_z += current_angular_rate_z * dt;
                    
                    if(first_time_gyro == TRUE)
                    {
                        first_time_gyro = FALSE;
                        
                        //Init for the integration samples
                        angle_gyro_x = 0;
                        angle_gyro_y = 0;
                        angle_gyro_z = 0;
                        
                        //Init for the HPF calculus
                        hpf_gyro_x = angle_gyro_x;
                        hpf_gyro_y = angle_gyro_y;
                        hpf_gyro_z = angle_gyro_z;
                        
                        last_angle_gyro_x = 0;
                        last_angle_gyro_y = 0;
                        last_angle_gyro_z = 0;
                    }
                    
                    //HPF on the gyro to keep the hight frequency of the sensor
                    hpf_gyro_x = 0.9 * hpf_gyro_x + 0.9 * (angle_gyro_x - last_angle_gyro_x);
                    hpf_gyro_y = 0.9 * hpf_gyro_y + 0.9 * (angle_gyro_y - last_angle_gyro_y);
                    hpf_gyro_z = 0.9 * hpf_gyro_z + 0.9 * (angle_gyro_z - last_angle_gyro_z);
                    
                    last_angle_gyro_x = angle_gyro_x;
                    last_angle_gyro_y = angle_gyro_y;
                    last_angle_gyro_z = angle_gyro_z;
                }
                
                /******************************************************************************RESULTS AND COMMANDS COMPUTATION
                 *****************************************************************************/
                //Sum of hight gyro frequencies and low accelero frequencies
                float fusion_x = hpf_gyro_y + angle_acc_x;
                float fusion_y = hpf_gyro_x + angle_acc_y;
                
                //NSLog(@"%*.2f  %*.2f  %*.2f  %*.2f  %*.2f",2,-angle_acc_x*180/PI,2,-angle_acc_y*180/PI,2,current_acceleration_rotate.x,2,current_acceleration_rotate.y,2,current_acceleration_rotate.z);
                //Adapt the command values Normalize between -1 = 1.57rad and 1 = 1.57 rad
                //and reverse the values in regards of the screen orientation
                if(motionManager.gyroAvailable == 0 && motionManager.accelerometerAvailable == 1)
                {
                    //Only accelerometer (iphone 3GS)
                    if(screenOrientationRight)
                    {
                        theta = -angle_acc_x;
                        phi = -angle_acc_y;
                    }
                    else
                    {
                        theta = angle_acc_x;
                        phi = angle_acc_y;
                    }
                } 
                else if (motionManager.deviceMotionAvailable == 1)
                {
                    //Accelerometer + gyro (iphone 4)
                    if(screenOrientationRight)
                    {
                        theta = -fusion_x;
                        phi = -fusion_y;
                    } 
                    else 
                    {
                        theta = fusion_x;
                        phi = fusion_y;            
                    }
                }
                                
                //Clamp the command sent
                theta = theta / M_PI_2;
                phi   = phi / M_PI_2;
                if(theta > 1) 
                    theta = 1;
                if(theta < -1) 
                    theta = -1;
                if(phi > 1) 
                    phi = 1;
                if(phi < -1) 
                    phi = -1;
                
                ctrldata.iphone_theta = theta;
                ctrldata.iphone_phi   = phi;

                //NSLog(@"Accelero-ctrl");
            } 
            else if (!acceleroEnabled)
            {
                //NSLog(@"Joystick-ctrl");
            }
        }
    } 
    else 
    {
        ctrldata.iphone_theta        = 0;
        ctrldata.iphone_phi          = 0;
    }
    
    sendControls();
    
#ifdef INTERFACE_WITH_DEBUG
    /**
     * REFRESH DEBUG AREA
     */
    static int nbIter = 0;
    if (++nbIter > (kFPS/2))
    {
        nbIter = 0;
        float DEBUG_percentMiss = DEBUG_nbSlices * 100.0 / DEBUG_totalSlices;
        [debugText setText:[NSString stringWithFormat:@"Mean missed slices : %6.3f/%2.0f (%5.1f%%)\nMissed frames : %10d | Bitrate : %6.2f Kbps\nFPS : %4.1f | Decoding time : %5.1f usec\nLatency : %5.1f ms | Protocol : %@", 
                        DEBUG_nbSlices, 
                        DEBUG_totalSlices, 
                        DEBUG_percentMiss, 
                        DEBUG_missed, 
                        DEBUG_bitrate, 
                        DEBUG_fps,
                        DEBUG_decodingTimeUsec,
                        DEBUG_latency,
                        (1 == DEBUG_isTcp) ? @"TCP" : @"UDP"]];
    }
#endif
}

- (void)refreshJoystickRight
{
	CGRect frame = joystickRightBackgroundImageView.frame;
	frame.origin = joystickRightCurrentPosition;
	joystickRightBackgroundImageView.frame = frame;
}    

- (void)refreshJoystickLeft
{
	CGRect frame = joystickLeftBackgroundImageView.frame;
	frame.origin = joystickLeftCurrentPosition;
	joystickLeftBackgroundImageView.frame = frame;
}

- (void)setControlToJoystick:(BOOL)isJs onLeft:(BOOL)isLeft useAbsoluteControl:(BOOL)useMag
{
    UIImageView *jsBg = joystickRightBackgroundImageView;
    UIImageView *jsThumb = joystickRightThumbImageView;
    NSString *deviceText = (UIUserInterfaceIdiomPad == UI_USER_INTERFACE_IDIOM()) ? @"iPAD" : @"RETINA";
    NSString *jsNameText = (useMag ? @"Absolut_Control" : (isJs ? @"Manuel" : @"Gyro"));
    if (isLeft)
    {
        jsBg = joystickLeftBackgroundImageView;
        jsThumb = joystickLeftThumbImageView;
        leftButtonIsJs = isJs;
    }
    else
    {
        rightButtonIsJs = isJs;
    }
    
    [jsThumb setImage:[UIImage imageNamed:[NSString stringWithFormat:@"Joystick_%@_%@.png", jsNameText, deviceText]]];
    if (isJs)
    {
        [jsBg setHidden:NO];
    }
    else
    {
        [jsBg setHidden:YES];
    }
}

- (void)refreshControlInterface
	{
		switch (controlMode) {
			case CONTROL_MODE2:
            [self setControlToJoystick:YES onLeft:YES useAbsoluteControl:NO];
            [self setControlToJoystick:(!acceleroEnabled) onLeft:NO useAbsoluteControl:magnetoEnabled];
				break;
				
			case CONTROL_MODE3:
			default:
            [self setControlToJoystick:YES onLeft:NO useAbsoluteControl:NO];
            [self setControlToJoystick:(!acceleroEnabled) onLeft:YES useAbsoluteControl:magnetoEnabled];
				break;
	}
    
	[self refreshJoystickRight];
	[self refreshJoystickLeft];
}

- (void)changeState:(BOOL)inGame
{
	printf("%s - running : %d, inGame : %d\n", __FUNCTION__, running, inGame);
	running = inGame;
	if(!inGame)
	{
		if(buttonRightPressed)
			[joystickRightButton sendActionsForControlEvents:UIControlEventTouchCancel];
		
		if(buttonLeftPressed)
			[joystickLeftButton sendActionsForControlEvents:UIControlEventTouchCancel];
	}
}

- (void)acceleroValueChanged:(bool_t)enabled
{
    CMMotionManager *motionManager = [ARDroneMotionManager sharedInstance].motionManager;
    if(motionManager.gyroAvailable == 0 && motionManager.accelerometerAvailable == 1){
        acceleroEnabled = enabled;
        //Accelero ok
    } else if (motionManager.deviceMotionAvailable == 1){
        acceleroEnabled = enabled;
        //Accelero + gyro ok
    } else {
        //Not gyro and not accelero
        acceleroEnabled = FALSE;
    }
	[self performSelectorOnMainThread:@selector(refreshControlInterface) withObject:nil waitUntilDone:YES];
}

- (void)loopingActiveValueChanged:(bool_t)enabled
{
    loopingEnabled = enabled;
}

- (void)magnetoValueChanged:(bool_t)enabled
{
	magnetoEnabled = enabled;
    if([CLLocationManager locationServicesEnabled] && [CLLocationManager headingAvailable])
    {
        if(!magnetoEnabled)
            [locationManager dismissHeadingCalibrationDisplay];
    }
	[self performSelectorOnMainThread:@selector(refreshControlInterface) withObject:nil waitUntilDone:YES];
}

- (void)combinedYawValueChanged:(bool_t)enabled
{
	combinedYawEnabled = enabled;
	[self performSelectorOnMainThread:@selector(refreshControlInterface) withObject:nil waitUntilDone:YES];
}

- (void)interfaceAlphaValueChanged:(CGFloat)value
{
	joystickRightThumbImageView.alpha = value;
	joystickRightBackgroundImageView.alpha = value;
	joystickLeftThumbImageView.alpha = value;
	joystickLeftBackgroundImageView.alpha = value;
	alpha = value;
}

- (void)controlModeChanged:(CONTROL_MODE)mode
{
	controlMode = mode;
	[self performSelectorOnMainThread:@selector(refreshControlInterface) withObject:nil waitUntilDone:YES];
}

- (void)updateVelocity:(CGPoint)point isRight:(BOOL)isRight
{
    static BOOL _runOnce = YES;
    static float leftThumbWidth = 0.0;
    static float rightThumbWidth = 0.0;
    static float leftThumbHeight = 0.0;
    static float rightThumbHeight = 0.0;
    static float leftRadius = 0.0;
    static float rightRadius = 0.0;
    static float radiusCoeff = 0.0;
    if (_runOnce)
    {
        leftThumbWidth = joystickLeftThumbImageView.frame.size.width;
        rightThumbWidth = joystickRightThumbImageView.frame.size.width;
        leftThumbHeight = joystickLeftThumbImageView.frame.size.height;
        rightThumbHeight = joystickRightThumbImageView.frame.size.height;
        leftRadius = joystickLeftBackgroundImageView.frame.size.width / 2.0;
        rightRadius = joystickRightBackgroundImageView.frame.size.width / 2.0;
        radiusCoeff = (UIUserInterfaceIdiomPad == UI_USER_INTERFACE_IDIOM()) ? 3.0 : 2.0;
        _runOnce = NO;
    }
    
	CGPoint nextpoint = CGPointMake(point.x, point.y);
	CGPoint center = (isRight ? rightCenter : leftCenter);
	UIImageView *thumbImage = (isRight ? joystickRightThumbImageView : joystickLeftThumbImageView);
	
	// Calculate distance and angle from the center.
	float dx = nextpoint.x - center.x;
	float dy = nextpoint.y - center.y;
	
	float distance = sqrt(dx * dx + dy * dy);
	float angle = atan2(dy, dx); // in radians
	
    float joystick_radius = (isRight ? rightRadius : leftRadius);
	// NOTE: Velocity goes from -1.0 to 1.0.
	// BE CAREFUL: don't just cap each direction at 1.0 since that
	// doesn't preserve the proportions.
	if (distance > joystick_radius) {
		dx = cos(angle) * joystick_radius;
		dy = sin(angle) * joystick_radius;
	}
	
	// Constrain the thumb so that it stays within the joystick
	// boundaries.  This is smaller than the joystick radius in
	// order to account for the size of the thumb.
	float thumb_radius = (isRight ? rightThumbWidth : leftThumbWidth) / radiusCoeff;
	if (distance > thumb_radius) {
		nextpoint.x = center.x + (cos(angle) * thumb_radius);
		nextpoint.y = center.y + (sin(angle) * thumb_radius);
	}
	
	// Update the thumb's position
	CGRect frame = thumbImage.frame;
	frame.origin.x = nextpoint.x - (thumbImage.frame.size.width / 2);
	frame.origin.y = nextpoint.y - (thumbImage.frame.size.height / 2);	
	thumbImage.frame = frame;
}

- (void)setMessageBox:(NSString*)str
{
	static int prevSound = 0;
	[messageBoxLabel performSelectorOnMainThread:@selector(setText:) withObject:str waitUntilDone:YES];
	
	struct timeval nowSound;
	gettimeofday(&nowSound, NULL);
	if (([str compare:ARDroneEngineLocalizeString(@"BATTERY LOW ALERT")] == NSOrderedSame) &&
		2 < (nowSound.tv_sec - prevSound))
	{
		AudioServicesPlaySystemSound(batt_id);
		prevSound = nowSound.tv_sec;
	}
}

- (void)setTakeOff:(NSNumber *)_isTakeOff
{
    BOOL isTakeOff = [_isTakeOff boolValue];
    
	UIImage *image = [UIImage imageNamed:(isTakeOff ? @"Btn_Landing_RETINA.png" : @"Btn_Take_Off_RETINA.png")];
	[takeOffButton setImage:image forState:UIControlStateNormal];
}

- (void)setEmergency:(NSNumber *)isInEmergency
{
    BOOL activateEmergency = (NO == [isInEmergency boolValue]);
	if(activateEmergency)
	{
		emergencyButton.enabled = TRUE;
		emergencyButton.alpha = 1.0;
	}
	else
	{
		emergencyButton.enabled = FALSE;
		emergencyButton.alpha = 0.5;
	}
}

- (void)hideInfos
{
	batteryLevelLabel.hidden = YES;
	batteryImageView.hidden = YES;	
}

- (void)showInfos
{
	batteryLevelLabel.hidden = (config.enableBatteryPercentage == NO);
	batteryImageView.hidden = NO;
}

- (void)showUSB:(NSNumber *)show
{
    BOOL enable = [show boolValue];

    usbImageView.hidden = (config.enableRecordButton == NO);
    if(enable)
    {
        usbImageView.alpha = 1.0;
        usbRemainingTimeLabel.alpha = 1.0;
    }
    else
    {
        usbImageView.alpha = 0.0;
        usbRemainingTimeLabel.alpha = 0.0;
    }
}

#define USB_LABEL_TEXT_LENGTH (10)
- (void)setRemainingUSBTime:(NSNumber *)remainingSeconds_objc
{
    uint32_t remainingSeconds = [remainingSeconds_objc unsignedIntValue];
    bool_t needColor = FALSE;
    static uint32_t prevRemainingTime = UINT32_MAX;
    static char prevString [USB_LABEL_TEXT_LENGTH] = {0};
    char remainingString [USB_LABEL_TEXT_LENGTH] = {0};
    if (remainingSeconds != prevRemainingTime)
    {
        if (3600 < remainingSeconds)
        {
            strncpy (remainingString, "> 1h", USB_LABEL_TEXT_LENGTH);
        }
        else if (2700 < remainingSeconds)
        {
            strncpy (remainingString, "45m", USB_LABEL_TEXT_LENGTH);
        }
        else if (1800 < remainingSeconds)
        {
            strncpy (remainingString, "30m", USB_LABEL_TEXT_LENGTH);
        }
        else if (900 < remainingSeconds)
        {
            strncpy (remainingString, "15m", USB_LABEL_TEXT_LENGTH);
        }
        else if (600 < remainingSeconds)
        {
            strncpy (remainingString, "10m", USB_LABEL_TEXT_LENGTH);
        }
        else if (300 < remainingSeconds)
        {
            strncpy (remainingString, "5m", USB_LABEL_TEXT_LENGTH);
        }
        else
        {
            if (30 > remainingSeconds)
            {
                needColor = TRUE;
            } // No else
            int remMin = remainingSeconds / 60;
            int remSec = remainingSeconds % 60;
            if (0 == remSec && 0 == remMin)
            {
                strncpy (remainingString, "FULL", USB_LABEL_TEXT_LENGTH);
            }
            else
            {
                snprintf(remainingString, USB_LABEL_TEXT_LENGTH, "%02d:%02d", remMin, remSec);
            }
        }
        prevRemainingTime = remainingSeconds;
        
        if (0 != strncmp (remainingString, prevString, USB_LABEL_TEXT_LENGTH))
        {
            [usbRemainingTimeLabel setText:[NSString stringWithCString:remainingString encoding:NSUTF8StringEncoding]];
            if (TRUE == needColor)
            {
                [usbRemainingTimeLabel setTextColor:[UIColor colorWithRed:0.816 green:0.0 blue:0.0 alpha:1.0]];
            }
            else
            {
                [usbRemainingTimeLabel setTextColor:[UIColor whiteColor]];
            }
            strncpy (prevString, remainingString, USB_LABEL_TEXT_LENGTH);
        }
    }
}

- (void)showBackToMainMenu:(NSNumber *)show
{
    BOOL enable = [show boolValue];
    NSLog (@"Show back to main menu : %s\n", (TRUE == enable ? "yes" : "no"));
    backToMainMenuButton.hidden = (config.enableBackToMainMenu == NO);
    if(enable)
    {
        mainMenuButtonHidden = NO;
        backToMainMenuButton.enabled = YES;
        backToMainMenuButton.alpha = 1.0;       
    }
    else
    {
        mainMenuButtonHidden = YES;
        backToMainMenuButton.enabled = NO;
        backToMainMenuButton.alpha = 0.0;
    }
}

- (void)showCameraButton:(NSNumber *)show
{
    BOOL enable = [show boolValue];

    cameraButton.hidden = (config.enableCameraButton == NO);
    if(enable)
    {
        cameraButton.enabled = YES;
        cameraButton.alpha = 1.0;
    }
    else
    {
        cameraButton.enabled = NO;
        cameraButton.alpha = 0.5;
    }
}

- (void)setBattery:(int)percent
{
    static int prevImage = -1;
    static int prevPercent = -1;
    static BOOL wasHidden = NO;
	if(percent < 0 && !wasHidden)
	{
		[self performSelectorOnMainThread:@selector(hideInfos) withObject:nil waitUntilDone:YES];		
        wasHidden = YES;
	}
	else if (percent >= 0)
	{
        if (wasHidden)
        {
            [self performSelectorOnMainThread:@selector(showInfos) withObject:nil waitUntilDone:YES];
            wasHidden = NO;
        }
        int imageNumber = ((percent < 10) ? 0 : (int)((percent / 33.4) + 1));
        if (prevImage != imageNumber)
        {
            UIImage *image = [UIImage imageNamed:[NSString stringWithFormat:@"Btn_Battery_%d_RETINA.png", imageNumber]];
            [batteryImageView performSelectorOnMainThread:@selector(setImage:) withObject:image waitUntilDone:YES];
            prevImage = imageNumber;
        }
        if (prevPercent != percent)
        {
            prevPercent = percent;
            [batteryLevelLabel performSelectorOnMainThread:@selector(setText:) withObject:[NSString stringWithFormat:@"%d%%", percent] waitUntilDone:YES];
        }
	}
}

- (void)initLoadingViews
{
    loadingViewsArray = [[NSMutableArray alloc] init];
    
    [loadingViewsArray addObject:tipsView00];
    [loadingViewsArray addObject:tipsView01];
    [loadingViewsArray addObject:tipsView02];
    [loadingViewsArray addObject:tipsView03];
    [loadingViewsArray addObject:tipsView04];
    [loadingViewsArray addObject:tipsView05];
    [loadingViewsArray addObject:tipsView06];
    [loadingViewsArray addObject:tipsView07];
    [loadingViewsArray addObject:tipsView08];
    [loadingViewsArray addObject:tipsView09];
    [loadingViewsArray addObject:tipsView10];
    [loadingViewsArray addObject:tipsView11];
    [loadingViewsArray addObject:tipsView12];
    
    // Set tags to remember picked up view (improves rand)
    for (int i = 0; i < loadingViewsArray.count; ++i)
        [[loadingViewsArray objectAtIndex:i] setTag:i];
}

- (void)showLoadingView:(NSNumber *)show
{    
    if ([show boolValue])
    {
        int nbMax = loadingViewsArray.count;
        
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        NSMutableArray *chosenViews = [defaults objectForKey:@"kLoadingViews"];
        if (chosenViews == nil) 
            chosenViews = [[NSMutableArray alloc] initWithCapacity:nbMax];
        
        NSMutableArray *viewsToRemove = [NSMutableArray arrayWithCapacity:nbMax];
        for (NSNumber *tagNumber in chosenViews)
        {
            for (UIView *view in loadingViewsArray)
                if (view.tag == tagNumber.intValue)
                    [viewsToRemove addObject:view];
        }
        [loadingViewsArray removeObjectsInArray:viewsToRemove];
        
        UIView *randomView = [loadingViewsArray objectAtIndex:(random() % loadingViewsArray.count)];
        [loadingView addSubview:randomView];
        [loadingView bringSubviewToFront:loadingTopBar];
        [self.view addSubview:loadingView];
        
        [chosenViews addObject:[NSNumber numberWithInt:randomView.tag]];
        if (chosenViews.count == nbMax) chosenViews = nil;
        [defaults setObject:chosenViews forKey:@"kLoadingViews"];
        [defaults synchronize];
    }
    else
    {
        [loadingView removeFromSuperview];
    }
}

- (IBAction)buttonPress:(id)sender forEvent:(UIEvent *)event 
{
    static uint64_t previous_time = 0;
    if(previous_time == 0) previous_time = mach_absolute_time();
    
    uint64_t current_time = mach_absolute_time();
    static mach_timebase_info_data_t sTimebaseInfo;
    uint64_t elapsedNano;
    float dt = 0;
    
    
	UITouch *touch = [[event touchesForView:sender] anyObject];
	CGPoint current_location = [touch locationInView:self.view];
    static CGPoint previous_location;
	bool_t acceleroModeOk = NO;
    
    
    //dt calculus function of real elapsed time
    if(sTimebaseInfo.denom == 0) (void) mach_timebase_info(&sTimebaseInfo);
    elapsedNano = (current_time-previous_time)*(sTimebaseInfo.numer / sTimebaseInfo.denom);
    dt = elapsedNano/1000000000.0;

//    NSLog(@"Time between two touches = %f",dt);
    float diff_x = current_location.x-previous_location.x;
    float diff_y = current_location.y-previous_location.y;
    float radius = sqrtf(diff_x*diff_x + diff_y*diff_y);
//    NSLog(@"PREV POINT (%d,%d)  CURR POINT (%d,%d)   DIST = %f",(int)previous_location.x,(int)previous_location.y,(int)current_location.x,(int)current_location.y,radius);
//    NSLog(@"Real radius = %f",joystickRightBackgroundImageView.frame.size.width / 2);
    
    if(dt > 0.1 && dt < 0.3 && radius < joystickRightBackgroundImageView.frame.size.width / 2
       && TRUE == loopingEnabled){
        
        if (DELAY_BETWEEN_TWO_LOOPINGS_MS < ardrone_timer_delta_ms(&loopingTimer))
        {
            string_t anim;
            snprintf (anim, STRING_T_SIZE, "%d,%d", ARDRONE_ANIM_FLIP_LEFT, MAYDAY_TIMEOUT[ARDRONE_ANIM_FLIP_LEFT]);
        ARDRONE_TOOL_CONFIGURATION_ADDEVENT(flight_anim,anim,NULL);
            ardrone_timer_update (&loopingTimer);
        }
    }
    
    previous_time = current_time;
    previous_location = current_location;
    
	if(sender == joystickRightButton)
	{
		buttonRightPressed = YES;
		// Start only if the first touch is within the pad's boundaries.
		// Allow touches to be tracked outside of the pad as long as the
		// screen continues to be pressed.
		BOOL joystickIsOutside =  ((current_location.x + (joystickRightBackgroundImageView.frame.size.width / 2) > (joystickRightButton.frame.origin.x + joystickRightButton.frame.size.width)) ||
								   (current_location.x - (joystickRightBackgroundImageView.frame.size.width / 2) < joystickRightButton.frame.origin.x) ||
								   (current_location.y + (joystickRightBackgroundImageView.frame.size.height / 2) > (joystickRightButton.frame.origin.y + joystickRightButton.frame.size.height)) ||
								   (current_location.y - (joystickRightBackgroundImageView.frame.size.height / 2) < joystickRightButton.frame.origin.y));
		
		if(joystickIsOutside && rightButtonIsJs)
		{
			AudioServicesPlaySystemSound(plop_id);
		}
		
		joystickRightCurrentPosition.x = current_location.x - (joystickRightBackgroundImageView.frame.size.width / 2);
		joystickRightCurrentPosition.y = current_location.y - (joystickRightBackgroundImageView.frame.size.height / 2);
		
		joystickRightBackgroundImageView.alpha = joystickRightThumbImageView.alpha = 1.0;
        
		// Refresh Joystick
		[self refreshJoystickRight];
		
		// Update center
		rightCenter = CGPointMake(joystickRightBackgroundImageView.frame.origin.x + (joystickRightBackgroundImageView.frame.size.width / 2), joystickRightBackgroundImageView.frame.origin.y + (joystickRightBackgroundImageView.frame.size.height / 2));
        
		// Update velocity
		[self updateVelocity:rightCenter isRight:YES];
		
		acceleroModeOk = controls_table[controlMode].Right.can_use_accelero;
		
		if(combinedYawEnabled && buttonLeftPressed)
			ctrldata.command_flag |= (1 << ARDRONE_PROGRESSIVE_CMD_COMBINED_YAW_ACTIVE);
	}
	else if(sender == joystickLeftButton)
	{
		buttonLeftPressed = YES;
        
        BOOL joystickIsOutside =  ((current_location.x + (joystickLeftBackgroundImageView.frame.size.width / 2) > (joystickLeftButton.frame.origin.x + joystickLeftButton.frame.size.width)) || (current_location.x - (joystickLeftBackgroundImageView.frame.size.width / 2) < joystickLeftButton.frame.origin.x) || (current_location.y + (joystickLeftBackgroundImageView.frame.size.height / 2) > (joystickLeftButton.frame.origin.y + joystickLeftButton.frame.size.height)) || (current_location.y - (joystickLeftBackgroundImageView.frame.size.height / 2) < joystickLeftButton.frame.origin.y));
		
		if(joystickIsOutside && leftButtonIsJs)
		{
			AudioServicesPlaySystemSound(plop_id);
		}
		
		joystickLeftCurrentPosition.x = current_location.x - (joystickLeftBackgroundImageView.frame.size.width / 2);
		joystickLeftCurrentPosition.y = current_location.y - (joystickLeftBackgroundImageView.frame.size.height / 2);
		
		joystickLeftBackgroundImageView.alpha = joystickLeftThumbImageView.alpha = 1.0;
		
		// Refresh Joystick
		[self refreshJoystickLeft];
		
		// Update center
		leftCenter = CGPointMake(joystickLeftBackgroundImageView.frame.origin.x + (joystickLeftBackgroundImageView.frame.size.width / 2), joystickLeftBackgroundImageView.frame.origin.y + (joystickLeftBackgroundImageView.frame.size.height / 2));
		
		// Update velocity
		[self updateVelocity:leftCenter isRight:NO];
        
		acceleroModeOk = controls_table[controlMode].Left.can_use_accelero;
		if(combinedYawEnabled && buttonRightPressed)
			ctrldata.command_flag |= (1 << ARDRONE_PROGRESSIVE_CMD_COMBINED_YAW_ACTIVE);
	}
	
	if(acceleroModeOk)
	{
		ctrldata.command_flag |= (1 << ARDRONE_PROGRESSIVE_CMD_ENABLE);
		if(acceleroEnabled)
		{
			// Start only if the first touch is within the pad's boundaries.
			// Allow touches to be tracked outside of the pad as long as the
			// screen continues to be pressed.
            CMMotionManager *motionManager = [ARDroneMotionManager sharedInstance].motionManager;
            CMAcceleration current_acceleration;
            float phi, theta;
            
            //Get ACCELERO values
            if(motionManager.gyroAvailable == 0 && motionManager.accelerometerAvailable == 1){
                //Only accelerometer (iphone 3GS)
                current_acceleration.x = motionManager.accelerometerData.acceleration.x;
                current_acceleration.y = motionManager.accelerometerData.acceleration.y;
                current_acceleration.z = motionManager.accelerometerData.acceleration.z;
            } else if (motionManager.deviceMotionAvailable == 1){
                //Accelerometer + gyro (iphone 4)
                current_acceleration.x = motionManager.deviceMotion.gravity.x + motionManager.deviceMotion.userAcceleration.x;
                current_acceleration.y = motionManager.deviceMotion.gravity.y + motionManager.deviceMotion.userAcceleration.y;
                current_acceleration.z = motionManager.deviceMotion.gravity.z + motionManager.deviceMotion.userAcceleration.z;
            }
            
            theta = atan2f(current_acceleration.x,sqrtf(current_acceleration.y*current_acceleration.y+current_acceleration.z*current_acceleration.z));
            phi = -atan2f(current_acceleration.y,sqrtf(current_acceleration.x*current_acceleration.x+current_acceleration.z*current_acceleration.z));
			
            //NSLog(@"Repere changed    ref_phi = %*.2f and ref_theta = %*.2f",4,phi * 180/PI,4,theta * 180/PI);
            
			[self setAcceleroRotationWithPhi:phi withTheta:theta withPsi:0];
		}
	}			
}

- (IBAction)buttonRelease:(id)sender forEvent:(UIEvent *)event 
{
	bool_t acceleroModeOk = NO;
	if(sender == joystickRightButton)
	{
		buttonRightPressed = NO;
		
		// Reinitialize joystick position
		joystickRightCurrentPosition = joystickRightInitialPosition;
		joystickRightBackgroundImageView.alpha = joystickRightThumbImageView.alpha = alpha;
		
		// Refresh joystick
		[self refreshJoystickRight];
		
		// Update center
		rightCenter = CGPointMake(joystickRightBackgroundImageView.frame.origin.x + (joystickRightBackgroundImageView.frame.size.width / 2), joystickRightBackgroundImageView.frame.origin.y + (joystickRightBackgroundImageView.frame.size.height / 2));
		
		// reset joystick
		[self updateVelocity:rightCenter isRight:YES];
		
		controls_table[controlMode].Right.up_down(0.0);
		controls_table[controlMode].Right.left_right(0.0);
        
		acceleroModeOk = controls_table[controlMode].Right.can_use_accelero;
		
		if(combinedYawEnabled)
			ctrldata.command_flag &= ~(1 << ARDRONE_PROGRESSIVE_CMD_COMBINED_YAW_ACTIVE);
	}
	else if(sender == joystickLeftButton)
	{
		//printf("button left released\n");
		buttonLeftPressed = NO;
		// Reinitialize joystick position
		joystickLeftCurrentPosition = joystickLeftInitialPosition;
		joystickLeftBackgroundImageView.alpha = joystickLeftThumbImageView.alpha = alpha;
		
		// Refresh joystick
		[self refreshJoystickLeft];
		
		// Update center
		leftCenter = CGPointMake(joystickLeftBackgroundImageView.frame.origin.x + (joystickLeftBackgroundImageView.frame.size.width / 2), joystickLeftBackgroundImageView.frame.origin.y + (joystickLeftBackgroundImageView.frame.size.height / 2));
		
		// reset joystick
		[self updateVelocity:leftCenter isRight:NO];
        
		controls_table[controlMode].Left.up_down(0.0);
		controls_table[controlMode].Left.left_right(0.0);
        
		acceleroModeOk = controls_table[controlMode].Left.can_use_accelero;
        
		if(combinedYawEnabled)
			ctrldata.command_flag &= ~(1 << ARDRONE_PROGRESSIVE_CMD_COMBINED_YAW_ACTIVE);
	}
	
	if(acceleroModeOk)
	{
		ctrldata.command_flag &= ~(1 << ARDRONE_PROGRESSIVE_CMD_ENABLE);
		if(acceleroEnabled)
		{
			[self setAcceleroRotationWithPhi:0.0 withTheta:0.0 withPsi:0.0];
		}
	}
}

- (IBAction)buttonDrag:(id)sender forEvent:(UIEvent *)event 
{
    BOOL _runOnce = YES;
    static float rightBackgoundWidth = 0.0;
    static float rightBackgoundHeight = 0.0;
    static float leftBackgoundWidth = 0.0;
    static float leftBackgoundHeight = 0.0;
    if (_runOnce)
    {
        rightBackgoundWidth = joystickRightBackgroundImageView.frame.size.width;
        rightBackgoundHeight = joystickRightBackgroundImageView.frame.size.height;
        leftBackgoundWidth = joystickLeftBackgroundImageView.frame.size.width;
        leftBackgoundHeight = joystickLeftBackgroundImageView.frame.size.height;
        _runOnce = NO;
    }
    
	UITouch *touch = [[event touchesForView:sender] anyObject];
	CGPoint point = [touch locationInView:self.view];
	bool_t acceleroModeOk = NO;
	float controlRatio = 0.5 - (CONTROL_RATIO / 2.0);
	if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
	{
		controlRatio = 0.5 - (CONTROL_RATIO_IPAD / 2.0);
	}
	
	if(sender == joystickRightButton &&
       buttonRightPressed)
	{
		if((rightCenter.x - point.x) > ((rightBackgoundWidth / 2) - (controlRatio * rightBackgoundWidth)))
		{
			float percent = ((rightCenter.x - point.x) - ((rightBackgoundWidth / 2) - (controlRatio * rightBackgoundWidth))) / ((controlRatio * rightBackgoundWidth));
			//NSLog(@"Percent (left)  : %f\n", percent);
			if(percent > 1.0)
				percent = 1.0;
			controls_table[controlMode].Right.left_right(-percent);
		}
		else if((point.x - rightCenter.x) > ((rightBackgoundWidth / 2) - (controlRatio * rightBackgoundWidth)))
		{
			float percent = ((point.x - rightCenter.x) - ((rightBackgoundWidth / 2) - (controlRatio * rightBackgoundWidth))) / ((controlRatio * rightBackgoundWidth));
			//NSLog(@"Percent (right) : %f\n", percent);
			if(percent > 1.0)
				percent = 1.0;
			controls_table[controlMode].Right.left_right(percent);
		}
		else
		{
			controls_table[controlMode].Right.left_right(0.0);
		}
        
		if((point.y - rightCenter.y) > ((rightBackgoundHeight / 2) - (controlRatio * rightBackgoundHeight)))
		{
			float percent = ((point.y - rightCenter.y) - ((rightBackgoundHeight / 2) - (controlRatio * rightBackgoundHeight))) / ((controlRatio * rightBackgoundHeight));
			//NSLog(@"Percent (down)  : %f\n", percent);
			if(percent > 1.0)
				percent = 1.0;
			controls_table[controlMode].Right.up_down(-percent);
		}
		else if((rightCenter.y - point.y) > ((rightBackgoundHeight / 2) - (controlRatio * rightBackgoundHeight)))
		{
			float percent = ((rightCenter.y - point.y) - ((rightBackgoundHeight / 2) - (controlRatio * rightBackgoundHeight))) / ((controlRatio * rightBackgoundHeight));
			//NSLog(@"Percent (top)   : %f\n", percent);
			if(percent > 1.0)
				percent = 1.0;
			controls_table[controlMode].Right.up_down(percent);
		}
		else
		{
			controls_table[controlMode].Right.up_down(0.0);
		}
        
		acceleroModeOk = controls_table[controlMode].Right.can_use_accelero;
	}
	else if(sender == joystickLeftButton
            && buttonLeftPressed)
	{
		if((leftCenter.x - point.x) > ((leftBackgoundWidth / 2) - (controlRatio * leftBackgoundWidth)))
		{
			float percent = ((leftCenter.x - point.x) - ((leftBackgoundWidth / 2) - (controlRatio * leftBackgoundWidth))) / ((controlRatio * leftBackgoundWidth));
			if(percent > 1.0)
				percent = 1.0;
			controls_table[controlMode].Left.left_right(-percent);
		}
		else if((point.x - leftCenter.x) > ((leftBackgoundWidth / 2) - (controlRatio * leftBackgoundWidth)))
		{
			float percent = ((point.x - leftCenter.x) - ((leftBackgoundWidth / 2) - (controlRatio * leftBackgoundWidth))) / ((controlRatio * leftBackgoundWidth));
			if(percent > 1.0)
				percent = 1.0;
			controls_table[controlMode].Left.left_right(percent);
		}
		else
		{
			controls_table[controlMode].Left.left_right(0.0);
		}	
		
		if((point.y - leftCenter.y) > ((leftBackgoundHeight / 2) - (controlRatio * leftBackgoundHeight)))
		{
			float percent = ((point.y - leftCenter.y) - ((leftBackgoundHeight / 2) - (controlRatio * leftBackgoundHeight))) / ((controlRatio * leftBackgoundHeight));
			if(percent > 1.0)
				percent = 1.0;
			controls_table[controlMode].Left.up_down(-percent);
		}
		else if((leftCenter.y - point.y) > ((leftBackgoundHeight / 2) - (controlRatio * leftBackgoundHeight)))
		{
			float percent = ((leftCenter.y - point.y) - ((leftBackgoundHeight / 2) - (controlRatio * leftBackgoundHeight))) / ((controlRatio * leftBackgoundHeight));
			if(percent > 1.0)
				percent = 1.0;
			controls_table[controlMode].Left.up_down(percent);
		}
		else
		{
			controls_table[controlMode].Left.up_down(0.0);
		}		
        
		acceleroModeOk = controls_table[controlMode].Left.can_use_accelero;
	}
    
	if(acceleroModeOk)
	{
		if(!acceleroEnabled)
		{
			// Update joystick velocity
			[self updateVelocity:point isRight:(sender == joystickRightButton)];
		}
	}
	else
	{
		// Update joystick velocity if needed
        BOOL isRight = (sender == joystickRightButton);
        if ((isRight && buttonRightPressed) ||
            (!isRight && buttonLeftPressed))
        {
            [self updateVelocity:point isRight:isRight];
        }
	}
    
}

- (void) checkRecordState:(NSNumber *)state
{
    bool_t b_state = ([state boolValue] == YES);
    if(b_state != ardrone_academy_navdata_get_record_ready())
    {
        [recordButton setEnabled:NO];
        [recordButton setAlpha:0.5];
        [self performSelector:@selector(checkRecordState:) withObject:state afterDelay:1.0];
    }
    else
    {
        if (ardrone_academy_navdata_get_record_ready())
        {
            UIImage *onImageBG = [UIImage imageNamed:@"Btn_Record_1_RETINA.png"];
            UIImage *onImageFG = [UIImage imageNamed:@"Btn_Record_2_RETINA.png"];
            [recordButton setBackgroundImage:onImageBG forState:UIControlStateNormal];
            [recordButton setImage:onImageFG forState:UIControlStateNormal];
            CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:@"opacity"];
            [animation setFromValue:[NSNumber numberWithFloat:0.f]];
            [animation setToValue:[NSNumber numberWithFloat:1.f]];
            [animation setDuration:0.5f];
            [animation setTimingFunction:[CAMediaTimingFunction functionWithControlPoints:0.0 :0.0 :0.0 :0.0]];
            [animation setAutoreverses:YES];
            [animation setRepeatCount:INFINITY];
            [recordButton.imageView.layer addAnimation:animation forKey:@"opacity"];
            [recordLabel setTextColor:[UIColor colorWithRed:0.816 green:0.0 blue:0.0 alpha:1.0]];
            [recordButton setEnabled:YES];
            [recordButton setAlpha:1.0];
        }
        else
        {
            UIImage *offImage = [UIImage imageNamed:@"Btn_Record_0_RETINA.png"];
            [recordButton setImage:offImage forState:UIControlStateNormal];
            [recordButton.imageView.layer removeAllAnimations];
            [recordLabel setTextColor:[UIColor whiteColor]];
            [self notifyConnexion:isConnectedToARDrone];
            if (recordPopUpDisplayed && IS_ARDRONE2)
            {
                // Call pop-up callback as if we got a timeout
                // Thus, we can still call this even if the "end record" pop-up
                // Is in the pop-up queue, and not yet displayed to the user
                [self recordFinishCallback:[NSNumber numberWithBool:YES]];
                if (NULL != recordPopUp)
                {
                    recordPopUp->timeout = 2;
                }
            }
            else if (mainMenuAfterRecordEnd && NO == mainMenuButtonHidden)
            {
                mainMenuAfterRecordEnd = NO;
                mainMenuPressed = YES;
            }
        }
            }
    
    if(!ardrone_academy_navdata_get_record_ready())
    {
        if(IS_ARDRONE1)
        {
            quicktime_encoder_stage_resume();
        }
    }
}

- (void) droneStoppedRecording
{
    [self checkRecordState:[NSNumber numberWithBool:NO]];
    [self addPopUpWithMessage:ARDroneEngineLocalizeString(@"USB drive full\nPlease connect a new one") maxDisplayTime:0 callback:nil priority:POPUP_PRIO_WARNING useProgress:NO];
}

- (void) checkRecordProgress
{
    if (IS_ARDRONE2)
    {
    if (-1.0 != hdvideo_retrieving_progress)
    {
            recordProgressViewShouldBeEmpty = NO;
            [recordPV setProgress:hdvideo_retrieving_progress];
    }
        else if (recordProgressViewShouldBeEmpty)
    {
            [recordPV setProgress:0.0];
        }
        else
        {
            [recordPV setProgress:1.0];
        }
    }
    else if (! recordPV.isHidden)
    {
        [recordPV setHidden:YES];
    }
}


/*
 * Pop-Up Management
 */

- (AR_PopUp *)addPopUpWithMessage:(NSString *)str maxDisplayTime:(int)seconds callback:(SEL)closeCb priority:(POPUP_PRIO)prio useProgress:(BOOL)usePV
{
    AR_PopUp *newPopUp = vp_os_malloc (sizeof (AR_PopUp));
    if (NULL == newPopUp)
    {
        return NULL;
    }
    newPopUp->message = [str retain];
    newPopUp->timeout = seconds;
    newPopUp->useProgressView = usePV;
    newPopUp->prio = prio;
    newPopUp->callback = closeCb;
    newPopUp->next = NULL;
    if (NULL == firstPopUp)
    {
        firstPopUp = newPopUp;
    }
    newPopUp->prev = (struct AR_PopUp_s *)lastPopUp;
    lastPopUp = newPopUp;
    if (NULL != newPopUp->prev)
    {
        AR_PopUp *prevPopUp = (AR_PopUp *)newPopUp->prev;
        prevPopUp->next = (struct AR_PopUp_s *)newPopUp;
    }

    
    [self updatePopUp];
    return newPopUp;
}

- (void) updatePopUp
{
    BOOL hasNewPopUp = NO;
    static uint32_t prevMod2Sec = 0;
    if (NULL != currentPopUp) // We have a pop-up on screen
    {
        uint64_t popUpTimerDelta = ardrone_timer_delta_ms(&popUpTimer);
        if (POPUP_PRIO_ERROR == currentPopUp->prio)
        {
            uint32_t currMod2Sec = popUpTimerDelta % 2000;
            if (currMod2Sec < prevMod2Sec)
            {
                AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);
            }
            prevMod2Sec = currMod2Sec;
        }
        // Check timeout
        if (0 < currentPopUp->timeout)
        {
            uint64_t popUpTimeoutMs = 1000ll * (uint64_t)currentPopUp->timeout;
            if (popUpTimeoutMs < popUpTimerDelta)
            {
                [self hidePopUp:YES];
            }    
        }
        else if (-1 == currentPopUp->timeout)
        {
            [self hidePopUp:NO];
        }
    }
    
    if (NULL == currentPopUp && // We don't have a pop-up on screen (may have been cleaned by the previous if)
        NULL != lastPopUp) // We have at least a pop-up in queue
    {
        // Get currentPopUp
        currentPopUp = lastPopUp;
        AR_PopUp *testPopUp = (AR_PopUp *)currentPopUp->prev;
        while (NULL != testPopUp)
        {
            if (testPopUp->prio <= currentPopUp->prio)
            {
                currentPopUp = testPopUp;
            }
            testPopUp = (AR_PopUp *)testPopUp->prev;
        }
        
        // Remove Current from Linked list
        if (currentPopUp == firstPopUp)
        {
            firstPopUp = (AR_PopUp *)currentPopUp->next;
        }
        if (currentPopUp == lastPopUp)
        {
            lastPopUp = (AR_PopUp *)currentPopUp->prev;
        }
        if (NULL != currentPopUp->prev)
        {
            AR_PopUp *prevPopUp = (AR_PopUp *)currentPopUp->prev;
            prevPopUp->next = currentPopUp->next;
        }
        if (NULL != currentPopUp->next)
        {
            AR_PopUp *nextPopUp = (AR_PopUp *)currentPopUp->next;
            nextPopUp->prev = currentPopUp->prev;
        }
        hasNewPopUp = YES;
    }
    
    if (hasNewPopUp && NULL != currentPopUp) // We have a new pop-up that we need to display
    {
        [popUpText setText:currentPopUp->message];
        [recordPV setHidden:(!currentPopUp->useProgressView)];
        recordProgressViewShouldBeEmpty = currentPopUp->useProgressView;
        [popUpView setHidden:NO];
        [popUpCloseButton setHidden:NO];
        ardrone_timer_update(&popUpTimer);
        prevMod2Sec = 0;
        if (POPUP_PRIO_WARNING >= currentPopUp->prio)
        {
            AudioServicesPlaySystemSound (kSystemSoundID_Vibrate);
        }
    }
    
}

- (void) closeCurrentPopUp
{
    if (NULL != currentPopUp)
    {
        currentPopUp->timeout = -1;
    }
    [self updatePopUp];
}

- (void)hidePopUp:(BOOL)wasTimeout
{
    [popUpView setHidden:YES];
    [recordPV setHidden:YES];
    [popUpCloseButton setHidden:YES];
    if (NULL != currentPopUp)
    {
        if (nil != currentPopUp->callback)
        {
            [self performSelector:currentPopUp->callback withObject:[NSNumber numberWithBool:wasTimeout]];
        }
        [currentPopUp->message release];
        vp_os_free (currentPopUp);
        currentPopUp = NULL;
    }
}

/*
 * End of Pop-Up section
 */

- (IBAction)buttonClick:(id)sender forEvent:(UIEvent *)event 
{
	static ARDRONE_VIDEO_CHANNEL channel = ARDRONE_VIDEO_CHANNEL_FIRST;
	if(sender == settingsButton)
	{
        
        [joystickRightButton sendActionsForControlEvents:UIControlEventTouchCancel];
        [joystickLeftButton sendActionsForControlEvents:UIControlEventTouchCancel];
        settingsPressed = YES;
	}
    else if(sender == backToMainMenuButton)
    {
        if (NO == mainMenuButtonHidden)
        {
            if (FALSE == ardrone_academy_navdata_get_record_ready())
            {
		mainMenuPressed = YES;
            }
            else
            {
                BOOL displayPopUp = (IS_ARDRONE2 ? YES : NO);
                [self switchRecord:displayPopUp backToMain:YES];
            }
            
        }
	}
    else if(sender == switchScreenButton)
	{
		if(channel++ == ARDRONE_VIDEO_CHANNEL_LAST)
			channel = ARDRONE_VIDEO_CHANNEL_FIRST;
		
		ARDRONE_TOOL_CONFIGURATION_ADDEVENT(video_channel, (int32_t*)&channel, NULL);
	}
	else if(sender == cameraButton)
	{
        ardrone_academy_navdata_screenshot();
	}
	else if(sender == takeOffButton)
	{
        bool_t isFlying = ardrone_academy_navdata_get_takeoff_state();
		if (TRUE == ardrone_academy_navdata_takeoff() &&
            FALSE == isFlying) {
            [self showBackToMainMenu:[NSNumber numberWithBool:NO]];
        }
	}
	else if(sender == emergencyButton)
	{
		ardrone_academy_navdata_emergency();
	}
    else if(sender == latencyButton)
    {
        if (LE_DISABLED == vlat.state)
        {
            NSLog (@"Will enable lat estimator\n");
            vlat.state = LE_WAITING;
        }
        else
        {
            NSLog (@"Will disable lat estimator (state was %d)\n", vlat.state);
            vlat.state = LE_DISABLED;
        }
        
        [self checkLatency];
    }
    else if(sender == recordButton)
    {
        BOOL displayPopUp = (IS_ARDRONE2 ? DISPLAY_RECORD_POPUP_DRONE2 : NO);
        [self switchRecord:displayPopUp backToMain:NO];
    }
    else if(sender == popUpCloseButton)
    {
        [self closeCurrentPopUp];
    }
}

- (void)recordFinishCallback:(NSNumber *)_boolIsTimeout
{
    if (! IS_ARDRONE2)
    {
        // Don't do anything for AR.Drone 1
        return;
    }
    recordPopUpDisplayed = NO;
    BOOL isTimeout = [_boolIsTimeout boolValue];
    if (! isTimeout)
    {
        video_stage_encoded_recorder_force_stop();
    }
    if (mainMenuAfterRecordEnd)
    {        
        mainMenuButtonHidden = NO;
        backToMainMenuButton.alpha = 1.0;
        backToMainMenuButton.enabled = YES;
        cameraButton.alpha = 1.0;
        cameraButton.enabled = YES;
        settingsButton.alpha = 1.0;
        settingsButton.enabled = YES;
        mainMenuPressed = YES;
        mainMenuAfterRecordEnd = NO;
    }
}

- (void)switchRecord:(BOOL)showPopUp backToMain:(BOOL)shouldGoBack
{
    static BOOL displayARDrone1StopRecordPopup = YES;
        bool_t record_state = ardrone_academy_navdata_get_record_ready();
        if (TRUE == ardrone_academy_navdata_record())
        {
        if (record_state)
          {
            video_stage_encoded_recorder_enable (0, 0);
                if (IS_ARDRONE1 &&
                    displayARDrone1StopRecordPopup)
                {
                [self addPopUpWithMessage:ARDroneEngineLocalizeString(@"Your video is being processed\nPlease do not close the application\nIt will appear shortly in the video section") maxDisplayTime:5 callback:nil priority:POPUP_PRIO_MESSAGE useProgress:NO];
                    displayARDrone1StopRecordPopup = NO;
                }
            if (showPopUp)
            {
                if (shouldGoBack)
                {
                    mainMenuButtonHidden = YES;
                    backToMainMenuButton.alpha = 0.0;
                    backToMainMenuButton.enabled = NO;
                    cameraButton.alpha = 0.5;
                    cameraButton.enabled = NO;
                    settingsButton.alpha = 0.5;
                    settingsButton.enabled = NO;
                }
                recordPopUp = [self addPopUpWithMessage:ARDroneEngineLocalizeString(@"Please wait until the end of the recording") maxDisplayTime:0 callback:@selector(recordFinishCallback:) priority:(shouldGoBack ? POPUP_PRIO_WARNING : POPUP_PRIO_MESSAGE) useProgress:YES];
                recordPopUpDisplayed = YES;
            }
            mainMenuAfterRecordEnd = shouldGoBack;
          }
        [self checkRecordState:[NSNumber numberWithBool:(record_state == FALSE)]];
    }
}

- (void)checkLatency
{
    if (LE_DISABLED == vlat.state)
    {
        [latencyButton setTitle:@"Latency Test" forState:UIControlStateNormal];
    }
    else
    {
        [latencyButton setTitle:@"Stop Test" forState:UIControlStateNormal];
    }
}

- (void)viewDidLoad
{
    [self initLoadingViews];
    [self showLoadingView:[NSNumber numberWithBool:YES]];
#ifndef INTERFACE_WITH_DEBUG
    // Disable debug buttons/area while not in debug mode
    debugText.hidden = YES;
    latencyButton.hidden = YES;
#endif
    
	switchScreenButton.hidden = (config.enableSwitchScreen == NO);
	backToMainMenuButton.hidden = (config.enableBackToMainMenu == NO);
	batteryLevelLabel.hidden = (config.enableBatteryPercentage == NO);
    recordButton.hidden = (config.enableRecordButton == NO);
    recordLabel.hidden = (config.enableRecordButton == NO);

    [self showCameraButton:[NSNumber numberWithBool:NO]];
    [self showUSB:[NSNumber numberWithBool:NO]];
    [recordPV setHidden:YES];
     
	rightCenter = CGPointMake(joystickRightThumbImageView.frame.origin.x + (joystickRightThumbImageView.frame.size.width / 2), joystickRightThumbImageView.frame.origin.y + (joystickRightThumbImageView.frame.size.height / 2));
	joystickRightInitialPosition = CGPointMake(rightCenter.x - (joystickRightBackgroundImageView.frame.size.width / 2), rightCenter.y - (joystickRightBackgroundImageView.frame.size.height / 2));
	leftCenter = CGPointMake(joystickLeftThumbImageView.frame.origin.x + (joystickLeftThumbImageView.frame.size.width / 2), joystickLeftThumbImageView.frame.origin.y + (joystickLeftThumbImageView.frame.size.height / 2));
	joystickLeftInitialPosition = CGPointMake(leftCenter.x - (joystickLeftBackgroundImageView.frame.size.width / 2), leftCenter.y - (joystickLeftBackgroundImageView.frame.size.height / 2));
    
	joystickLeftCurrentPosition = joystickLeftInitialPosition;
	joystickRightCurrentPosition = joystickRightInitialPosition;
	
	alpha = MIN(joystickRightBackgroundImageView.alpha, joystickRightThumbImageView.alpha);
	joystickRightBackgroundImageView.alpha = joystickRightThumbImageView.alpha = alpha;
	joystickLeftBackgroundImageView.alpha = joystickLeftThumbImageView.alpha = alpha;
    
    leftButtonIsJs = NO;
    rightButtonIsJs = YES;
    
    // Get the URL to the sound file to play
	CFURLRef batt_url  = CFBundleCopyResourceURL (CFBundleGetMainBundle(),
                                                  CFSTR ("battery"),
                                                  CFSTR ("wav"),
												  NULL);
    CFURLRef plop_url  = CFBundleCopyResourceURL (CFBundleGetMainBundle(),
                                                  CFSTR ("plop"),
                                                  CFSTR ("wav"),
                                                  NULL);
	
    // Create a system sound object representing the sound file
    AudioServicesCreateSystemSoundID (plop_url, &plop_id);
    AudioServicesCreateSystemSoundID (batt_url, &batt_id);
	CFRelease(plop_url);
	CFRelease(batt_url);
	
	[self setBattery:-1];
}

- (void) setWifiLevel:(float)level
{
    static int prev_number = -1;
    int bar_number = 1;
    
    if (0.66 < level) { bar_number = 3; }
    else if (0.33 < level) { bar_number = 2; }
    else if (0.0 > level) { bar_number = 0; }
    else { bar_number = 1; };
    
    if (bar_number != prev_number)
    {
        prev_number = bar_number;
        [wifiLevelImageView performSelectorOnMainThread:@selector(setImage:) withObject:[UIImage imageNamed:[NSString stringWithFormat:@"Btn_Wi-Fi_%d_RETINA.png", bar_number]] waitUntilDone:YES];
    }
}

- (void) notifyConnexion:(BOOL)connected
{
    isConnectedToARDrone = connected;
    float alphaValue = (connected ? 1.0 : 0.5);
    [cameraButton setEnabled:connected];
    [cameraButton setAlpha:alphaValue];
    
    if (! ardrone_academy_navdata_get_record_ready ())
    {
        [recordButton setEnabled:connected];
        [recordButton setAlpha:alphaValue];
    }
}

- (void) dealloc 
{
    [locationManager stopUpdatingLocation];
	locationManager.delegate = nil;
    [locationManager release];
    [loadingViewsArray release];
    
    /* Clean pop-up linked list */
    AR_PopUp *testPopUp = firstPopUp;
    while (NULL != testPopUp)
    {
        AR_PopUp *nextPopUp = (AR_PopUp *)testPopUp->next;
        if (currentPopUp != testPopUp)
        {
            [testPopUp->message release];
            vp_os_free (testPopUp);
        }
        testPopUp = nextPopUp;
    }
    
    if (NULL != currentPopUp)
    {
        [currentPopUp->message release];
        vp_os_free (currentPopUp);
    }
    
#ifdef WRITE_DEBUG_ACCELERO
	fclose(mesures_file);
#endif
	AudioServicesDisposeSystemSoundID (plop_id);
	AudioServicesDisposeSystemSoundID (batt_id);
	[super dealloc];
}

@end
