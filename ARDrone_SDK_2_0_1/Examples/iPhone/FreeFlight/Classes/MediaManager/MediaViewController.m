//
//  MediaViewController.m
//  FreeFlight
//
//  Created by Nicolas Payot on 04/08/11.
//  Copyright 2011 PARROT. All rights reserved.
//

#import "MediaViewController.h"
#import "MediaThumbsViewController.h"
#import <QuartzCore/QuartzCore.h>

#define PAGE_WIDTH      ((UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) ? 1022.f : 478.f)
#define PAGE_HEIGHT     CONVERT_HEIGHT_SIZE(320.f)
#define PAGE_OFFSET     2.f

@implementation ARMediaView

@synthesize delegate = _delegate;
@synthesize spinner;
@synthesize isMediaLoaded;
@synthesize videoPlayer;

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self)
    {
        isMediaLoaded = NO;
        spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
        CGFloat x = self.frame.size.width / 2 - spinner.frame.size.width / 2;
        CGFloat y = self.frame.size.height / 2 - spinner.frame.size.height / 2;
        [spinner setFrame:CGRectMake(x, y, spinner.frame.size.width, spinner.frame.size.height)];
        [self addSubview:spinner];
        [spinner setHidesWhenStopped:YES];
        [self setClipsToBounds:YES];
        videoPlayer = nil;
        
        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(touchRecognized:)];
        [tap setDelegate:self];
        [tap setCancelsTouchesInView:NO];
        [self addGestureRecognizer:tap];
        [tap release];
    }
    return self;
}

- (void)dealloc
{
    [spinner release];
    [videoPlayer release];
    [super dealloc];
}

- (void)touchRecognized:(id)sender
{
    [self.delegate mediaViewToucheRecognized:self];
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch
{    
    if (videoPlayer)
    {
        // Cancel tap gesture if user pressed on videoPlayer controls
        if ((touch.view == videoPlayer.playButtonBig) ||
            (touch.view == videoPlayer.controlsBar) || 
            ([videoPlayer.controlsBar.subviews indexOfObject:touch.view] != NSNotFound))
            return NO;
    }
    return YES;
}

@end

@implementation MediaContentOperation

- (id)initWithMediaAssetStringURL:(NSString *)_mediaAssetStringURL pageIndex:(NSInteger)_pageIndex delegate:(id)_delegate
{
    self = [super init];
    if (self)
    {
        mediaAssetStringURL = _mediaAssetStringURL;
        pageIndex = _pageIndex;
        delegate = _delegate;
    }
    return self;
}

- (void)dealloc
{
    [super dealloc];
}

- (void)main
{
    if (self.isCancelled) return;
    NSNumber *pageIndexNum = [NSNumber numberWithInteger:pageIndex];
    // Video
    if (mediaAssetStringURL == nil) return;
    
    ALAssetsLibrary *library = [[ALAssetsLibrary alloc] init];
    [library assetForURL:[NSURL URLWithString:mediaAssetStringURL] resultBlock:^(ALAsset *asset)
    {
        // Video
        if([asset valueForProperty:ALAssetPropertyType] == ALAssetTypeVideo)
        {
            if (self.isCancelled) return;
            
            NSArray *utis =  (NSArray*)[asset valueForProperty:ALAssetPropertyRepresentations];
            ALAssetRepresentation *representation = [asset representationForUTI:[utis objectAtIndex:0]];

            ARDronePlayerViewController *videoPlayer = [[ARDronePlayerViewController alloc] initWithURL:[representation url]];
            NSDictionary *dict = [NSDictionary dictionaryWithObject:videoPlayer forKey:pageIndexNum];
            [delegate performSelectorOnMainThread:@selector(displayFlightVideo:) withObject:dict waitUntilDone:NO];
            [videoPlayer release];
        }
        // Picture
        else if([asset valueForProperty:ALAssetPropertyType] == ALAssetTypePhoto)
        {
            NSArray *utis =  (NSArray*)[asset valueForProperty:ALAssetPropertyRepresentations];
            ALAssetRepresentation *representation = [asset representationForUTI:[utis objectAtIndex:0]];
            UIImage *image = [UIImage imageWithCGImage:[representation fullResolutionImage]];
            NSDictionary *dic = [NSDictionary dictionaryWithObject:image forKey:pageIndexNum];
            if (self.isCancelled) return;
            [delegate performSelectorOnMainThread:@selector(displayFlightPicture:) withObject:dic waitUntilDone:NO];   
        }
        /*else if([mediaPath.pathExtension isEqualToString:ARDRONE_MEDIAMANAGER_ENC_EXTENSION])
         {
         while(!([[NSFileManager defaultManager] fileExistsAtPath:movie]))
         {
         if(self.isCancelled)
         return;
         
         [NSThread sleepForTimeInterval:1.0];
         }
         
         mediaPath = movie;
         [self main];
         }
         */
        // NO ELSE
    } 
    failureBlock:^(NSError *error) 
    {
        NSLog(@"Failure : %@", error);
    }];
    [library release];
}

@end

/*@interface MediaViewController (private)
- (void)displaySendButton;
@end*/

@implementation MediaViewController

@synthesize index;
@synthesize flightMediaAssets;
@synthesize currentPlayer;
@synthesize parent;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    NSMutableString *nibName = [NSMutableString stringWithString:nibNameOrNil];
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
        [nibName appendString:@"-iPad"];
    
    self = [super initWithNibName:nibName bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization here
    }
    return self;
}

