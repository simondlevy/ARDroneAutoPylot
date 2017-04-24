//
//  ARStatusBarViewController.h
//  FreeFlight
//
//  Created by Nicolas Payot on 07/10/11.
//  Copyright 2011 PARROT. All rights reserved.
//

#import <UIKit/UIKit.h>

@class ARStatusBarViewController;

@protocol ARStatusBarDelegate <NSObject>
- (void)statusBarPreferencesClicked:(ARStatusBarViewController *)bar;
@end

@interface ARStatusBarViewController : UIViewController {
    id <ARStatusBarDelegate> _delegate;
    IBOutlet UIImageView *batteryIcon;
    IBOutlet UILabel *batteryLabel;
    IBOutlet UIImageView *timeIcon;
    IBOutlet UILabel *timeLabel;
    IBOutlet UIImageView *settingsIcon;
    IBOutlet UIButton *settingsButton;
}

@property (nonatomic, assign) id <ARStatusBarDelegate> delegate;

- (void)updateBatteryLevel;
- (void)updateWatch;
- (IBAction)openSettings;

@end
