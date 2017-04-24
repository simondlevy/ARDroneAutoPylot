//
//  MenuGames.m
//  FreeFlight
//
//  Created by Nicolas Payot on 12/10/11.
//  Copyright 2011 PARROT. All rights reserved.
//

#import "MenuGames.h"
#import "MenuPreferences.h"
#import "MenuGamesTrailer.h"

@implementation MenuGames

@synthesize buttons;
@synthesize buttonsIcons;
@synthesize gamesTitles;
@synthesize gamesDescriptions;
@synthesize gamesURLs;
@synthesize gamesTrailers;

#define BUTTON_HEIGHT   100.f

#define PURSUIT_URL     [NSDictionary dictionaryWithObject:@"http://itunes.apple.com/us/app/ar-pursuit/id398459463?mt=8" forKey:@"parrotarpursuit://"]
#define FLYING_ACE_URL  [NSDictionary dictionaryWithObject:@"http://itunes.apple.com/us/app/ar-flyingace/id422272353?mt=8" forKey:@"parrotarflyingace://"]
#define RACE_URL        [NSDictionary dictionaryWithObject:@"http://itunes.apple.com/us/app/ar-race/id422274413?mt=8" forKey:@"parrotarrace://"]
#define HUNTER_URL      [NSDictionary dictionaryWithObject:@"http://itunes.apple.com/us/app/ar.hunter/id453496125?mt=8" forKey:@"parrotarhunter://"]
#define RESCUE_URL      [NSDictionary dictionaryWithObject:@"http://itunes.apple.com/us/app/ar.rescue/id479509997?mt=8" forKey:@"parrotarrescue://"]

#define PURSUIT_TRAILER_ID      @"TcuPdraxiRc"
#define FLYING_ACE_TRAILER_ID   @"3RMUV_3qsWc"
#define RACE_TRAILER_ID         @"lEvmaU7chbM"
#define HUNTER_TRAILER_ID       @"UII0cDQqNn0"
#define RESCUE_TRAILER_ID       @"p53V11Ph9sc"

#define NEWSLETTER_URL          @"http://www.parrot-register.com/newsletter.asp?mail="

typedef enum 
{
    NEWSLETTER_TAG = 100,
    EMAIL_TAG = 101,
    ARDRONE2_TAB_TAG = 102
} eAlertViewTag;

- (id)initWithController:(MenuController *)menuController
{
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
        self = [super initWithNibName:@"MenuGames-iPad" bundle:nil];
    else
        self = [super initWithNibName:@"MenuGames" bundle:nil];
    
    if (self) 
    {
        controller = menuController;
    }
    return self;
}

- (void)dealloc
{
    [leftScrollView release];
    [pursuitButton release];
    [flyingAceButton release];
    [raceButton release];
    [hunterButton release];
    [rescueButton release];
    [buttons release];
    [buttonsIcons release];
    [gameTitle release];
    [download release];
    [gameDescription release];
    [gamesTitles release];
    [gamesDescriptions release];
    [gamesURLs release];
    [gamesTrailers release];
    [super dealloc];
}

- (void)didReceiveMemoryWarning
{
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc that aren't in use.
}

