//
//  MenuGuestSpace.m
//  FreeFlight
//
//  Created by Nicolas on 11/10/11.
//  Copyright 2011 Parrot. All rights reserved.
//

#import "MenuGuestSpace.h"
#import "ARUtils.h"
#import "MenuPreferences.h"

@implementation MenuGuestSpace

@synthesize scrollView;
@synthesize previous;
@synthesize next;
@synthesize m_stayTunedView;

#define USERS_VIDEOS_URL    @"http://%@.youtube.com/playlist?list=PL4499009D796F2BEA"
#define DEMO_STORE_URL      @"http://ardrone2.parrot.com/promo/getademo/"
#define WHERE_TO_BUY_URL    @"http://ardrone.parrot.com/parrot-ar-drone/usa/where-to-buy"
#define ARDRONE_WEBSITE_URL @"http://ardrone.parrot.com/parrot-ar-drone/usa/"
#define NEWSLETTER_URL      @"http://ardrone2.parrot.com/promo/email/"
#define FACEBOOK_URL        @"http://www.facebook.com/parrot"
#define TWITTER_URL         @"http://www.twitter.com/ardrone"

typedef enum 
{
    WHERE_TO_BUY_TAG    = 100,
    WEBSITE_TAG         = 101,
    NEWSLETTER_TAG      = 102, 
    FACEBOOK_TAG        = 103, 
    TWITTER_TAG         = 104
} eAlertViewTag;

- (id)initWithController:(MenuController *)menuController
{
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
        self = [super initWithNibName:@"MenuGuestSpace-iPad" bundle:nil];
    else
        self = [super initWithNibName:@"MenuGuestSpace" bundle:nil];
    
    if (self) 
        controller = menuController;
    
    return self;
}

- (void)dealloc
{
    [statusBar release];
    [navBar release];
    [scrollView release];
    [previous release];
    [next release];
    [m_stayTunedView release];
    [usersVideosViewController setDelegate:nil];
    [tryItViewController setDelegate:nil];
    [usersVideosViewController release];
    [tryItViewController release];
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
    [navBar setViewTitle:@"AR.DRONE 2.0"];
    [navBar.leftButton addTarget:self action:@selector(backToMenuHome) forControlEvents:UIControlEventTouchUpInside];
        
    [informationsButton setBackgroundColorHighlighted:ORANGE(1.f)];
    [informationsButton setSelected:YES];
    [usersVideosButton setBackgroundColorHighlighted:ORANGE(1.f)];
    [stayTunedButton setBackgroundColorHighlighted:ORANGE(1.f)];
    [tryItButton setBackgroundColorHighlighted:ORANGE(1.f)];
    
  	CGRect frame = scrollView.frame;
  	scrollView.contentSize = CGSizeZero;
	scrollView.pagingEnabled = YES;
	scrollView.showsHorizontalScrollIndicator = NO;
	scrollView.showsVerticalScrollIndicator = NO;
	scrollView.delegate = self;
    
    pagesCount = 0;
    
    NSMutableArray *guestViews = [NSMutableArray array];
    [guestViews addObject:guestView1];
    [guestViews addObject:guestView2];
    [guestViews addObject:guestView3];
    [guestViews addObject:guestView4];
    [guestViews addObject:guestView5];
    [guestViews addObject:guestView6];
    
    for (UIView *guestView in guestViews)
    {
        scrollView.contentSize = CGSizeMake(scrollView.contentSize.width + scrollView.frame.size.width, scrollView.frame.size.height);
        guestView.frame = frame;
        frame.origin.x += frame.size.width;
        [scrollView addSubview:guestView];
        pagesCount++;
    }
		
	[previous setHidden:YES];
    
    // Alloc users videos view controller
    usersVideosViewController = [[ARWebViewController alloc] init];
    [usersVideosViewController setDelegate:self];
    
    tryItViewController = [[ARWebViewController alloc] init];
    [tryItViewController setDelegate:self];
    
    m_visibleView = INFORMATIONS_VIEW;
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}

