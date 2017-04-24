//
//  MenuGuestSpace.h
//  FreeFlight
//
//  Created by Nicolas on 11/10/11.
//  Copyright 2011 Parrot. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "MenuController.h"
#import "ARUtils.h"
#import "Common.h"

typedef enum
{
    INFORMATIONS_VIEW,
    USERS_VIDEOS_VIEW,
    STAY_TUNED_VIEW,
    WTB_VIEW
} eGuestSpaceVisibleView;

@interface MenuGuestSpace : ARNavigationController <ARWebViewControllerDelegate, UIScrollViewDelegate, ARStatusBarDelegate, UIAlertViewDelegate> {
    ARStatusBarViewController *statusBar;
    ARNavigationBarViewController *navBar;
    
    IBOutlet UIView *m_currentView;
    
    IBOutlet UIScrollView *scrollView;
	IBOutlet UIButton *previous;
	IBOutlet UIButton *next;
    NSUInteger pagesCount;
    
    IBOutlet UIView *guestView1;
    IBOutlet UIView *guestView2;
    IBOutlet UIView *guestView3;
    IBOutlet UIView *guestView4;
    IBOutlet UIView *guestView5;
    IBOutlet UIView *guestView6;
    
    IBOutlet ARButton *informationsButton;
    IBOutlet ARButton *usersVideosButton;
    IBOutlet ARButton *stayTunedButton;
    IBOutlet ARButton *tryItButton;
    
    IBOutlet UIView *m_stayTunedView;
    ARWebViewController *usersVideosViewController;
    ARWebViewController *tryItViewController;
    
    eGuestSpaceVisibleView m_visibleView;
}

@property (nonatomic, retain) UIScrollView *scrollView;
@property (nonatomic, retain) UIButton *previous;
@property (nonatomic, retain) UIButton *next;
@property (nonatomic, retain) UIView *m_stayTunedView;

- (id)initWithController:(MenuController *)menuController;
- (IBAction)buttonUp:(id)button;
- (IBAction)infoButtonlicked;
- (IBAction)usersVideosButtonClicked;
- (IBAction)stayTunedButtonClicked;
- (IBAction)goToWebsiteButtonClicked;
- (IBAction)signUpButtonClicked;
- (IBAction)likeButtonClicked;
- (IBAction)followButtonClicked;
- (IBAction)tryItButtonClicked;

@end
