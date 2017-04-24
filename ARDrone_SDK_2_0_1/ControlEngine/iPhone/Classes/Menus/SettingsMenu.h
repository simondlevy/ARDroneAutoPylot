#include "ConstantsAndMacros.h" 
#import "ARDrone.h"
#import "ARSlider.h"

// Just used to change background color when button highlighted
@interface ARMenuSettingsButton : UIButton 
{
    // Nothing here
}
@end

typedef enum CONTROL_MODE
{
	CONTROL_MODE3,
	CONTROL_MODE2,
	CONTROL_MODE1,
	CONTROL_MODE4,
	CONTROL_MODE_MAX,
} CONTROL_MODE;

typedef struct 
{
	BOOL  logsActivated;
} SettingsParams;

//#define DECLARE_PAGE(NAME) IBOutlet UIView *NAME##Page
//
//#define INIT_PAGE(NAME)  NAME##Page = nil
//
//#define DEFINE_PAGE(NAME)                       \
//if(NAME##Page != nil)                           \
//{                                               \
//    NAME##Page.frame = frame;                   \
//    frame.origin.x += frame.size.width;         \
//    scrollView.contentSize = CGSizeMake(scrollView.contentSize.width + scrollView.frame.size.width, scrollView.frame.size.height);          \
//    [scrollView addSubview:NAME##Page];         \
//    pagesNumber++;                              \
//}

@protocol SettingsMenuDelegate<NSObject>

- (void)acceleroValueChanged:(bool_t)enabled;
- (void)magnetoValueChanged:(bool_t)enabled;
- (void)combinedYawValueChanged:(bool_t)enabled;
- (void)loopingActiveValueChanged:(bool_t)enabled;
- (void)controlModeChanged:(CONTROL_MODE)mode;
- (void)interfaceAlphaValueChanged:(CGFloat)value;
@end

@interface SettingsMenu : UIViewController <UIScrollViewDelegate, UIAlertViewDelegate> {
    // Settings pages
    IBOutlet UIScrollView *scrollView;

    IBOutlet UIView *personalSettingsPage;
    IBOutlet UIView *flightSettingsPage;
    IBOutlet UIView *pilotingModePage;
    IBOutlet UIView *videoSettingsPage;
    IBOutlet UIView *statusPage;
    IBOutlet UIView *debugPage;
    
    NSMutableArray *pagesArray;
    NSMutableArray *pagesArrayTitle;
    
    // Settings field
	IBOutlet UILabel  *pairingText;
	IBOutlet UIButton *pairingSwitch;
    
	IBOutlet UILabel  *outdoorFlightText;
    IBOutlet UIButton *outdoorFlightSwitch;
    
	IBOutlet UILabel  *outdoorShellText;
    IBOutlet UIButton *outdoorShellSwitch;

	IBOutlet UILabel  *acceleroDisabledText;
	IBOutlet UIButton *acceleroDisabledSwitch;

	IBOutlet UILabel  *magnetoText;
	IBOutlet UIButton *magnetoSwitch;
	
    IBOutlet UILabel  *leftHandedText;
    IBOutlet UIButton *leftHandedSwitch;
	
	IBOutlet UILabel  *adaptiveVideoText;
    IBOutlet UIButton *adaptiveVideoSwitch;

    IBOutlet UILabel  *videoRecordOnUSBText;
    IBOutlet UIButton *videoRecordOnUSBSwitch;
    
    IBOutlet UILabel *loopingEnabledLabel;
    IBOutlet UIButton *enableLoopingSwitch;

    IBOutlet UILabel  *videoCodecText;
    IBOutlet UISegmentedControl *videoCodecSwitch;

	IBOutlet ARMenuSettingsButton *clearButton;
	IBOutlet ARMenuSettingsButton *flatTrimButton;
	IBOutlet UIButton *okButton;
    IBOutlet UIPageControl *pageControl;
	
    IBOutlet UIButton *previous;
    IBOutlet UIButton *next;
    
	IBOutlet UILabel  *altitudeLimitedText;
    IBOutlet UILabel  *altitudeLimitedCurrentLabel;
    IBOutlet ARSlider *altitudeLimitedSlider;

	IBOutlet UILabel  *droneTiltText;
    IBOutlet UILabel  *droneTiltCurrentLabel;
    IBOutlet ARSlider *droneTiltSlider;
	
	IBOutlet UILabel  *iPhoneTiltText;
    IBOutlet UILabel  *iPhoneTiltCurrentLabel;
    IBOutlet ARSlider *iPhoneTiltSlider;

