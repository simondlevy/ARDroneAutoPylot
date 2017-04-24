//
//  ARNavigationBarViewController.m
//  FreeFlight
//
//  Created by Nicolas Payot on 11/10/11.
//  Copyright 2011 PARROT. All rights reserved.
//

#import "ARNavigationBarViewController.h"

const CGFloat ORIGIN_Y      = 18.f;
const CGFloat ORIGIN_Y_IPAD = 26.f;

@implementation ARNavigationBarViewController

@synthesize leftButton;
@synthesize rightButton;
@synthesize rightButtonType;
@synthesize backPageButton;
@synthesize nextPageButton;

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

- (void)dealloc
{
    [leftButton release];
    [titleLabel release];
    [searchButton release];
    [plusButton release];
    [minusButton release];
    [rightButton release];
    [shareButton release];
    [backPageButton release];
    [nextPageButton release];
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
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) 
        frame.origin.y = ORIGIN_Y_IPAD;
    else 
        frame.origin.y = ORIGIN_Y;
    [self.view setFrame:frame];
        
    // Back button displayed by default
    [self displayBackButton];
    
    [shareButton setTitle:LOCALIZED_STRING(@"SHARE") forState:UIControlStateNormal];
    [shareButton setBackgroundColorHighlighted:[UIColor colorWithRed:50.f/255.f green:50.f/255.f blue:50.f/255.f alpha:1.f]];
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

- (void)setViewTitle:(NSString *)title
{
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
        [titleLabel setFont:[UIFont fontWithName:HELVETICA size:40.f]];
    else
        [titleLabel setFont:[UIFont fontWithName:HELVETICA size:22.f]];
    [titleLabel setText:title];
    [titleLabel sizeToFit];
    
    // Center title
    CGRect frame = titleLabel.frame;
    frame.origin.x = (self.view.frame.size.width - frame.size.width) / 2.f;
    frame.origin.y = (self.view.frame.size.height - frame.size.height) / 2.f;
    [titleLabel setFrame:frame];
}

- (void)displayBackButton
{
    [leftButton setImage:[UIImage imageNamed:@"ff2.0_arrow_back.png"] forState:UIControlStateNormal];
}

- (void)displayHomeButton
{
    [leftButton setImage:[UIImage imageNamed:@"ff2.0_home.png"] forState:UIControlStateNormal];
}

- (void)hideAllRightItems
{
    [searchButton setHidden:YES];
    [plusButton setHidden:YES];
    [minusButton setHidden:YES];
}

- (void)displayRightButton:(ARNavBarRightButton)button
{
    CGRect frame = titleLabel.frame;
    frame.origin.x = (self.view.frame.size.width - frame.size.width) / 2;
    [titleLabel setFrame:frame];
    [self hideAllRightItems];
    
    switch (button) 
    {
        case AR_SEARCH_BUTTON:
            self.rightButton = searchButton;
            rightButtonType = AR_SEARCH_BUTTON;
            break;
        case AR_PLUS_BUTTON:
            self.rightButton = plusButton;
            rightButtonType = AR_PLUS_BUTTON;
            break;
        case AR_MINUS_BUTTON:
            self.rightButton = minusButton;
            rightButtonType = AR_MINUS_BUTTON;
            break;
        case AR_SHARE_BUTTON:
            self.rightButton = shareButton;
            rightButtonType = AR_SHARE_BUTTON;
            break;
        default:
            break;
    }
    
    frame = rightButton.frame;
    frame.origin.x = self.view.frame.size.width - frame.size.width;
    [rightButton setFrame:frame];
    [rightButton setHidden:NO];
}

- (void)moveOnTop
{
    CGRect frame = self.view.frame;
    frame.origin.y = 0.f;
    [self.view setFrame:frame];
}

- (void)setTransparentStyle:(BOOL)transparent
{
    UIColor *color = [self.view backgroundColor];
    const CGFloat *rgba = CGColorGetComponents(color.CGColor);
    [self.view setBackgroundColor:[UIColor colorWithRed:rgba[0] green:rgba[1] blue:rgba[2] alpha:(transparent ? 0.75f : 1.f)]];
}

- (void)alignViewTitleRight
{
    CGRect frame = titleLabel.frame;
    frame.origin.x = self.view.frame.size.width - frame.size.width - floorf(CONVERT_WIDTH_SIZE(10.f));
    [titleLabel setFrame:frame];
}

- (void)alignViewTitleLeft
{
    CGRect frame = titleLabel.frame;
    frame.origin.x = leftButton.frame.size.width + floorf(CONVERT_WIDTH_SIZE(10.f));
    [titleLabel setFrame:frame];
}

- (void)displayWebPagesControls:(BOOL)display
{
    if (display)
    {
        CGRect frame = nextPageButton.frame;
        frame.origin.x = self.view.frame.size.width - frame.size.width;
        [nextPageButton setFrame:frame];
        
        frame = whiteSeparator.frame;
        frame.origin.x = nextPageButton.frame.origin.x - frame.size.width;
        [whiteSeparator setFrame:frame];
        
        frame = backPageButton.frame;
        frame.origin.x = whiteSeparator.frame.origin.x - frame.size.width;
        [backPageButton setFrame:frame];
        
        [backPageButton setHidden:NO];
        [whiteSeparator setHidden:NO];
        [nextPageButton setHidden:NO];
    }
    else 
    {
        [backPageButton setHidden:YES];
        [whiteSeparator setHidden:YES];
        [nextPageButton setHidden:YES];
    }
}

@end
