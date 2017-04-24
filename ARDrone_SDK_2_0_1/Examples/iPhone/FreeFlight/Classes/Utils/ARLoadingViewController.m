//
//  ARLoadingViewController.m
//  FreeFlight
//
//  Created by Nicolas Payot on 16/12/11.
//  Copyright (c) 2011 PARROT. All rights reserved.
//

#import "ARLoadingViewController.h"

/** #################### ARActivityIndicatorView implementation #################### **/

@implementation ARActivityIndicatorView

#define kARActivityIndicatorViewSize    35.f
#define kImagesCount                    17

- (id)init
{
    self = [super initWithFrame:CGRectMake(0.f, 0.f, kARActivityIndicatorViewSize, kARActivityIndicatorViewSize)];
    if (self)
    {
        NSMutableArray *imagesArray = [NSMutableArray arrayWithCapacity:kImagesCount];
        for (int i = 1; i <= kImagesCount; ++i)
        {
            UIImage *image = [UIImage imageNamed:[NSString stringWithFormat:@"ff2.0_spinner_%d.png", i]];
            [imagesArray addObject:image];
        }
        [self setAnimationImages:imagesArray];
        [self setAnimationDuration:1.5f];
        [self startAnimating];
    }
    return self;
}

@end

/** #################### ARProgressView implementation #################### **/

@implementation ARProgressView

#define kFillOffsetX        3.f
#define kFillOffsetY        3.f
#define kProgressBarHeight  20.f

- (id)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self)
    {
        CGRect frame = self.frame;
        frame.size.height = kProgressBarHeight;
        [self setFrame:frame];
        NSLog(@"frame: %@", NSStringFromCGRect(self.frame));
    }
    return self;
}

- (void)drawRect:(CGRect)rect 
{        
    CGSize backgroundStretchPoints = CGSizeMake(2.f, 0.f);
    
    // Initialize the stretchable images
    UIImage *background = [[UIImage imageNamed:@"ff2.0_progress_bar_bg.png"] stretchableImageWithLeftCapWidth:backgroundStretchPoints.width 
                                                                                                 topCapHeight:backgroundStretchPoints.height];
    UIImage *fill = [UIImage imageNamed:@"ff2.0_progress_bar_fill.png"];
    
    // Draw the background in the current rect
    [background drawInRect:rect];
    
    // Compute the max width in pixels for the fill.  Max width being how wide the fill should be at 100% progress.
    NSInteger maxWidth = rect.size.width - 2 * kFillOffsetX;
    
    // Compute the width for the current progress value, 0.0 - 1.0 corresponding to 0% and 100% respectively.
    NSInteger curWidth = ceilf([self progress] * maxWidth);
    
    // Create the rectangle for our fill image accounting for the position offsets
    CGRect fillRect = CGRectMake(rect.origin.x + kFillOffsetX, rect.origin.y + kFillOffsetY, curWidth, rect.size.height - 2 * kFillOffsetY);
    
    // Draw the fill
    [fill drawInRect:fillRect];
}

@end

/** #################### ARLoadingViewController implementation #################### **/

@implementation ARLoadingViewController

@synthesize delegate = _delegate;

- (id)init
{
    NSMutableString *nibName = [NSMutableString stringWithString:@"ARLoadingView"];
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
        [nibName appendString:@"-iPad"];
    
    self = [super initWithNibName:nibName bundle:nil];
    if (self)
    {
        self.delegate = nil;
    }
    return self;
}

- (id)initWithDelegate:(id<ARLoadingViewDelegate>)aDelegate
{
    NSMutableString *nibName = [NSMutableString stringWithString:@"ARLoadingView"];
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
        [nibName appendString:@"-iPad"];
    
    self = [super initWithNibName:nibName bundle:nil];
    if (self)
    {
        self.delegate = aDelegate;
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
        
    spinner = [[ARActivityIndicatorView alloc] init];
    CGRect frame = spinner.frame;
    frame.origin.x = floorf((indicatorView.frame.size.width - frame.size.width) / 2.f);
    frame.origin.y = floorf((indicatorView.frame.size.height - frame.size.height) / 2.f);
    [spinner setFrame:frame];
    [indicatorView addSubview:spinner];
    
    [loadingLabel setText:[LOCALIZED_STRING(@"Loading...") uppercaseString]];
    [cancelButton setTitle:LOCALIZED_STRING(@"CANCEL") forState:UIControlStateNormal];
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}

- (void)dealloc
{
    [spinner release];
    [progressBar release];
    [loadingLabel release];
    [cancelButton release];
    [topView release];
    [indicatorView release];
    [super dealloc];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // Return YES for supported orientations
    return UIInterfaceOrientationIsLandscape(interfaceOrientation);
}

- (void)showView
{
    [self.view setHidden:NO];
}

- (void)hideView
{
    [self.view setHidden:YES];
}

- (void)addImageWithName:(NSString *)imageName
{
    UIImage *image = [UIImage imageNamed:imageName];
    UIImageView *imageView = [[UIImageView alloc] initWithImage:image];

    CGRect frame = imageView.frame;
    frame.origin.x = (topView.frame.size.width - frame.size.width) / 2.f;
    frame.origin.y = (topView.frame.size.height - frame.size.height) / 2.f;
    [imageView setFrame:frame];
    
    [topView addSubview:imageView];
    [imageView release];
}

- (void)displaySpinner
{
    [progressBar setHidden:YES];
    [spinner setHidden:NO];
}

- (void)displayProgressBar
{
    [spinner setHidden:YES];
    [progressBar setHidden:NO];
}

- (void)setProgressBarValue:(CGFloat)val
{
    // val must be between 0 and 1
    if (val < 0.f || val > 1.f) return;
    [progressBar setProgress:val];
}

- (void)setLoadingText:(NSString *)_loadingText
{
    [loadingLabel setText:_loadingText];
}

- (void)displayCancelButton:(BOOL)display
{
    [cancelButton setHidden:!display];
}

- (void)setCancelButtonTitle:(NSString *)title
{
    [cancelButton setTitle:title forState:UIControlStateNormal];
}

#pragma mark - 
#pragma mark - IBActions

- (void)cancelButtonClicked:(id)sender
{
    [self hideView];
    if ([self.delegate respondsToSelector:@selector(loadingViewControllerCancelButtonClicked:)])
        [self.delegate loadingViewControllerCancelButtonClicked:self];
}

@end
