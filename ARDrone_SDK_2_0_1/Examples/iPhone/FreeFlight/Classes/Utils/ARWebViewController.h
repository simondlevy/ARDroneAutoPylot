//
//  ARWebViewController.h
//  FreeFlight
//
//  Created by Nicolas Payot on 03/02/12.
//  Copyright (c) 2012 PARROT. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "ARUtils.h"

@class ARWebViewController;
@protocol ARWebViewControllerDelegate <NSObject>

- (void)webViewControllerDidFinishLoad:(ARWebViewController *)webViewController;

@end

@interface ARWebViewController : UIViewController <UIWebViewDelegate>
{
    IBOutlet UIToolbar *toolbar;
    IBOutlet UIBarButtonItem *previous;
    IBOutlet UIBarButtonItem *next;
    IBOutlet UIBarButtonItem *done;
    IBOutlet UIWebView *webView;
    IBOutlet UIActivityIndicatorView *spinner;
    IBOutlet UILabel *statusInfoLabel;
    id<ARWebViewControllerDelegate> _delegate;
}

@property (nonatomic, retain) IBOutlet UIToolbar *toolbar;
@property (nonatomic, retain) IBOutlet UIBarButtonItem *previous;
@property (nonatomic, retain) IBOutlet UIBarButtonItem *next;
@property (nonatomic, retain) IBOutlet UIBarButtonItem *done;
@property (nonatomic, retain) IBOutlet UIWebView *webView;
@property (nonatomic, retain) IBOutlet UIActivityIndicatorView *spinner;
@property (nonatomic, retain) IBOutlet UILabel *statusInfoLabel;
@property (nonatomic, assign) id<ARWebViewControllerDelegate> delegate;

- (id)init;
- (void)setViewFrame:(CGRect)frame;
- (IBAction)previousButtonClicked:(id)sender;
- (IBAction)nextButtonClicked:(id)sender;
- (void)loadRequest:(NSURLRequest *)request;
- (void)loadHTMLString:(NSString *)htmlString;
- (IBAction)doneButtonClicked:(id)sender;
- (void)hideToolbar;
- (void)doneButtonHidden:(BOOL)hidden;
- (void)disableBouncing;
- (void)centersStatusInfoLabel;

@end
