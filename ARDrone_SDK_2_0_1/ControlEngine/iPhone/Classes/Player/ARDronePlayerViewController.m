//
//  ARDronePlayerViewController.m
//  ARDroneEngine
//
//  Created by Frédéric D'HAEYER / Nicolas Payot on 02/11/11.
//  Copyright 2011 PARROT. All rights reserved.
//

#import "ARDronePlayerViewController.h"
#include "ConstantsAndMacros.h"

@implementation UIScrubber

// Improve touch zone for player scrubber when superview is scrollView
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event
{
	CGRect thumbFrame = [self thumbRectForBounds:self.bounds trackRect:[self trackRectForBounds:self.bounds] value:self.value];
	if (CGRectContainsPoint(thumbFrame, point))
		return [super hitTest:point withEvent:event];
	else
		return [[self superview] hitTest:point withEvent:event];
}

@end

@implementation ARDronePlayerViewController

@synthesize delegate = _delegate;
@synthesize videoFileURL;
@synthesize videoPlayer;
@synthesize controlsBar;
@synthesize timeObserver;
@synthesize playButtonBig;

- (id)initWithURL:(NSURL *)fileURL
{
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
        self = [super initWithNibName:@"ARDronePlayerView-iPad" bundle:nil];
    else 
        self = [super initWithNibName:@"ARDronePlayerView" bundle:nil];
    
    if (self) {
        // Custom initialization
        self.videoFileURL = fileURL;
    }
    return self;
}

- (void)dealloc
{
    [videoPlayer.currentItem removeObserver:self forKeyPath:@"status"];
    [playButtonBig release];
    [CATransaction setDisableActions:YES];
    [playerLayer removeFromSuperlayer];
    [curValue release];
    [remainValue release];
    [scrubber release];
    [controlsBar release];
    [timeObserver release];
    [videoPlayer release];
    [videoFileURL release];
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

    self.videoPlayer = [AVPlayer playerWithURL:videoFileURL];    
    playerLayer = [AVPlayerLayer playerLayerWithPlayer:videoPlayer];
    [playerLayer setPlayer:videoPlayer];
    [CATransaction setDisableActions:YES];
    [self.view.layer addSublayer:playerLayer];
    [playerLayer setFrame:self.view.bounds];
    [playerLayer setVideoGravity:AVLayerVideoGravityResizeAspect];
    
    [self.view bringSubviewToFront:playButtonBig];
    
    [controlsBar setHidden:YES];
    [playButtonBig setHidden:YES];
    
    [scrubber setValue:0.f];
    seekToZeroBeforePlay = NO;
    timeObserver = nil;
    
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
    {
        curValue = [[UILabel alloc] initWithFrame:CGRectMake(0.f, 0.f, 80.f, 22.f)];
        remainValue = [[UILabel alloc] initWithFrame:CGRectMake(0.f, 0.f, 80.f, 22.f)];
        [curValue setFont:[UIFont boldSystemFontOfSize:18.f]];
        [remainValue setFont:[UIFont boldSystemFontOfSize:18.f]];
    }
    else 
    {
        curValue = [[UILabel alloc] initWithFrame:CGRectMake(0.f, 0.f, 40.f, 22.f)];
        remainValue = [[UILabel alloc] initWithFrame:CGRectMake(0.f, 0.f, 40.f, 22.f)];
        [curValue setFont:[UIFont boldSystemFontOfSize:13.f]];
        [remainValue setFont:[UIFont boldSystemFontOfSize:13.f]];
    }
    [curValue setBackgroundColor:[UIColor clearColor]];
    [remainValue setBackgroundColor:[UIColor clearColor]];
    [curValue setTextColor:[UIColor whiteColor]];
    [remainValue setTextColor:[UIColor whiteColor]];
    [curValue setTextAlignment:UITextAlignmentCenter];
    [remainValue setTextAlignment:UITextAlignmentCenter];
    [curValue setText:@"0.00"];
    [remainValue setText:@"0.00"];
    
    UIBarButtonItem *leftLabelItem = [[UIBarButtonItem alloc] initWithCustomView:curValue];
    UIBarButtonItem *rightLabelItem = [[UIBarButtonItem alloc] initWithCustomView:remainValue];
    
    NSMutableArray *items = [NSMutableArray arrayWithArray:controlsBar.items];
    [items insertObject:leftLabelItem atIndex:1];
    [items insertObject:rightLabelItem atIndex:3];
    [controlsBar setItems:items];
    
    [leftLabelItem release];
    [rightLabelItem release];
    
    [self.view bringSubviewToFront:controlsBar];
    CGRect frame = controlsBar.frame;
    if (UI_USER_INTERFACE_IDIOM() != UIUserInterfaceIdiomPad)
        frame.size.height = 32.f;
    frame.origin.y = self.view.frame.size.height - frame.size.height;
    [controlsBar setFrame:frame];
    
    // Observe status changes
    [videoPlayer.currentItem addObserver:self forKeyPath:@"status" options:0 context:NULL];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [playButtonBig setHidden:YES];
    [[NSNotificationCenter defaultCenter] postNotificationName:QuicktimeEncoderStageDidResume object:nil];
	[super viewWillDisappear:animated];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [[NSNotificationCenter defaultCenter] postNotificationName:QuicktimeEncoderStageDidSuspend object:nil];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [playButtonBig setHidden:NO];
}