- (void)dealloc
{
    [queue release];
    [flightMediaAssets release];
    [scrollView release];
    [currentPlayer release];
    self.currentPlayer = nil;
    [loadingViewController release];
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
    navBar = [[ARNavigationBarViewController alloc] initWithNibName:NAVIGATION_BAR bundle:nil];
    [self.view addSubview:navBar.view];
    [navBar setViewTitle:[NSString stringWithFormat:LOCALIZED_STRING(@"%d of %d"), index + 1, [flightMediaAssets count]]];
    [navBar moveOnTop];
    [navBar setTransparentStyle:YES];
    [navBar.leftButton addTarget:self action:@selector(goBack) forControlEvents:UIControlEventTouchUpInside];
    [navBar displayRightButton:AR_SHARE_BUTTON];
    [navBar.rightButton addTarget:self action:@selector(sendMedia) forControlEvents:UIControlEventTouchUpInside];
    
    [scrollView setShowsHorizontalScrollIndicator:NO];
    [scrollView setDelegate:self];
    [scrollView setPagingEnabled:YES];
    [scrollView setContentSize:CGSizeMake((PAGE_WIDTH * [flightMediaAssets count]) + (PAGE_OFFSET * [flightMediaAssets count]), PAGE_HEIGHT)];
    [scrollView setDelaysContentTouches:NO];
    
    currentPage = index;
    currentPlayer = nil;
    currentMediaView = nil;
   
    loadingViewController = [[ARLoadingViewController alloc] init];
    [self.view addSubview:loadingViewController.view];
    
    queue = [NSOperationQueue new];
    
    [self setScrollViewMediaViewFramesAndContentOffset];
}

- (void)viewDidUnload
{
    [super viewDidUnload];
}

- (void)displayFlightMediaFrame:(ARMediaView *)frame
{
    [scrollView addSubview:frame];
}

- (void)setScrollViewMediaViewFramesAndContentOffset
{
    CGFloat x = PAGE_OFFSET / 2.f;    
    // Start with media frames
    for (NSInteger i = 0; i < [flightMediaAssets count]; ++i)
    {
        ARMediaView *mediaView = [[ARMediaView alloc] initWithFrame:CGRectMake(x, 0.f, PAGE_WIDTH, PAGE_HEIGHT)];
        [mediaView setDelegate:self];
        [scrollView addSubview:mediaView];
        [mediaView release];
        x += PAGE_WIDTH + PAGE_OFFSET;
    }
    
    CGFloat offset = (PAGE_WIDTH + PAGE_OFFSET) * (CGFloat)index;
    [scrollView setContentOffset:CGPointMake(offset, 0.f)];
    [self scrollViewDidEndDecelerating:scrollView];
}

- (void)ardronePlayerDidStartPlaying:(ARDronePlayerViewController *)videoPlayer
{
    // Hide video player controls and navBar after 1 second
    [self performSelector:@selector(hideMediaViewControls:) withObject:[NSNumber numberWithBool:YES] afterDelay:1.f];
}

- (void)ardronePlayerDidFinishPlaying:(ARDronePlayerViewController *)videoPlayer
{
    [self performSelector:@selector(hideMediaViewControls:) withObject:[NSNumber numberWithBool:NO]];
}

- (void)hideMediaViewControls:(NSNumber *)yesNoNumber
{
    BOOL yesNo = [yesNoNumber boolValue];
    
    [navBar.view setHidden:(yesNo || !navBar.view.hidden)];
    if (currentPlayer) [currentPlayer.controlsBar setHidden:navBar.view.hidden];  
                        
    // Set up fading animation
    CATransition *animation = [CATransition animation];
    [animation setDuration:0.2f];
    [animation setType:kCATransitionFade];
    [navBar.view.layer addAnimation:animation forKey:nil];
    if (currentPlayer) [currentPlayer.controlsBar.layer addAnimation:animation forKey:nil];
}

- (void)mediaViewToucheRecognized:(ARMediaView *)mediaView
{    
    [self hideMediaViewControls:[NSNumber numberWithBool:NO]];
}

