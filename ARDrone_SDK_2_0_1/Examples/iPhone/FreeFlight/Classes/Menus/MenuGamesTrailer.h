//
//  MenuGamesTrailer.h
//  FreeFlight
//
//  Created by Nicolas Payot on 26/01/12.
//  Copyright (c) 2012 PARROT. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "ARNavigationBarViewController.h"

@interface MenuGamesTrailer : UIViewController <UIWebViewDelegate>
{
    IBOutlet ARNavigationBarViewController *m_navBar;
    IBOutlet UIWebView *m_webView;
    
    NSString *m_trailerName;
    NSString *m_trailerID;
    
    IBOutlet UIActivityIndicatorView *spinner;
    IBOutlet UILabel *loadingLabel;
    
    BOOL trailerIsLoaded;
    BOOL errorDidOccur;
}

@property (nonatomic, retain) ARNavigationBarViewController *m_navBar;
@property (nonatomic, retain) IBOutlet UIWebView *m_webView;
@property (nonatomic, copy, setter = setTrailerName:) NSString *m_trailerName;
@property (nonatomic, copy, setter = setTrailerID:) NSString *m_trailerID;
@property (nonatomic, retain) IBOutlet UIActivityIndicatorView *spinner;
@property (nonatomic, retain) IBOutlet UILabel *loadingLabel;

- (void)centersStatusInfoLabel;

@end
