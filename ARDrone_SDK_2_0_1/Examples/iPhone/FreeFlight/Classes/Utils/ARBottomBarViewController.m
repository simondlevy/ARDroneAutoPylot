//
//  ARBottomBarViewController.m
//  FreeFlight
//
//  Created by Nicolas Payot on 26/10/11.
//  Copyright 2011 PARROT. All rights reserved.
//

#import "ARBottomBarViewController.h"
#import "Common.h"

@implementation ARBottomBarViewController

@synthesize delegate = _delegate;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    NSMutableString *nibName = [NSMutableString stringWithString:nibNameOrNil];
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) 
        [nibName appendString:@"-iPad"];
    
    self = [super initWithNibName:nibName bundle:nibBundleOrNil];
    if (self) 
    {
        // Custom initialization
    }
    return self;
}

- (void)dealloc
{
    [loadingView removeFromSuperview];
    [sortAll release];
    [sortPhotos release];
    [sortVideos release];
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
    
    CGRect frame = self.view.frame;
    frame.origin.y = SCREEN_H - frame.size.height;
    [self.view setFrame:frame];
    
    [sortLabel setText:LOCALIZED_STRING(@"SORT:")];
//    [sortAll setTitle:LOCALIZED_STRING(@"ALL") forState:UIControlStateNormal];
//    [sortPhotos setTitle:LOCALIZED_STRING(@"PHOTOS") forState:UIControlStateNormal];
//    [sortVideos setTitle:LOCALIZED_STRING(@"VIDEOS") forState:UIControlStateNormal];
    [loadingLabel setText:[LOCALIZED_STRING(@"Loading...") uppercaseString]];
    
    [sortAll setSelected:YES];
    [sortPhotos.imageView setAlpha:0.5f];
    [sortVideos.imageView setAlpha:0.5f];
    
    [loadingView setHidden:YES];
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
    return UIInterfaceOrientationIsLandscape(UIInterfaceOrientationPortrait);
}

- (void)showLoadingView:(NSNumber *)show
{
    [loadingView setHidden:![show boolValue]];
}

- (void)clearAllButton
{    
    [sortAll setSelected:NO];
    [sortPhotos setSelected:NO];
    [sortVideos setSelected:NO];
    
    [sortAll.imageView setAlpha:0.5f];
    [sortPhotos.imageView setAlpha:0.5f];
    [sortVideos.imageView setAlpha:0.5f];
}

- (void)displayAll
{
    [self clearAllButton];
    [sortAll setSelected:YES];
    [sortAll.imageView setAlpha:1.f];
    [self.delegate bottomBar:self sortMediaWithType:ALAssetTypeUnknown];
}

- (void)displayPhotos
{
    [self clearAllButton];
    [sortPhotos setSelected:YES];
    [sortPhotos.imageView setAlpha:1.f];
    [self.delegate bottomBar:self sortMediaWithType:ALAssetTypePhoto];
}

- (void)displayVideos
{
    [self clearAllButton];
    [sortVideos setSelected:YES];
    [sortVideos.imageView setAlpha:1.f];
    [self.delegate bottomBar:self sortMediaWithType:ALAssetTypeVideo];
}

@end