- (void)scrollViewWillBeginDragging:(UIScrollView *)_scrollView
{    
    [self hideMediaViewControls:[NSNumber numberWithBool:YES]];
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)_scrollView
{
    currentPage = _scrollView.contentOffset.x / (PAGE_WIDTH + PAGE_OFFSET);
    ARMediaView *mediaView = [scrollView.subviews objectAtIndex:currentPage + 1];
    
    if (currentMediaView == mediaView) return;
    
    if (currentPlayer)
    {
        [currentMediaView.videoPlayer viewWillDisappear:NO];
        currentMediaView.videoPlayer = nil;
        [currentPlayer pauseVideo];
    }
    
    currentMediaView = mediaView;
    self.currentPlayer = mediaView.videoPlayer;
        
    [navBar setViewTitle:[NSString stringWithFormat:LOCALIZED_STRING(@"%d of %d"), currentPage + 1, [flightMediaAssets count]]];
    if (!mediaView.isMediaLoaded)
    {
        [mediaView bringSubviewToFront:mediaView.spinner];
        [mediaView.spinner startAnimating];

        MediaContentOperation *operation = [[MediaContentOperation alloc] initWithMediaAssetStringURL:[(ARThumbImageView *)[flightMediaAssets objectAtIndex:currentPage] assetURLString] pageIndex:currentPage delegate:self];
        [queue addOperation:operation];
        [operation release];
    }
}

- (void)displayFlightVideo:(NSDictionary *)dict
{    
    id key = [[dict allKeys] objectAtIndex:0];
    ARDronePlayerViewController *videoPlayer = [dict objectForKey:key];  
    [videoPlayer viewWillAppear:NO];
    ARMediaView *mediaView = [scrollView.subviews objectAtIndex:[key intValue] + 1];
    [mediaView.spinner stopAnimating];
    [mediaView addSubview:videoPlayer.view];
     
    [videoPlayer.controlsBar setHidden:navBar.view.hidden];
    [mediaView setVideoPlayer:videoPlayer];
    
    self.currentPlayer = videoPlayer;
    [currentPlayer setDelegate:self];
}

- (void)displayFlightPicture:(NSDictionary *)dic
{
    id key = [[dic allKeys] objectAtIndex:0];
    UIImage *image = [dic objectForKey:key];
    ARMediaView *mediaView = [scrollView.subviews objectAtIndex:[key intValue] + 1];
    [mediaView.spinner stopAnimating];
    UIImageView *imageView = [[UIImageView alloc] initWithFrame:CGRectMake(0.f, 0.f, PAGE_WIDTH, PAGE_HEIGHT)];
    [imageView setContentMode:UIViewContentModeScaleAspectFit];
    [imageView setImage:image];
    [mediaView addSubview:imageView];
    
    [mediaView setVideoPlayer:nil];
    currentPlayer = nil;
    
    [imageView release];
    [mediaView setIsMediaLoaded:YES];
}

#pragma mark - 
#pragma mark - IBActions
- (void)operationFinished:(NSError *)error
{
    if (error != nil)
        [loadingViewController setLoadingText:LOCALIZED_STRING(@"TRANSFER TO CAMERA ROLL FAILED!")];
    else
        [loadingViewController setLoadingText:LOCALIZED_STRING(@"TRANSFER TO CAMERA ROLL SUCCEED!")];
    
    [loadingViewController performSelector:@selector(hideView) withObject:nil afterDelay:LOADING_TIMEOUT];
}

- (IBAction)sendMedia
{    
    if ([(ARThumbImageView *)[flightMediaAssets objectAtIndex:currentPage] assetType] == ALAssetTypeVideo)
    {
        MediaVideoUploadingViewController *mediaUploadingViewController = [[MediaVideoUploadingViewController alloc] initWithNibName:@"MediaVideoUploadingView" bundle:nil];
        [mediaUploadingViewController setAssetURLString:[(ARThumbImageView *)[flightMediaAssets objectAtIndex:currentPage] assetURLString]];
        [self.navigationController pushViewController:mediaUploadingViewController animated:YES];
        [mediaUploadingViewController release];
    }
    else if([(ARThumbImageView *)[flightMediaAssets objectAtIndex:currentPage] assetType] == ALAssetTypePhoto)
    {
        MediaPhotoUploadingViewController *mediaUploadingViewController = [[MediaPhotoUploadingViewController alloc] initWithNibName:@"MediaPhotoUploadingView" bundle:nil];
        [mediaUploadingViewController setAssetURLString:[(ARThumbImageView *)[flightMediaAssets objectAtIndex:currentPage] assetURLString]];
        [self.navigationController pushViewController:mediaUploadingViewController animated:YES];
        [mediaUploadingViewController release];
    }
    // NO ELSE - No other type of media compatibility
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    //[self displaySendButton];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // Return YES for supported orientations
    return UIInterfaceOrientationIsLandscape(interfaceOrientation);
}

- (void)goBack
{
    [queue cancelAllOperations];
    
    if (currentPlayer)
    {
        [currentPlayer pauseVideo];
        self.currentPlayer = nil;
    }

    [self.navigationController popViewControllerAnimated:YES];
}

@end