- (void)scrollViewDidScroll:(UIScrollView *)_scrollView
{
	int currentPage = (int) (scrollView.contentOffset.x + .5f * scrollView.frame.size.width) / scrollView.frame.size.width;
    
    if(currentPage == 0)
    {
        [previous setHidden:YES];
        [next setHidden:NO];
    }
    else if(currentPage == (pagesCount - 1))
    {
        [previous setHidden:NO];
        [next setHidden:YES];
    }
    else
    {
        [previous setHidden:NO];
        [next setHidden:NO];
    }
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

- (IBAction) buttonUp:(id)button
{
	int currentPage = (int) (scrollView.contentOffset.x + .5f * scrollView.frame.size.width) / scrollView.frame.size.width;
	if ( (currentPage > 0) && (button == previous) )
		[scrollView setContentOffset:CGPointMake((currentPage - 1) * scrollView.frame.size.width, 0) animated:YES];
	else if ( (currentPage < (pagesCount - 1)) && (button == next) )
		[scrollView setContentOffset:CGPointMake((currentPage + 1) * scrollView.frame.size.width, 0) animated:YES];
}

- (void)statusBarPreferencesClicked:(ARStatusBarViewController *)bar
{
    MenuPreferences *menuPreferences = [[MenuPreferences alloc] initWithController:controller];
    [self.navigationController pushViewController:menuPreferences animated:NO];
    [menuPreferences release];
}

- (void)removeVisibleView
{
    switch (m_visibleView) 
    {
        case USERS_VIDEOS_VIEW:
            [usersVideosViewController.view removeFromSuperview];
            [navBar displayWebPagesControls:NO];
            break;
        case STAY_TUNED_VIEW:
            [m_stayTunedView removeFromSuperview];
            break;
        case INFORMATIONS_VIEW:
            [scrollView removeFromSuperview];
            [previous removeFromSuperview];
            [next removeFromSuperview];
        case WTB_VIEW:
            [tryItViewController.view removeFromSuperview];
            [navBar displayWebPagesControls:NO];
            break;
        default:
            break;
    }
}

- (void)infoButtonlicked
{
    if (!informationsButton.isSelected)
    {
        [self removeVisibleView];
        
        [m_currentView addSubview:scrollView];
        [m_currentView addSubview:previous];
        [m_currentView addSubview:next];
        
        m_visibleView = INFORMATIONS_VIEW;
        
        [usersVideosButton setSelected:NO];
        [stayTunedButton setSelected:NO];
        [tryItButton setSelected:NO];
        [informationsButton setSelected:YES];
    }
}

- (void)usersVideosButtonClicked
{
    if (!usersVideosButton.isSelected)
    {
        [self removeVisibleView];
        
        CGFloat marginHeight = (statusBar.view.frame.size.height + navBar.view.frame.size.height);
        CGRect frame = CGRectMake(0.f, marginHeight, self.view.frame.size.width, self.view.frame.size.height - marginHeight - usersVideosButton.frame.size.height);
        [usersVideosViewController setViewFrame:frame];
        [m_currentView addSubview:usersVideosViewController.view];
        [usersVideosViewController hideToolbar];
        [usersVideosViewController disableBouncing];
        NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:USERS_VIDEOS_URL, (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad ? @"www" : @"m")]];
        [usersVideosViewController loadRequest:[NSURLRequest requestWithURL:url]];
        
        m_visibleView = USERS_VIDEOS_VIEW;
        
        [informationsButton setSelected:NO];
        [stayTunedButton setSelected:NO];
        [tryItButton setSelected:NO];
        [usersVideosButton setSelected:YES];
        
        [navBar displayWebPagesControls:YES];
        [navBar.backPageButton setEnabled:NO];
        [navBar.nextPageButton setEnabled:NO];
        [navBar.backPageButton addTarget:self action:@selector(backPageButtonClicked) forControlEvents:UIControlEventTouchUpInside];
        [navBar.nextPageButton addTarget:self action:@selector(nextPageButtonClicked) forControlEvents:UIControlEventTouchUpInside];
    }
}

- (void)backPageButtonClicked
{
    switch (m_visibleView) 
    {
        case USERS_VIDEOS_VIEW:
            [usersVideosViewController.webView goBack];
            break;
        case WTB_VIEW:
            [tryItViewController.webView goBack];
            break;
        default:
            break;
    }
}

