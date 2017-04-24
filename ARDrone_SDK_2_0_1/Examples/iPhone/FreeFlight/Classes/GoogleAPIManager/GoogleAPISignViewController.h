//
//  GoogleAPISignViewController.h
//  FreeFlight
//
//  Created by Frederic D'HAEYER on 30/11/11.
//  Copyright 2011 PARROT. All rights reserved.
//
#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import "GoogleAPIManager.h"
#import "MenuController.h"
#import "ARUtils.h"

@class ARStatusBarViewController;
@class ARNavigationBarViewController;

@interface GoogleAPISignViewController : UIViewController <UITextFieldDelegate, GoogleAPIManagerDelegate> {
    ARNavigationBarViewController *navBar;
    IBOutlet UITextField *loginTextField;
    IBOutlet UITextField *passwordTextField;
    IBOutlet ARButton *signInButton;
    UITextField *activeTextField;
    IBOutlet UIButton *yesButton;
    IBOutlet UIButton *noButton;
    IBOutlet UIImageView *yesPin;
    IBOutlet UIImageView *noPin;
    IBOutlet UIScrollView *scrollView;
    BOOL rememberCredentials;
    ARLoadingViewController *loadingViewController;
    
    IBOutlet UILabel *loginLabel;
    IBOutlet UILabel *passwordLabel;
    IBOutlet UILabel *rememberLabel;
}

- (IBAction)signIn;
- (IBAction)rememberGoogleCredentials:(id)sender;

@end