#pragma mark - View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
    
    self.navigationController.navigationBarHidden = YES;
    
    statusBar = [[ARStatusBarViewController alloc] initWithNibName:STATUS_BAR bundle:nil];
    [self.view addSubview:statusBar.view];
    [statusBar setDelegate:self];
    
    navBar = [[ARNavigationBarViewController alloc] initWithNibName:NAVIGATION_BAR bundle:nil];
    [self.view addSubview:navBar.view];
    [navBar displayHomeButton];
    [navBar setViewTitle:LOCALIZED_STRING(@"GAMES")];
    [navBar.leftButton addTarget:self action:@selector(backToMenuHome) forControlEvents:UIControlEventTouchUpInside];
        
    [pursuitButton setTag:PURSUIT];
    [flyingAceButton setTag:FLYINGACE];
    [raceButton setTag:RACE];
    [hunterButton setTag:HUNTER];
    [rescueButton setTag:RESCUE];
    
    self.buttons = [NSMutableArray arrayWithCapacity:GAMES_COUNT];
    [buttons addObject:pursuitButton];
    [buttons addObject:flyingAceButton];
    [buttons addObject:raceButton];
    [buttons addObject:hunterButton];
    [buttons addObject:rescueButton];
    
    self.buttonsIcons = [NSMutableArray arrayWithCapacity:GAMES_COUNT];
    [buttonsIcons addObject:@"ff2.0_pursuit_"];
    [buttonsIcons addObject:@"ff2.0_flying_ace_"];
    [buttonsIcons addObject:@"ff2.0_race_"];
    [buttonsIcons addObject:@"ff2.0_hunter_"];
    [buttonsIcons addObject:@"ff2.0_rescue_"];
    
    self.gamesTitles = [NSMutableArray arrayWithCapacity:GAMES_COUNT];
    [gamesTitles addObject:@"AR.Pursuit"];
    [gamesTitles addObject:@"AR.FlyingAce"];
    [gamesTitles addObject:@"AR.Race"];
    [gamesTitles addObject:@"AR.Hunter"];
    [gamesTitles addObject:@"AR.Rescue"];
    
    self.gamesDescriptions = [NSMutableArray arrayWithCapacity:GAMES_COUNT];
    [gamesDescriptions addObject:LOCALIZED_STRING(@"PURSUIT_DESCRIPTION")];
    [gamesDescriptions addObject:LOCALIZED_STRING(@"FLYINGACE_DESCRIPTION")];
    [gamesDescriptions addObject:LOCALIZED_STRING(@"RACE_DESCRIPTION")];
    [gamesDescriptions addObject:LOCALIZED_STRING(@"HUNTER_DESCRIPTION")];
    [gamesDescriptions addObject:LOCALIZED_STRING(@"RESCUE_DESCRIPTION")];
    
    self.gamesURLs = [NSMutableArray arrayWithCapacity:GAMES_COUNT];
    [gamesURLs addObject:PURSUIT_URL];
    [gamesURLs addObject:FLYING_ACE_URL];
    [gamesURLs addObject:RACE_URL];
    [gamesURLs addObject:HUNTER_URL];
    [gamesURLs addObject:RESCUE_URL];
    
    self.gamesTrailers = [NSMutableArray arrayWithCapacity:GAMES_COUNT];
    [gamesTrailers addObject:PURSUIT_TRAILER_ID];
    [gamesTrailers addObject:FLYING_ACE_TRAILER_ID];
    [gamesTrailers addObject:RACE_TRAILER_ID];
    [gamesTrailers addObject:HUNTER_TRAILER_ID];
    [gamesTrailers addObject:RESCUE_TRAILER_ID];
    
    // Only for iPhone / iPod...
    if (UI_USER_INTERFACE_IDIOM() != UIUserInterfaceIdiomPad)
    {
        [leftScrollView setFrame:CGRectMake(10.f, 10.f, 200.f, 214.f)];
        [leftScrollView setContentSize:CGSizeMake(leftScrollView.frame.size.width, (int)ceilf(buttons.count / 2.f) * BUTTON_HEIGHT)];
        [contentView addSubview:leftScrollView];
    }
    
    [gameTitle setText:[gamesTitles objectAtIndex:0]];
    
    [gameDescription setContentInset:UIEdgeInsetsMake(-10.f, 0.f, 0.f, 0.f)];
    [gameDescription setText:[gamesDescriptions objectAtIndex:0]];
    [gameDescription setDelegate:self];
    
    [self setDownloadOrPlayTitleWithTag:PURSUIT];
    
    [download setTitle:LOCALIZED_STRING(@"DOWNLOAD") forState:UIControlStateNormal];
    [watchTrailerButton setTitle:LOCALIZED_STRING(@"TRAILER") forState:UIControlStateNormal];
    [sendToFriendButton setTitle:LOCALIZED_STRING(@"SEND TO FRIEND") forState:UIControlStateNormal];
    
    [ardrone1Button setSelected:YES];
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // Return YES for supported orientations
    return UIInterfaceOrientationIsLandscape(interfaceOrientation);
}

- (IBAction)backToMenuHome
{
    [controller doAction:MENU_FF_ACTION_JUMP_TO_HOME];
}

- (IBAction)displayGameInformation:(id)sender
{   
    // Store tag of selected game
    selectedGame = ((UIButton *)sender).tag;
    
    for (UIButton *game in buttons)
    {
        UIImage *icon = [UIImage imageNamed:[NSString stringWithFormat:@"%@off.png", [buttonsIcons objectAtIndex:game.tag]]];
        [game setImage:icon forState:UIControlStateNormal];
    }

    UIImage *senderIcon = [UIImage imageNamed:[NSString stringWithFormat:@"%@on.png", [buttonsIcons objectAtIndex:selectedGame]]];
    [sender setImage:senderIcon forState:UIControlStateNormal];
        
    [self setDownloadOrPlayTitleWithTag:selectedGame];
    // Change title
    [gameTitle setText:[gamesTitles objectAtIndex:selectedGame]];
    // Change description
    [gameDescription setText:[gamesDescriptions objectAtIndex:selectedGame]];
    //[self setScrollingButtonsVisibility:gameDescription.contentOffset.y];
    
    [gameDescription setContentOffset:CGPointMake(0.f, 10.f)];
    [gameDescription setContentInset:UIEdgeInsetsMake(-10.f, 0.f, 0.f, 0.f)];
}

