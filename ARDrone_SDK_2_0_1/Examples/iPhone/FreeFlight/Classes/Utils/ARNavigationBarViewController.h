//
//  ARNavigationBarViewController.h
//  FreeFlight
//
//  Created by Nicolas Payot on 11/10/11.
//  Copyright 2011 PARROT. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "Common.h"
#import "ARUtils.h"

typedef enum 
{ 
    AR_SEARCH_BUTTON,
    AR_PLUS_BUTTON,
    AR_MINUS_BUTTON,
    AR_SHARE_BUTTON
} ARNavBarRightButton;

@class ARButton;
@interface ARNavigationBarViewController : UIViewController <UIImagePickerControllerDelegate, UINavigationControllerDelegate> {
    IBOutlet UIButton *leftButton;
    IBOutlet UILabel *titleLabel;
    IBOutlet UIButton *searchButton;
    IBOutlet UIButton *plusButton;
    IBOutlet UIButton *minusButton;
    IBOutlet ARButton *shareButton;
    ARNavBarRightButton rightButtonType;
    IBOutlet UIButton *backPageButton;
    IBOutlet UIButton *nextPageButton;
    IBOutlet UIView *whiteSeparator;
}

@property (nonatomic, retain) UIButton *leftButton;
@property (nonatomic, retain) UIButton *rightButton;
@property (nonatomic, readonly) ARNavBarRightButton rightButtonType;
@property (nonatomic, retain) UIButton *backPageButton;
@property (nonatomic, retain) UIButton *nextPageButton;

- (void)setViewTitle:(NSString *)title;
- (void)displayHomeButton;
- (void)displayBackButton;
- (void)displayRightButton:(ARNavBarRightButton)button;
- (void)moveOnTop;
- (void)setTransparentStyle:(BOOL)transparent;
- (void)alignViewTitleRight;
- (void)alignViewTitleLeft;
- (void)displayWebPagesControls:(BOOL)display;

@end
