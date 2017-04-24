//
//  MediaViewController.h
//  FreeFlight
//
//  Created by Nicolas Payot on 04/08/11.
//  Copyright 2011 PARROT. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "Common.h"
#import "ARALAssetsLibrary.h"
#import "ARDronePlayerViewController.h"
#import "MediaVideoUploadingViewController.h"
#import "MediaPhotoUploadingViewController.h"
#import "ARUtils.h"

@class ARMediaView;
@protocol ARMediaViewDelegate <NSObject>

- (void)mediaViewToucheRecognized:(ARMediaView *)mediaView;

@end

@interface ARMediaView : UIView <UIGestureRecognizerDelegate>
{
    id<ARMediaViewDelegate> _delegate;
    UIActivityIndicatorView *spinner;
    BOOL isMediaLoaded;
    ARDronePlayerViewController *videoPlayer;
}

@property (nonatomic, assign) id<ARMediaViewDelegate> delegate;
@property (nonatomic, retain) UIActivityIndicatorView *spinner;
@property (nonatomic, assign) BOOL isMediaLoaded;
@property (nonatomic, retain) ARDronePlayerViewController *videoPlayer;

@end

@interface MediaContentOperation : NSOperation 
{
    NSString *mediaAssetStringURL;
    NSInteger pageIndex;
    id delegate;
}

- (id)initWithMediaAssetStringURL:(NSString *)mediaAssetStringURL pageIndex:(NSInteger)pageIndex delegate:(id)delegate;

@end

@interface MediaViewController : UIViewController <UIScrollViewDelegate, ARMediaViewDelegate, ARDronePlayerDelegate> 
{
    ARNavigationBarViewController *navBar;
    IBOutlet UIScrollView *scrollView;
    NSInteger index;
    NSArray *flightMediaAssets;
    NSOperationQueue *queue;
    NSInteger currentPage;
    ARDronePlayerViewController *currentPlayer;
    ARMediaView *currentMediaView;

    ARLoadingViewController *loadingViewController;
    
    id parent;
}

@property (nonatomic, assign) NSInteger index;
@property (nonatomic, retain) NSArray *flightMediaAssets;
@property (nonatomic, retain) ARDronePlayerViewController *currentPlayer;
@property (nonatomic, assign) id parent;

- (void)setScrollViewMediaViewFramesAndContentOffset;
- (IBAction)sendMedia;

@end