- (void)playButtonBigClicked
{
    [self playPauseVideo:nil];
}

// Cancel the previously registered time observer.
- (void)removePlayerTimeObserver
{
	if (timeObserver)
	{
		[videoPlayer removeTimeObserver:timeObserver];
		[timeObserver release];
		timeObserver = nil;
	}
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    AVPlayerItem *videoPlayerCurrentItem = (AVPlayerItem *)object;
    UIBarButtonItem *playButton = [controlsBar.items objectAtIndex:0];
    
    switch (videoPlayerCurrentItem.status) 
    {
        case AVPlayerItemStatusReadyToPlay:
            [self initTimeLabels];
            [playButton setEnabled:YES];
            [playButtonBig setHidden:NO];
            break;
        case AVPlayerItemStatusUnknown:
        case AVPlayerItemStatusFailed:
            [playButton setEnabled:NO];
            [playButtonBig setHidden:YES];
            NSLog(@"AVPlayerItemStatusFailed: video cannot be played");
            break;
        default:
            break;
    }
}

- (float)remainingTimeValue:(double)duration
{
    return (floorf(duration / 60.f) + (((int)duration % 60) / 100.f));
}

- (CMTime)currentItemDuration
{
    CMTime duration = kCMTimeZero;
    if ([videoPlayer.currentItem respondsToSelector:@selector(duration)])
        duration = videoPlayer.currentItem.duration;
    else
        duration = videoPlayer.currentItem.asset.duration;
    
    return duration;
}

- (void)initTimeLabels
{
    [curValue setText:@"0.00"];
    CMTime playerDuration = [self currentItemDuration];
    double duration = CMTimeGetSeconds(playerDuration);
	if (isfinite(duration))
        [remainValue setText:[NSString stringWithFormat:@"%0.2f", - [self remainingTimeValue:duration]]];
}

- (void)setPlayButton
{
    // Set play button
    UIBarButtonItem *playButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemPlay target:self action:@selector(playPauseVideo:)];
    NSMutableArray *items = [NSMutableArray arrayWithArray:controlsBar.items];
    [items replaceObjectAtIndex:0 withObject:playButton];
    [controlsBar setItems:items];
    [playButton release];
    // Pause video
    [self pauseVideo];
}

- (void)setPauseButton
{
    // Set pause button
    UIBarButtonItem *pauseButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemPause target:self action:@selector(playPauseVideo:)];
    NSMutableArray *items = [NSMutableArray arrayWithArray:controlsBar.items];
    [items replaceObjectAtIndex:0 withObject:pauseButton];
    [controlsBar setItems:items];
    [pauseButton release];
    // Play video
    [self playVideo];
}

- (void)playPauseVideo:(id)sender
{
    // Currently playing
    if ([self isPlaying])
        [self setPlayButton];
    // Not playing
    else
        [self setPauseButton];
}

- (void)playVideo
{
    [playButtonBig setHidden:YES];
    // Set up fading animation
    CATransition *animation = [CATransition animation];
    [animation setDuration:0.2f];
    [animation setType:kCATransitionFade];
    [playButtonBig.layer addAnimation:animation forKey:nil];
    
    [self initScrubberTimer];
    // If we are at the end of the movie, we must seek to the beginning first before starting playback
    if (seekToZeroBeforePlay)
    {
        seekToZeroBeforePlay = NO;
        [videoPlayer seekToTime:kCMTimeZero];
    }
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playerItemDidReachEnd:)
                                                 name:AVPlayerItemDidPlayToEndTimeNotification
                                               object:nil];
    [videoPlayer play];
    // Notify delegate 
    [self.delegate ardronePlayerDidStartPlaying:self];
}

- (void)pauseVideo
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:AVPlayerItemDidPlayToEndTimeNotification object:nil];
    [self removePlayerTimeObserver];
    [videoPlayer pause];
}

/* ---------------------------------------------------------
 ** Called when the player item has played to its end time 
 ** Graphic tasks have to be done on the main thread
 ** (the notification can arrive on a different thread) 
 ** ------------------------------------------------------*/
