//
//  ARLoadingViewController.h
//  FreeFlight
//
//  Created by Nicolas Payot on 16/12/11.
//  Copyright (c) 2011 PARROT. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "ARUtils.h"

/** #################### ARActivityIndicatorView Interface #################### **/

@interface ARActivityIndicatorView : UIImageView {
    // Nothing here
}
@end

/** #################### ARProgressView Interface #################### **/

@interface ARProgressView : UIProgressView {
    // Nothing here
}
@end

/** #################### ARLoadingViewDelegate #################### **/

@class ARLoadingViewController;

@protocol ARLoadingViewDelegate <NSObject>
@optional
- (void)loadingViewControllerCancelButtonClicked:(ARLoadingViewController *)loadingViewController;
@end

/** #################### ARLoadingViewController #################### **/

@class ARButton;
@interface ARLoadingViewController : UIViewController 
{
    id<ARLoadingViewDelegate> _delegate;
    IBOutlet UIView *topView;
    IBOutlet UIView *indicatorView;
    ARActivityIndicatorView *spinner;
    IBOutlet ARProgressView *progressBar;
    IBOutlet UILabel *loadingLabel;
    IBOutlet ARButton *cancelButton;
}

@property (nonatomic, assign) id<ARLoadingViewDelegate> delegate;

- (id)initWithDelegate:(id<ARLoadingViewDelegate>)delegate;
- (void)showView;
- (void)hideView;
- (void)addImageWithName:(NSString *)imageName;
- (void)displaySpinner;
- (void)displayProgressBar;
- (void)setProgressBarValue:(CGFloat)val;
- (void)setLoadingText:(NSString *)loadingText;
- (void)displayCancelButton:(BOOL)display;
- (void)setCancelButtonTitle:(NSString *)title;
- (IBAction)cancelButtonClicked:(id)sender;

@end
