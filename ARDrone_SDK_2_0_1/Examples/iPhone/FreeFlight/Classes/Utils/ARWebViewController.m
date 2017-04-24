//
//  ARWebViewController.m
//  FreeFlight
//
//  Created by Nicolas Payot on 03/02/12.
//  Copyright (c) 2012 PARROT. All rights reserved.
//

#import "ARWebViewController.h"

@implementation ARWebViewController

#define TOOLBAR_H   32.f
#define LABEL_W     (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad ? 800.f : 400.f)
#define LABEL_H     100.f

@synthesize toolbar;
@synthesize previous;
@synthesize next;
@synthesize webView;
@synthesize done;
@synthesize spinner;
@synthesize statusInfoLabel;
@synthesize delegate = _delegate;

- (id)init
{
    NSMutableString *nibName = [NSMutableString stringWithString:@"ARWebView"];
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
        [nibName appendString:@"-iPad"];
    
    self = [super initWithNibName:nibName bundle:nil];
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
    
    if (UI_USER_INTERFACE_IDIOM() != UIUserInterfaceIdiomPad)
    {
        CGRect frame = toolbar.frame;
        frame.size.height = TOOLBAR_H;
        [toolbar setFrame:frame];
        
        frame = webView.frame;
        frame.size.height = self.view.frame.size.height - TOOLBAR_H;
        frame.origin.y = TOOLBAR_H;
        [webView setFrame:frame];
    }
    
    [statusInfoLabel setText:LOCALIZED_STRING(@"Loading...")];
    [self centersStatusInfoLabel];
    
    [webView setScalesPageToFit:YES];
    [webView setDelegate:self];
}

- (void)dealloc
{
    [toolbar release];
    [previous release];
    [next release];
    [webView setDelegate:nil];
    [webView release];
    [done release];
    [spinner release];
    [statusInfoLabel release];
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

- (void)setViewFrame:(CGRect)frame
{
    [self.view setFrame:frame];
    [toolbar setFrame:CGRectMake(0.f, 0.f, frame.size.width, TOOLBAR_H)];
    [webView setFrame:CGRectMake(0.f, TOOLBAR_H, frame.size.width, frame.size.height - TOOLBAR_H)];
    
    [self centersStatusInfoLabel];
}

- (void)centersStatusInfoLabel
{
    [statusInfoLabel sizeToFit];
    CGRect frame;
    
    if (!spinner.hidden)
    {
        frame = spinner.frame;
        frame.origin.x = floorf((self.view.frame.size.width - (frame.size.width + 8.f + statusInfoLabel.frame.size.width)) / 2.f);
        frame.origin.y = floorf((self.view.frame.size.height - frame.size.height) / 2.f);
        [spinner setFrame:frame];
    }
    
    frame = statusInfoLabel.frame;
    
    if (!spinner.hidden)
        frame.origin.x = floorf(spinner.frame.origin.x + spinner.frame.size.width + 8.f);
    else 
        frame.origin.x = floorf((self.view.frame.size.width - frame.size.width) / 2.f);
    
    frame.origin.y = floorf((self.view.frame.size.height - frame.size.height) / 2.f);
    [statusInfoLabel setFrame:frame];
}

- (void)hideToolbar
{
    [self.toolbar setHidden:YES];
    [webView setFrame:CGRectMake(0.f, 0.f, self.view.frame.size.width, self.view.frame.size.height)];
}

- (void)doneButtonHidden:(BOOL)hidden
{
    NSMutableArray *items = [NSMutableArray arrayWithArray:toolbar.items];
    if (hidden) [items removeObject:done];
    else [items addObject:done];
    [toolbar setItems:items];
}

- (void)disableBouncing
{
    for (UIView *view in webView.subviews)
        if ([[view class] isSubclassOfClass:[UIScrollView class]])
            [(UIScrollView *)view setBounces:NO];
}

#pragma mark - UIWebView delegate

- (void)webViewDidFinishLoad:(UIWebView *)_webView
{   
    [spinner stopAnimating];
    [statusInfoLabel setHidden:YES];
    [webView setHidden:NO];
    [previous setEnabled:[webView canGoBack]];
    [next setEnabled:[webView canGoForward]];
    if ([self.delegate respondsToSelector:@selector(webViewControllerDidFinishLoad:)])
        [self.delegate webViewControllerDidFinishLoad:self];
}

- (void)webView:(UIWebView *)_webView didFailLoadWithError:(NSError *)error
{    
    // This error should be ignored
    if (error.code == NSURLErrorCancelled) 
        [webView setHidden:NO];
    else
    {
        [spinner stopAnimating];
        [statusInfoLabel setText:[NSString stringWithFormat:LOCALIZED_STRING(@"Error: %@"), [error localizedDescription]]];
        [self centersStatusInfoLabel];
    }
}

#pragma mark - IBActions

- (void)previousButtonClicked:(id)sender
{
    [webView goBack];
}

- (void)nextButtonClicked:(id)sender
{
    [webView goForward];
}

- (void)loadRequest:(NSURLRequest *)request
{
    [webView loadRequest:request];
}

- (void)loadHTMLString:(NSString *)htmlString
{
    [webView loadHTMLString:htmlString baseURL:nil];
}

- (void)doneButtonClicked:(id)sender
{
    [self dismissModalViewControllerAnimated:YES];
}

@end
