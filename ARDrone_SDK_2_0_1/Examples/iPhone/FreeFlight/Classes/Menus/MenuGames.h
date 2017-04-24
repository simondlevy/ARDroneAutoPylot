//
//  MenuGames.h
//  FreeFlight
//
//  Created by Nicolas Payot on 12/10/11.
//  Copyright 2011 PARROT. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "MenuController.h"
#import "ARStatusBarViewController.h"
#import "ARNavigationBarViewController.h"
#import "Common.h"
#import <MessageUI/MessageUI.h>
#import "ARUtils.h"

enum
{
    PURSUIT,
    FLYINGACE,
    RACE,
    HUNTER,
    RESCUE,
    GAMES_COUNT
};

enum 
{
    LOCAL_URL,
    APPSTORE_URL
};

@interface MenuGames : ARNavigationController <UITextViewDelegate, ARStatusBarDelegate, MFMailComposeViewControllerDelegate, UIWebViewDelegate> {
    ARStatusBarViewController *statusBar;
    ARNavigationBarViewController *navBar;
    
    IBOutlet UIView *contentView;
    IBOutlet UIScrollView *leftScrollView;
    IBOutlet UIButton *pursuitButton;
    IBOutlet UIButton *flyingAceButton;
    IBOutlet UIButton *raceButton;
    IBOutlet UIButton *hunterButton;
    IBOutlet UIButton *rescueButton;
    
    NSMutableArray *buttons;
    NSMutableArray *buttonsIcons;
    NSMutableArray *gamesTitles;
    NSMutableArray *gamesDescriptions;
    NSMutableArray *gamesURLs;
    NSMutableArray *gamesTrailers;
    
    IBOutlet UILabel *gameTitle;
    IBOutlet UIButton *download;
    IBOutlet UITextView *gameDescription;
    
    NSInteger selectedGame;
    
    IBOutlet ARButton *ardrone1Button;
    IBOutlet ARButton *ardrone2Button;
    
    IBOutlet UIButton *watchTrailerButton;
    IBOutlet UIButton *sendToFriendButton;
}

@property (nonatomic, retain) NSMutableArray *buttons;
@property (nonatomic, retain) NSMutableArray *buttonsIcons;
@property (nonatomic, retain) NSMutableArray *gamesTitles;
@property (nonatomic, retain) NSMutableArray *gamesDescriptions;
@property (nonatomic, retain) NSMutableArray *gamesURLs;
@property (nonatomic, retain) NSMutableArray *gamesTrailers;

- (id)initWithController:(MenuController *)menuController;
- (IBAction)displayGameInformation:(id)sender;
- (void)setDownloadOrPlayTitleWithTag:(NSInteger)tag;
- (IBAction)downloadOrPlayGame:(id)sender;
- (IBAction)watchTrailerButtonClicked;
- (IBAction)sendToFriendButtonClicked;
- (IBAction)ardrone2ButtonClicked:(id)sender;

@end
