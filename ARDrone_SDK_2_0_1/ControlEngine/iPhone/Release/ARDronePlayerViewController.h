//
//  ARDronePlayerViewController.h
//  ARDroneEngine
//
//  Created by Frédéric D'HAEYER / Nicolas Payot on 02/11/11.
//  Copyright 2011 PARROT. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

@interface UIScrubber : UISlider {
    // Nothing here
}
@end

@class ARDronePlayerViewController;

@protocol ARDronePlayerDelegate <NSObject>

- (void)ardronePlayerDidStartPlaying:(ARDronePlayerViewController *)videoPlayer;
- (void)ardronePlayerDidFinishPlaying:(ARDronePlayerViewController *)videoPlayer;

@end

@interface ARDronePlayerViewController : UIViewController {
    id<ARDronePlayerDelegate> _delegate;
    NSURL *videoFileURL;
    AVPlayerLayer *playerLayer;
    AVPlayer *videoPlayer;
    IBOutlet UIToolbar *controlsBar;
    UILabel *curValue;
    UILabel *remainValue;
    BOOL seekToZeroBeforePlay;
    IBOutlet UIScrubber *scrubber;
    id timeObserver;
    float restoreAfterScrubbingRate;
    IBOutlet UIButton *playButtonBig;
}

@property (nonatomic, assign) id<ARDronePlayerDelegate> delegate;
@property (nonatomic, copy) NSURL *videoFileURL;
@property (nonatomic, retain) AVPlayer *videoPlayer;
@property (nonatomic, retain) UIToolbar *controlsBar;
@property (nonatomic, retain) id timeObserver;
@property (nonatomic, retain) UIButton *playButtonBig;

- (id)initWithURL:(NSURL *)fileURL;
- (void)initTimeLabels;
- (IBAction)playPauseVideo:(id)sender;
- (void)initScrubberTimer;
- (IBAction)beginScrubbing:(id)sender;
- (IBAction)scrub:(id)sender;
- (IBAction)endScrubbing:(id)sender;
- (BOOL)isPlaying;
- (void)playVideo;
- (void)pauseVideo;
- (IBAction)playButtonBigClicked;

@end
