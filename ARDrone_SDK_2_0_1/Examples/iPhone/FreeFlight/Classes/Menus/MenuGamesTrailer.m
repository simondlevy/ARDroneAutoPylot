//
//  MenuGamesTrailer.m
//  FreeFlight
//
//  Created by Nicolas Payot on 26/01/12.
//  Copyright (c) 2012 PARROT. All rights reserved.
//

#import "MenuGamesTrailer.h"
#import "ARUtils.h"

@implementation MenuGamesTrailer

@synthesize m_navBar;
@synthesize m_webView;
@synthesize m_trailerName;
@synthesize m_trailerID;
@synthesize spinner;
@synthesize loadingLabel;

#define MARGIN  15.f
#define LABEL_W (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad ? 800.f : 400.f)
#define LABEL_H 100.f


- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    NSMutableString *nibName = [NSMutableString stringWithString:nibNameOrNil];
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
        [nibName appendString:@"-iPad"];
    
    self = [super initWithNibName:nibName bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
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
    
    m_navBar = [[ARNavigationBarViewController alloc] initWithNibName:NAVIGATION_BAR bundle:nil];
    [self.view addSubview:m_navBar.view];
    [m_navBar moveOnTop];
    if (m_trailerName != nil)
        [m_navBar setViewTitle:[[NSString stringWithFormat:@"%@ %@", m_trailerName, LOCALIZED_STRING(@"TRAILER")] uppercaseString]];
    else
        [m_navBar setViewTitle:LOCALIZED_STRING(@"GAME TRAILER")];
    [m_navBar.leftButton addTarget:self action:@selector(backToMenuGames) forControlEvents:UIControlEventTouchUpInside];
    
    errorDidOccur = NO;
    
    [loadingLabel setText:LOCALIZED_STRING(@"Loading...")];
    [self centersStatusInfoLabel];
    
    CGRect frame = m_webView.frame;
    frame.size.height -= m_navBar.view.frame.size.height;
    frame.origin.y += m_navBar.view.frame.size.height;
    [m_webView setFrame:frame];
    [m_webView setDelegate:self];
    
    trailerIsLoaded = NO;
    
    // Disable scrolling
    for (UIView *view in m_webView.subviews)
        if ([[view class] isSubclassOfClass:[UIScrollView class]])
            [(UIScrollView *)view setScrollEnabled:NO];
        
    // Load youtube trailer into webView
    NSString *embedHTML =   @"<iframe class=\"youtube-player\" \
                            type=\"text/html\" \
                            width=\"%f\" height=\"%f\" \
                            src=\"http://www.youtube.com/embed/%@\" frameborder=\"0\">\
                            </iframe>";
    
    if (m_trailerID != nil)
    {
        NSString *html = [NSString stringWithFormat:embedHTML, m_webView.frame.size.width - MARGIN, m_webView.frame.size.height - MARGIN, m_trailerID];
        [m_webView loadHTMLString:html baseURL:nil];
    }
    else
        [ARAlertView displayAlertView:LOCALIZED_STRING(@"Cannot Load Trailer") 
                               format:LOCALIZED_STRING(@"Trailer was not found.")];
}

- (void)dealloc
{
    [m_trailerName release];
    [m_trailerID release];
    [m_navBar release];
    [m_webView release];
    [spinner release];
    [loadingLabel release];
    
    [super dealloc];
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

- (void)backToMenuGames
{
    [self.navigationController popViewControllerAnimated:YES];
}

- (void)centersStatusInfoLabel
{
    [loadingLabel sizeToFit];
    CGRect frame;
    
    if (!spinner.hidden)
    {
        frame = spinner.frame;
        frame.origin.x = floorf((self.view.frame.size.width - (frame.size.width + 8.f + loadingLabel.frame.size.width)) / 2.f);
        frame.origin.y = floorf((self.view.frame.size.height - frame.size.height) / 2.f);
        [spinner setFrame:frame];
    }
    
    frame = loadingLabel.frame; 
    
    if (!spinner.hidden)
        frame.origin.x = floorf(spinner.frame.origin.x + spinner.frame.size.width + 8.f);
    else 
        frame.origin.x = floorf((self.view.frame.size.width - frame.size.width) / 2.f);
    
    frame.origin.y = floorf((self.view.frame.size.height - frame.size.height) / 2.f);
    [loadingLabel setFrame:frame];
}

#pragma mark - UIWebView delegate

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType
{
    if (!trailerIsLoaded)
        return YES;
    else
        return NO;
}

- (void)webViewDidFinishLoad:(UIWebView *)webView
{
    if (!errorDidOccur)
    {
        [spinner stopAnimating];
        [loadingLabel setHidden:YES];
        trailerIsLoaded = YES;
        [m_webView setHidden:NO];
    }
}

- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error
{    
    if (error.code == NSURLErrorCancelled)
        [m_webView setHidden:NO];
    else 
    {
        errorDidOccur = YES;
        [spinner stopAnimating];                     
        [loadingLabel setText:[NSString stringWithFormat:LOCALIZED_STRING(@"Error: %@"), [error localizedDescription]]];
        [self centersStatusInfoLabel];
    }
}

@end
