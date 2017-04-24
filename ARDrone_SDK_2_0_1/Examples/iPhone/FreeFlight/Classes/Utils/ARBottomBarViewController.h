//
//  ARBottomBarViewController.h
//  FreeFlight
//
//  Created by Nicolas Payot on 26/10/11.
//  Copyright 2011 PARROT. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AssetsLibrary/AssetsLibrary.h>
#import "ARUtils.h"

@class ARBottomBarViewController;
@class ARButton;

@protocol ARBottomBarDelegate <NSObject>

- (void)bottomBar:(ARBottomBarViewController *)bar sortMediaWithType:(NSString *)assetType;

@end

@interface ARBottomBarViewController : UIViewController {
    id <ARBottomBarDelegate> _delegate;  
    
    IBOutlet UIView *loadingView;
    IBOutlet UILabel *sortLabel;
    IBOutlet ARButton *sortAll;
    IBOutlet ARButton *sortPhotos;
    IBOutlet ARButton *sortVideos;
    IBOutlet UILabel *loadingLabel;
}

@property (nonatomic, assign) id <ARBottomBarDelegate> delegate;

- (void)showLoadingView:(NSNumber *)show;
- (IBAction)displayAll;
- (IBAction)displayPhotos;
- (IBAction)displayVideos;

@end
