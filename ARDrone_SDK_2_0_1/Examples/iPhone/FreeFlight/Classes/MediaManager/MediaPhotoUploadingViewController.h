//
//  MediaPhotoUploadingViewController.h
//  FreeFlight
//
//  Created by Frédéric D'Haeyer on 11/22/11.
//  Copyright 2011 Parrot SA. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "GoogleAPIManager.h"
#import "GoogleAPISignViewController.h"
#import "ARUtils.h"

@interface MediaPhotoUploadingViewController : UIViewController <GoogleAPIManagerDelegate, UITextFieldDelegate, UITextViewDelegate, UIAlertViewDelegate, UIPickerViewDelegate, ARLoadingViewDelegate>
{
    ARNavigationBarViewController *navBar;
    GoogleAPIManagerEntry *photoEntry;
    NSString *assetURLString;
    ARLoadingViewController *loadingViewController;
    UIView *activeTextView;
    NSMutableArray *albums;
    ARToolbar *toolbar;
    ARPickerViewController  *albumsPickerView;
    
    IBOutlet UITextField *photoTitle;
    IBOutlet UITextView *photoDescription;
    IBOutlet UITextView *photoTags;
    
    IBOutlet UIButton *selectAlbumButton;
    IBOutlet UITextField *albumTitle;
    IBOutlet ARButton *privateButton;
    IBOutlet ARButton *publicButton;
    IBOutlet ARButton *uploadButton;
    IBOutlet UIButton *plusButton;
    BOOL shouldShowAlbumsPicker;
    IBOutlet UIActivityIndicatorView *spinner;
    IBOutlet UIScrollView *scrollView;
    BOOL newAlbumAccess;
    BOOL needAuthRequest;
    
    IBOutlet UILabel *titleLabel;
    IBOutlet UILabel *descriptionLabel;
    IBOutlet UILabel *tagsLabel;
    
    BOOL needsToBeUploaded;
    BOOL viewDidLoad;
}

@property (nonatomic, retain) NSString *assetURLString;
@property (nonatomic, retain) GoogleAPIManagerEntry *photoEntry;

- (IBAction)selectAlbumButtonClicked;
- (IBAction)privateButtonClicked;
- (IBAction)publicButtonClicked;
- (IBAction)uploadButtonClicked:(id)sender;
- (IBAction)plusButtonClicked:(id)sender;

@end
