//
//  MediaVideoUploadingViewController.h
//  FreeFlight
//
//  Created by Frédéric D'Haeyer on 11/22/11.
//  Copyright 2011 Parrot SA. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "GoogleAPIManager.h"
#import "GoogleAPISignViewController.h"
#import "ARUtils.h"
#import "Common.h"

@interface MediaVideoUploadingViewController : UIViewController <GoogleAPIManagerDelegate, UITextFieldDelegate, UITextViewDelegate, UIAlertViewDelegate, ARLoadingViewDelegate>
{
    ARNavigationBarViewController *navBar;

    GoogleAPIManagerEntry *videoEntry;
    
    NSString *assetURLString;

    ARLoadingViewController *loadingViewController;
    UIView *activeTextView;
    
    NSMutableDictionary *categories;
    ARToolbar *toolbar;
    ARPickerViewController *categoriesPickerView;
    
    IBOutlet UILabel *titleLabel;
    IBOutlet UILabel *descriptionLabel;
    IBOutlet UILabel *tagsLabel;
    IBOutlet ARButton *privateButton;
    IBOutlet ARButton *publicButton;
    IBOutlet ARButton *uploadButton;
    
    IBOutlet UITextField    *videoTitle;
    IBOutlet UITextView     *videoTags;
    IBOutlet UITextView     *videoDescription;

    IBOutlet UITextField    *videoCategory;
    IBOutlet UIButton       *selectCategoryButton;
    
    IBOutlet UIScrollView *scrollView;
    IBOutlet UIActivityIndicatorView *spinner;
    IBOutlet UILabel        *usernameLabel;
    BOOL privateVideo;
    BOOL needAuthRequest;
    BOOL viewDidLoad;
}

@property (nonatomic, retain) NSString *assetURLString;
@property (nonatomic, retain) GoogleAPIManagerEntry *videoEntry;

- (IBAction)selectCategoryButtonClicked;
- (IBAction)privateButtonClicked;
- (IBAction)publicButtonClicked;
- (IBAction)uploadButtonClicked;

@end