- (void)playerItemDidReachEnd:(NSNotification *)notification 
{
	// After the movie has played to its end time, seek back to time zero to play it again.
	seekToZeroBeforePlay = YES;
    [self performSelectorOnMainThread:@selector(setPlayButton) withObject:nil waitUntilDone:NO];
    [self.delegate ardronePlayerDidFinishPlaying:self];
}

/* --------------------------------------------------------------
 **  Methods to handle manipulation of the movie scrubber control
 ** ---------------------------------------------------------- */

// Set the scrubber based on the player current time.
- (void)syncScrubber
{
	CMTime playerDuration = [self currentItemDuration];
	if (CMTIME_IS_INVALID(playerDuration)) 
	{
		[scrubber setMinimumValue:0.f];
        curValue.text = [NSString stringWithFormat:@"%0.2f", 0.f];
		return;
	} 
    
	double duration = CMTimeGetSeconds(playerDuration);
	if (isfinite(duration))
	{
		float minValue = [scrubber minimumValue];
		float maxValue = [scrubber maximumValue];
		double time = CMTimeGetSeconds([videoPlayer currentTime]);
		
		[scrubber setValue:(maxValue - minValue) * time / duration + minValue];
        [curValue setText:[NSString stringWithFormat:@"%0.2f", [self remainingTimeValue:time]]];
        [remainValue setText:[NSString stringWithFormat:@"%0.2f", - [self remainingTimeValue:(duration - time)]]];
    }
}

// Requests invocation of a given block during media playback to update the movie scrubber control.
-(void)initScrubberTimer
{
	double interval = .1f;
	
	CMTime playerDuration = [self currentItemDuration];
	if (CMTIME_IS_INVALID(playerDuration)) 
	{
		return;
	} 
	double duration = CMTimeGetSeconds(playerDuration);
    
	if (isfinite(duration))
	{
		CGFloat width = CGRectGetWidth([scrubber bounds]);
		interval = 0.5f * duration / width;
        [remainValue setText:[NSString stringWithFormat:@"%0.2f", - [self remainingTimeValue:duration]]];
	}
    
	// Update the scrubber during normal playback.
    self.timeObserver = [videoPlayer addPeriodicTimeObserverForInterval:CMTimeMakeWithSeconds(interval, NSEC_PER_SEC) 
                                                                  queue:NULL /* If you pass NULL, the main queue is used. */
                                                             usingBlock:^(CMTime time) { [self syncScrubber]; }];
}

// The user is dragging the movie controller thumb to scrub through the movie.
- (void)beginScrubbing:(id)sender
{
	restoreAfterScrubbingRate = videoPlayer.rate;
	[videoPlayer setRate:0.f];
	// Remove previous timer
	[self removePlayerTimeObserver];
}

/* Set the player current time to match the scrubber position. */
- (void)scrub:(id)sender
{
    UISlider *slider = (UISlider *)sender;
    
    CMTime playerDuration = [self currentItemDuration];
    if (CMTIME_IS_INVALID(playerDuration))
        return;
    
    double duration = CMTimeGetSeconds(playerDuration);
    if (isfinite(duration))
    {
        float minValue = [slider minimumValue];
        float maxValue = [slider maximumValue];
        float value = [slider value];
        
        double time = duration * (value - minValue) / (maxValue - minValue);
        [videoPlayer seekToTime:CMTimeMakeWithSeconds(time, NSEC_PER_SEC)];
        
        [curValue setText:[NSString stringWithFormat:@"%0.2f", [self remainingTimeValue:time]]];
        [remainValue setText:[NSString stringWithFormat:@"%0.2f", - [self remainingTimeValue:(duration - time)]]];
    }
}

// The user has released the movie thumb control to stop scrubbing through the movie.
- (void)endScrubbing:(id)sender
{
	if (!timeObserver)
	{
		CMTime playerDuration = [self currentItemDuration];
		if (CMTIME_IS_INVALID(playerDuration)) 
			return;
		
		double duration = CMTimeGetSeconds(playerDuration);
		if (isfinite(duration))
		{
			CGFloat width = CGRectGetWidth([scrubber bounds]);
			double tolerance = 0.5f * duration / width;
            
			self.timeObserver = [videoPlayer addPeriodicTimeObserverForInterval:CMTimeMakeWithSeconds(tolerance, NSEC_PER_SEC) 
                                                                          queue:NULL 
                                                                     usingBlock:^(CMTime time) { [self syncScrubber]; }];
		}
	}
    
	if (restoreAfterScrubbingRate)
	{
		[videoPlayer setRate:restoreAfterScrubbingRate];
		restoreAfterScrubbingRate = 0.f;
	}
}

- (BOOL)isPlaying
{
    return restoreAfterScrubbingRate != 0.f || [videoPlayer rate] != 0.f;
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

@end