	IBOutlet UILabel  *verticalSpeedText;
    IBOutlet UILabel  *verticalSpeedCurrentLabel;
	IBOutlet ARSlider *verticalSpeedSlider;
	
	IBOutlet UILabel  *yawSpeedText;
    IBOutlet UILabel  *yawSpeedCurrentLabel;
    IBOutlet ARSlider *yawSpeedSlider;
	    
	IBOutlet UILabel  *droneSSIDText;
	IBOutlet UITextField *droneSSIDTextField;
	
	IBOutlet UILabel  *interfaceAlphaText;
	IBOutlet UILabel  *interfaceAlphaCurrentLabel;
	IBOutlet ARSlider *interfaceAlphaSlider;

    IBOutlet UILabel  *appNameLabel;

	IBOutlet UILabel  *softwareVersion;
	IBOutlet UILabel  *droneHardVersion, *droneSoftVersion;
	IBOutlet UILabel  *dronePicHardVersion, *dronePicSoftVersion;
	IBOutlet UILabel  *droneMotor1HardVersion, *droneMotor1SoftVersion, *droneMotor1SupplierVersion;
	IBOutlet UILabel  *droneMotor2HardVersion, *droneMotor2SoftVersion, *droneMotor2SupplierVersion;
	IBOutlet UILabel  *droneMotor3HardVersion, *droneMotor3SoftVersion, *droneMotor3SupplierVersion;
	IBOutlet UILabel  *droneMotor4HardVersion, *droneMotor4SoftVersion, *droneMotor4SupplierVersion;
	
	IBOutlet UILabel  *viewTitleLabel;	
	IBOutlet UILabel  *softwareVersionText;
	IBOutlet UILabel  *droneVersionText, *droneHardVersionText, *droneSoftVersionText;
	IBOutlet UILabel  *dronePicVersionText, *dronePicHardVersionText, *dronePicSoftVersionText;
	IBOutlet UILabel  *droneMotorVersionsText;
	IBOutlet UILabel  *droneMotor1HardVersionText, *droneMotor1SoftVersionText, *droneMotor1SupplierVersionText, *droneMotor1Text;
	IBOutlet UILabel  *droneMotor2HardVersionText, *droneMotor2SoftVersionText, *droneMotor2SupplierVersionText, *droneMotor2Text;
	IBOutlet UILabel  *droneMotor3HardVersionText, *droneMotor3SoftVersionText, *droneMotor3SupplierVersionText, *droneMotor3Text;
	IBOutlet UILabel  *droneMotor4HardVersionText, *droneMotor4SoftVersionText, *droneMotor4SupplierVersionText, *droneMotor4Text;
	
    IBOutlet UIButton *magnetoCalibButton;
    
    // Debug page outlets
	IBOutlet UIButton *clearLogsButton;
    IBOutlet UIButton *logsSwitch;
    
    IBOutlet UILabel  *cocardeRangeCurrent;
    IBOutlet ARSlider *cocardeRangeSlider;

	IBOutlet UILabel  *videoThreadPriorityText;
	IBOutlet UISlider *videoThreadPrioritySlider;
	IBOutlet UILabel  *videoThreadPriorityCurrentLabel;

	IBOutlet UILabel  *atThreadPriorityText;
	IBOutlet UISlider *atThreadPrioritySlider;
	IBOutlet UILabel  *atThreadPriorityCurrentLabel;
    
    BOOL flyingState;
}

@property (nonatomic, retain) NSMutableArray *pagesArray;
@property (nonatomic, retain) NSMutableArray *pagesArrayTitle;

- (id)initWithFrame:(CGRect)frame AndHUDConfiguration:(ARDroneHUDConfiguration)configuration withDelegate:(id <SettingsMenuDelegate>)delegate;
- (void)switchDisplay;
- (void)configChanged;
- (void)saveIPhoneSettings;
- (void)loadIPhoneSettings;
- (void)toggleSwitch:(UIButton *)Switch;
- (void)setSwitch:(UIButton *)Switch withValue:(BOOL)checked;
- (IBAction)switchClick:(id)sender;
- (IBAction)valueChanged:(id)sender;
- (IBAction)sliderRelease:(id)sender;
- (IBAction)buttonClick:(id)sender;
- (IBAction)logsChanged:(id)sender;
- (void)setFlyingState:(NSNumber *)flyingState;
@end
