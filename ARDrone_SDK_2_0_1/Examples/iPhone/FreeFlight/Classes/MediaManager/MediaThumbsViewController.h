//
//  MediaThumbsViewController.h
//  ARDroneAcademy
//
//  Created by Frédéric D'HAEYER / Nicolas PAYOT on 29/06/11.
//  Copyright 2011 PARROT. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AssetsLibrary/AssetsLibrary.h>
#import "ARALAssetsLibrary.h"
#import <UIKit/UIKit.h>

#import "ARDroneMediaManager.h"
#import "MediaViewController.h"
#import "Common.h"
#import "MenuController.h"
#import "ARUtils.h"

/** #################### ARMediaCell Interface #################### **/

@interface ARMediaCell : UITableViewCell {
    NSArray *cellThumbs;
}

@property (nonatomic, retain) NSArray *cellThumbs;

- (id)initWithThumbs:(NSArray *)thumbs reuseIdentifier:(NSString *)reuseIdentifier;
- (void)setThumbs:(NSArray *)thumbs;

@end

/** #################### ARThumbImageView Interface #################### **/

typedef enum { NOT_UPLOADED, UPLOADED } ARThumbUploadState;

@interface ARThumbImageView : UIImageView {
    UIImageView *uploadedStateImageView;
    UIImageView *selectedLayer;
    BOOL remove;
    NSInteger rowIndex;
    NSString *assetType;
    NSString *assetURLString;
}

@property (nonatomic, assign) BOOL remove;
@property (nonatomic, assign) NSInteger rowIndex;
@property (nonatomic, assign) NSString *assetType;
@property (nonatomic, assign) NSString *assetURLString;

- (void)selectThumb:(BOOL)select;
- (void)setUploadedState:(NSNumber *)state;

@end

/** #################### ThumbnailUploadStateOperation Interface #################### **/

@interface ThumbnailUploadStateOperation : NSOperation {
    ARThumbImageView *imageView;
    id delegate;
}

- (id)initWithImageView:(ARThumbImageView *)imageView withDelegate:(id)delegate;

@end

/** #################### MediaThumbsViewController Interface #################### **/

@interface MediaThumbsViewController : UIViewController <UITableViewDelegate, UITableViewDataSource, ARBottomBarDelegate, ARStatusBarDelegate, MenuProtocol>
{
    MenuController *controller;
    ARStatusBarViewController *statusBar;
    ARNavigationBarViewController *navBar;
    ARBottomBarViewController *bottomBar;
    IBOutlet UIView *loadingView;
    IBOutlet UILabel *loadingLabel;
    IBOutlet UITableView *tableView;
    NSMutableArray *allThumbnails;
    NSMutableArray *allFilteredThumbnails;
    NSMutableArray *thumbnailsPerRow;
    NSMutableArray *filteredThumbnailsPerRow;
    NSMutableArray *assetsToAdd;
    NSOperationQueue *queue;
    NSString *sortAssetType;
    NSInteger currentPage;
    int currentMediaIdx;
    BOOL needUploadState;
    BOOL isCancel;
    ARLoadingViewController *loadingViewController;
}

@property (nonatomic, retain) NSMutableArray *allThumbnails;
@property (nonatomic, retain) NSMutableArray *allFilteredThumbnails;
@property (nonatomic, retain) NSMutableArray *thumbnailsPerRow;
@property (nonatomic, retain) NSMutableArray *filteredThumbnailsPerRow;
@property (nonatomic, retain) NSMutableArray *assetsToAdd;

- (id)initWithController:(MenuController *)menuController;

@end
