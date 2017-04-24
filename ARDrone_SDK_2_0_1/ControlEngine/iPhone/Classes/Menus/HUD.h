#include "ConstantsAndMacros.h"
#import "ARDrone.h"
#import "SettingsMenu.h"

typedef void (*control_callback)(float percent);

typedef struct Joystick
{
	// Value between -1.0 and 1.0
	bool_t can_use_accelero;
	control_callback up_down;
	control_callback left_right;
} JOYSTICK;

typedef struct Controls
{
	JOYSTICK Left;
	JOYSTICK Right;
} CONTROLS;

typedef enum
{
    POPUP_PRIO_ERROR = 0,
    POPUP_PRIO_WARNING,
    POPUP_PRIO_MESSAGE,
} POPUP_PRIO; // Less is the most urgent to show


typedef struct AR_Popup_s
{
    POPUP_PRIO prio;
    int timeout; // Set timeout to zero = unlimited
    SEL callback;
    BOOL useProgressView;
    NSString *message;
    struct AR_PopUp_s *next;
    struct AR_PopUp_s *prev;
} AR_PopUp;


@interface HUD : UIViewController <UIAccelerometerDelegate, SettingsMenuDelegate, CLLocationManagerDelegate> {
    IBOutlet UILabel	 *messageBoxLabel;
    IBOutlet UILabel	 *batteryLevelLabel;
	
	IBOutlet UIImageView *batteryImageView;
	IBOutlet UIImageView *joystickRightThumbImageView;
	IBOutlet UIImageView *joystickRightBackgroundImageView;
	IBOutlet UIImageView *joystickLeftThumbImageView;
	IBOutlet UIImageView *joystickLeftBackgroundImageView;
    
    IBOutlet UIImageView *wifiLevelImageView;
    IBOutlet UIImageView *usbImageView;
    IBOutlet UILabel     *usbRemainingTimeLabel;

	IBOutlet UIView      *loadingView;
    IBOutlet UIView      *loadingTopBar;
    IBOutlet UILabel     *loadingLabel;
    IBOutlet UIView      *tipsView00;
    IBOutlet UIView      *tipsView01;
    IBOutlet UIView      *tipsView02;
    IBOutlet UIView      *tipsView03;
    IBOutlet UIView      *tipsView04;
    IBOutlet UIView      *tipsView05;
    IBOutlet UIView      *tipsView06;
    IBOutlet UIView      *tipsView07;
    IBOutlet UIView      *tipsView08;
    IBOutlet UIView      *tipsView09;
    IBOutlet UIView      *tipsView10;
    IBOutlet UIView      *tipsView11;
    IBOutlet UIView      *tipsView12;
    
	IBOutlet UIButton	 *backToMainMenuButton;
	IBOutlet UIButton    *settingsButton;
	IBOutlet UIButton    *switchScreenButton;
	IBOutlet UIButton    *cameraButton;
    IBOutlet UIButton    *takeOffButton;
	IBOutlet UIButton	 *emergencyButton;
	
	IBOutlet UIButton	 *joystickRightButton;
	IBOutlet UIButton	 *joystickLeftButton;
    
    IBOutlet UIButton    *recordButton;
    IBOutlet UILabel     *recordLabel;
    
    BOOL screenOrientationRight;

    /**
     * Pop-up outlets
     */
    IBOutlet UIButton    *popUpCloseButton;
    IBOutlet UILabel     *popUpText;
    IBOutlet UIView      *popUpView;
    /* Pop-up internals */
    AR_PopUp             *firstPopUp;
    AR_PopUp             *lastPopUp;
    AR_PopUp             *currentPopUp;
    ardrone_timer_t       popUpTimer;

    
    /**
     * Record Pop-up
     */
    BOOL mainMenuAfterRecordEnd;
    BOOL recordPopUpDisplayed;
    AR_PopUp             *recordPopUp;
    IBOutlet UIProgressView *recordPV;
    BOOL recordProgressViewShouldBeEmpty;

    /**
     * DEBUG OUTLETS
     */
    IBOutlet UITextView  *debugText;
    IBOutlet UIButton *latencyButton;
	
    /**
     * Internal variables
     */
	BOOL firePressed;
	BOOL settingsPressed;
	BOOL mainMenuPressed;
    BOOL mainMenuButtonHidden;
    ardrone_timer_t      loopingTimer;
	
	CONTROLS controls;
    
    CLLocationManager *locationManager;
}

@property (nonatomic, assign) BOOL firePressed;
@property (nonatomic, assign) BOOL settingsPressed;
@property (nonatomic, assign) BOOL mainMenuPressed;
@property (nonatomic, assign) BOOL screenOrientationRight;
@property (nonatomic, retain) CLLocationManager *locationManager;

- (id)initWithFrame:(CGRect)frame withState:(BOOL)inGame withHUDConfiguration:(ARDroneHUDConfiguration)hudconfiguration;
- (void)setMessageBox:(NSString*)str;
- (AR_PopUp *)addPopUpWithMessage:(NSString*)str maxDisplayTime:(int)seconds callback:(SEL)closeCb priority:(POPUP_PRIO)prio useProgress:(BOOL)usePV;
- (void)updatePopUp;
- (void)closeCurrentPopUp;
- (void)hidePopUp:(BOOL)wasTimeout;
- (void)setTakeOff:(NSNumber *)_isTakeOff;
- (void)setEmergency:(NSNumber *)isInEmergency;
- (void)setBattery:(int)percent;
- (void)setWifiLevel:(float)level;
- (void)changeState:(BOOL)inGame;
- (void)showBackToMainMenu:(NSNumber *)show;
- (void)showCameraButton:(NSNumber *)show;
- (void)showUSB:(NSNumber *)show;
- (void)setRemainingUSBTime:(NSNumber *)remainingSeconds_objc;
- (void)droneStoppedRecording;
- (void)showLoadingView:(NSNumber *)show;
- (void)checkLatency;
- (void)checkRecordState:(NSNumber *)state;
- (void)checkRecordProgress;
- (void)notifyConnexion:(BOOL)connected;
- (void)switchRecord:(BOOL)showPopUp backToMain:(BOOL)shouldGoBack;
- (void)recordFinishCallback:(NSNumber *)_boolIsTimeout;

- (IBAction)buttonPress:(id)sender forEvent:(UIEvent *)event;
- (IBAction)buttonRelease:(id)sender forEvent:(UIEvent *)event;
- (IBAction)buttonClick:(id)sender forEvent:(UIEvent *)event;
- (IBAction)buttonDrag:(id)sender forEvent:(UIEvent *)event;
@end