- (void)setDownloadOrPlayTitleWithTag:(NSInteger)tag
{
    NSString *localURL = [[[gamesURLs objectAtIndex:tag] allKeys] objectAtIndex:0];
    NSURL *gameURL = [NSURL URLWithString:localURL];
    
    NSString *downloadImageName = @"ff2.0_arrow_download.png";
    NSString *playImageName = @"ff2.0_arrow_play.png";
    
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
    {
        downloadImageName = @"ff2.0_arrow_download@2x.png";
        playImageName = @"ff2.0_arrow_play@2x.png";
    }
    
    if (![[UIApplication sharedApplication] canOpenURL:gameURL])
    {
        [download setTitle:LOCALIZED_STRING(@"DOWNLOAD") forState:UIControlStateNormal];
        [download setImage:[UIImage imageNamed:downloadImageName] forState:UIControlStateNormal];
        [download setTag:APPSTORE_URL];
    }
    else
    {
        [download setTitle:LOCALIZED_STRING(@"PLAY") forState:UIControlStateNormal];
        [download setImage:[UIImage imageNamed:playImageName] forState:UIControlStateNormal];
        [download setTag:LOCAL_URL];
    }
}

- (IBAction)downloadOrPlayGame:(id)sender
{
    NSString *gameURL = nil;
    switch (((UIButton *)sender).tag) 
    {
        case LOCAL_URL:
            gameURL = [[[gamesURLs objectAtIndex:selectedGame] allKeys] objectAtIndex:0];
            break;
        case APPSTORE_URL:
            gameURL = [[[gamesURLs objectAtIndex:selectedGame] allValues] objectAtIndex:0];
        default:
            break;
    }
        
    if (![[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:gameURL]])
    {
        UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:[gamesTitles objectAtIndex:selectedGame] 
                                                            message:LOCALIZED_STRING(@"Sorry, this game is not available.")
                                                           delegate:self cancelButtonTitle:@"OK"
                                                otherButtonTitles:nil, nil];
        [alertView show];
        [alertView release];
        return;
    }
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:gameURL]];
}

- (void)watchTrailerButtonClicked
{        
    MenuGamesTrailer *menuGamesTrailerViewController = [[MenuGamesTrailer alloc] initWithNibName:@"MenuGamesTrailer" bundle:nil];
    [menuGamesTrailerViewController setTrailerName:[gamesTitles objectAtIndex:selectedGame]];
    [menuGamesTrailerViewController setTrailerID:[gamesTrailers objectAtIndex:selectedGame]];
    [self.navigationController pushViewController:menuGamesTrailerViewController animated:YES];
    [menuGamesTrailerViewController release];
}

- (IBAction)sendToFriendButtonClicked
{                
    MFMailComposeViewController *mailViewController = [[MFMailComposeViewController alloc] init];
    [mailViewController setMailComposeDelegate:self];
    [mailViewController setSubject:[NSString stringWithFormat:LOCALIZED_STRING(@"Discover: \"%@\""), [gamesTitles objectAtIndex:selectedGame]]];
    
    NSMutableString *mailContent = [NSMutableString stringWithString:@"<html><body>"];
    [mailContent appendString:LOCALIZED_STRING(@"View this application in the Apple Store:")];
    NSString *gameLink = [[[gamesURLs objectAtIndex:selectedGame] allValues] objectAtIndex:0];
    [mailContent appendString:[NSString stringWithFormat:@"<p><b><a href=\"%@\">%@</a></b>", gameLink, [gamesTitles objectAtIndex:selectedGame]]];
    [mailContent appendString:LOCALIZED_STRING(@"<br>PARROT SA")];
    [mailContent appendString:LOCALIZED_STRING(@"<br>Category: Games</p>")];
    [mailContent appendString:@"</html></body>"];
    
    // Add game image as attachment
    NSData *imgData = UIImagePNGRepresentation([UIImage imageNamed:[NSString stringWithFormat:@"%@off.png", [buttonsIcons objectAtIndex:selectedGame]]]);
    [mailViewController addAttachmentData:imgData mimeType:@"image/png" fileName:[NSString stringWithFormat:@"%@.png", [gamesTitles objectAtIndex:selectedGame]]];
        
    [mailViewController setMessageBody:mailContent isHTML:YES];
    
    if (mailViewController)
        [self presentModalViewController:mailViewController animated:YES];
    
    [mailViewController release];
}

- (void)mailComposeController:(MFMailComposeViewController *)controller didFinishWithResult:(MFMailComposeResult)result error:(NSError *)error
{
    [self dismissModalViewControllerAnimated:YES];
}

- (void)statusBarPreferencesClicked:(ARStatusBarViewController *)bar
{
    MenuPreferences *menuPreferences = [[MenuPreferences alloc] initWithController:controller];
    [self.navigationController pushViewController:menuPreferences animated:NO];
    [menuPreferences release];
}

- (void)ardrone2ButtonClicked:(id)sender
{
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:LOCALIZED_STRING(@"Information")
                                                        message:LOCALIZED_STRING(@"Games are not available yet for AR.Drone 2.0.") 
                                                       delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil, nil];
    [alertView setTag:ARDRONE2_TAB_TAG];
    [alertView show];
    [alertView release];
}

@end