- (void)nextPageButtonClicked
{
    switch (m_visibleView) 
    {
        case USERS_VIDEOS_VIEW:
            [usersVideosViewController.webView goForward];
            break;
        case WTB_VIEW:
            [tryItViewController.webView goForward];
            break;
        default:
            break;
    }
}

- (void)webViewControllerDidFinishLoad:(ARWebViewController *)webViewController
{
    [navBar.backPageButton setEnabled:[webViewController.webView canGoBack]];
    [navBar.nextPageButton setEnabled:[webViewController.webView canGoForward]];
}

- (void)stayTunedButtonClicked
{    
    if (!stayTunedButton.isSelected)
    {
        [self removeVisibleView];
        [m_currentView addSubview:m_stayTunedView];
        m_visibleView = STAY_TUNED_VIEW;
        
        [informationsButton setSelected:NO];
        [usersVideosButton setSelected:NO];
        [tryItButton setSelected:NO];
        [stayTunedButton setSelected:YES];
    }
}

- (void)tryItButtonClicked
{
    if (!tryItButton.isSelected)
    {
        [self removeVisibleView];
        
        CGFloat marginHeight = (statusBar.view.frame.size.height + navBar.view.frame.size.height);
        CGRect frame = CGRectMake(0.f, marginHeight, self.view.frame.size.width, self.view.frame.size.height - marginHeight - tryItButton.frame.size.height);
        [tryItViewController setViewFrame:frame];
        [m_currentView addSubview:tryItViewController.view];
        [tryItViewController hideToolbar];
        [tryItViewController disableBouncing];
        [tryItViewController loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:DEMO_STORE_URL]]];
        
        m_visibleView = WTB_VIEW;
    
        [informationsButton setSelected:NO];
        [usersVideosButton setSelected:NO];
        [stayTunedButton setSelected:NO];
        [tryItButton setSelected:YES];
        
        [navBar displayWebPagesControls:YES];
        [navBar.backPageButton setEnabled:NO];
        [navBar.nextPageButton setEnabled:NO];
        [navBar.backPageButton addTarget:self action:@selector(backPageButtonClicked) forControlEvents:UIControlEventTouchUpInside];
        [navBar.nextPageButton addTarget:self action:@selector(nextPageButtonClicked) forControlEvents:UIControlEventTouchUpInside];
    }
}

- (void)goToWebsiteButtonClicked
{
    ARWebViewController *webViewController = [[ARWebViewController alloc] init];
    [self presentModalViewController:webViewController animated:YES];
    [webViewController loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:ARDRONE_WEBSITE_URL]]];
    [webViewController release];
}

- (void)signUpButtonClicked
{
    ARWebViewController *webViewController = [[ARWebViewController alloc] init];
    [self presentModalViewController:webViewController animated:YES];
    [webViewController loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:NEWSLETTER_URL]]];
    [webViewController release];
}

- (void)likeButtonClicked
{
    ARWebViewController *webViewController = [[ARWebViewController alloc] init];
    [self presentModalViewController:webViewController animated:YES];
    [webViewController loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:FACEBOOK_URL]]];
    [webViewController release];
}

- (void)followButtonClicked
{
    ARWebViewController *webViewController = [[ARWebViewController alloc] init];
    [self presentModalViewController:webViewController animated:YES];
    [webViewController loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:TWITTER_URL]]];
    [webViewController release];
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    // Ok button
    if (buttonIndex == 0)
    {
        // Leave app
        switch (alertView.tag) 
        {
            case WHERE_TO_BUY_TAG:
                [[UIApplication sharedApplication] openURL:[NSURL URLWithString:WHERE_TO_BUY_URL]];
                break;
            case WEBSITE_TAG:
                [[UIApplication sharedApplication] openURL:[NSURL URLWithString:ARDRONE_WEBSITE_URL]];
                break;
            case NEWSLETTER_TAG:
                [[UIApplication sharedApplication] openURL:[NSURL URLWithString:NEWSLETTER_URL]];
                break;
            case FACEBOOK_TAG:
                [[UIApplication sharedApplication] openURL:[NSURL URLWithString:FACEBOOK_URL]];
                break;
            case TWITTER_TAG:
                [[UIApplication sharedApplication] openURL:[NSURL URLWithString:TWITTER_URL]];
                break;
            default:
                break;
        }
    }
}

@end
