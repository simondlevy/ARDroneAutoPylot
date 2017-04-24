//
//  MediaThumbsViewController.m
//  FreeFlight
//
//  Created by Frédéric D'HAEYER / Nicolas PAYOT on 22/08/2011.
//  Copyright 2011 PARROT. All rights reserved.
//
#import <AssetsLibrary/AssetsLibrary.h>
#import "MediaThumbsViewController.h"
#import "MenuPreferences.h"
#import <MediaPlayer/MediaPlayer.h>

/* iPhone */
#define CELL_HEIGHT     ((UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) ? 125.f : 79.f)
#define COLUMNS_COUNT   ((UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) ? 8 : 6)
#define THUMB_SIZE      ((UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) ? 120.f : 75.f)

#define LEFT_MARGIN ((UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) ? 11.f : 5.f)
#define X_OFFSET    ((UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) ? 6.f : 4.f)
#define Y_OFFSET    ((UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) ? 6.f : 2.f)

/** #################### ARMediaCell Implementation #################### **/

@implementation ARMediaCell

@synthesize cellThumbs;

- (id)initWithThumbs:(NSArray *)thumbs reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:UITableViewCellStyleDefault reuseIdentifier:reuseIdentifier];
    if (self) {
        self.cellThumbs = thumbs;
    }
    return self;
}

- (void)setThumbs:(NSArray *)thumbs
{
    // Remove all thumbnails first
    for (ARThumbImageView *thumb in self.subviews)
        [thumb removeFromSuperview];
    self.cellThumbs = thumbs;
}

- (void)layoutSubviews 
{    
    CGRect frame = CGRectMake(LEFT_MARGIN, Y_OFFSET, THUMB_SIZE, THUMB_SIZE);
    for (NSInteger i = 0; i < [cellThumbs count]; ++i)
    {
        ARThumbImageView *thumb = [cellThumbs objectAtIndex:i];
        
        if (thumb.superview == self)
            continue;
        
        [thumb setUserInteractionEnabled:YES];

		frame.origin.x = LEFT_MARGIN + thumb.tag * (frame.size.width + X_OFFSET);
        [thumb setFrame:frame];
        [self addSubview:thumb];
	}
}

- (void)dealloc
{
    [cellThumbs release];
    [super dealloc];
}

@end

/** #################### ARThumbImageView Implementation #################### **/

@implementation ARThumbImageView
@synthesize assetType;
@synthesize remove;
@synthesize rowIndex;
@synthesize assetURLString;

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self)
    {
        [self setContentMode:UIViewContentModeScaleToFill];
        [self.layer setBorderWidth:1.f];
        [self.layer setBorderColor:[UIColor grayColor].CGColor];
        
        selectedLayer = [[UIImageView alloc] initWithFrame:CGRectMake(0.f, 0.f, THUMB_SIZE, THUMB_SIZE)];
        [selectedLayer setBackgroundColor:WHITE(0.5f)];
        
        CGRect frame = CGRectZero;
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
            frame = CGRectMake(70.f, 5.f, 45.f, 45.f);
        else 
            frame = CGRectMake(47.f, 5.f, 23.f, 23.f);
                                
        UIImageView *pin = [[UIImageView alloc] initWithFrame:frame];
        [pin setImage:[UIImage imageNamed:@"ff2.0_pin_selected.png"]];
        [selectedLayer addSubview:pin];
        [pin release];

        remove = NO;
        [self setUploadedState:[NSNumber numberWithInt:NOT_UPLOADED]];
    }
    return self;
}

- (void)dealloc
{
    [uploadedStateImageView release];
    [selectedLayer release];
    [super dealloc];
}

- (void)selectThumb:(BOOL)select
{
    if (select)
        [self addSubview:selectedLayer];
    else
        [selectedLayer removeFromSuperview];
}

- (void)setUploadedState:(NSNumber *)state // ARThumbUploadState
{
    ARThumbUploadState upload_state = [state intValue];
    CGRect frame;

    if (uploadedStateImageView != nil)
    {
        [uploadedStateImageView removeFromSuperview];
        [uploadedStateImageView release];
        uploadedStateImageView = nil;
    }
    
    switch (upload_state) 
    {
        case UPLOADED:
            uploadedStateImageView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:(UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad ? 
                                                                                             @"ff2.0_uploaded_status@2x.png" : @"ff2.0_uploaded_status.png")]];
            frame = uploadedStateImageView.frame;
            frame.origin.x = THUMB_SIZE - frame.size.width;
            frame.origin.y = THUMB_SIZE - frame.size.height;
            [uploadedStateImageView setFrame:frame];
            [self addSubview:uploadedStateImageView];
            break;

        case NOT_UPLOADED:
        default:
            break;
    }
}
@end

/** #################### ThumbnailUploadStateOperation Implementation #################### **/
@implementation ThumbnailUploadStateOperation

- (id)initWithImageView:(ARThumbImageView *)_imageView withDelegate:(id)_delegate
{
    self = [super init];
    if (self)
    {
        imageView   = _imageView;
        delegate    = _delegate;
    }
    return self;
}

- (void)dealloc
{
    [super dealloc];
}

- (void)main
{               
    if (imageView.assetURLString == nil) 
        return;
    
    if ([[[GoogleAPIManager sharedInstance] uploadedDictionary] objectForKey:imageView.assetURLString] != nil)
        [imageView performSelectorOnMainThread:@selector(setUploadedState:) withObject:[NSNumber numberWithInt:UPLOADED] waitUntilDone:NO];
    else
        [imageView performSelectorOnMainThread:@selector(setUploadedState:) withObject:[NSNumber numberWithInt:NOT_UPLOADED] waitUntilDone:NO];
}

@end

/** #################### MediaThumbsViewController Implementation #################### **/
@interface MediaThumbsViewController (private)
- (void)filterGlobalArrayWithThumbType:(NSString *)_assetType;
- (void)reloadTableView;
@end

@implementation MediaThumbsViewController

#define kMaxTransferingMedia    5

@synthesize allThumbnails;
@synthesize allFilteredThumbnails;
@synthesize thumbnailsPerRow;
@synthesize filteredThumbnailsPerRow;
@synthesize assetsToAdd;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    NSMutableString *nibName = [NSMutableString stringWithString:nibNameOrNil];
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
        [nibName appendString:@"-iPad"];
    
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) 
    {
        // Custom initialization
        controller = nil;
        currentMediaIdx = 0;
        sortAssetType = ALAssetTypeUnknown;
        needUploadState = NO;
        isCancel = NO;
    }
    
    return self;    
}

- (id)initWithController:(MenuController *)menuController
{
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
        self = [super initWithNibName:@"MediaThumbsView-iPad" bundle:nil];
    else
        self = [super initWithNibName:@"MediaThumbsView" bundle:nil];
    
    if (self) 
    {
        // Custom initialization
        controller = menuController;
        currentMediaIdx = 0;
        sortAssetType = ALAssetTypeUnknown;
        needUploadState = NO;
        isCancel = NO;
    }
    
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [queue cancelAllOperations];
    [queue release];
    [statusBar release];
    [navBar release];
    [bottomBar release];
    [tableView release];
    [loadingView release];
    self.allThumbnails = nil;
    self.allFilteredThumbnails = nil;
    self.thumbnailsPerRow = nil;
    self.filteredThumbnailsPerRow = nil;
    self.assetsToAdd = nil;
    [super dealloc];
}

- (void)didReceiveMemoryWarning
{
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
}

#pragma mark - View lifecycle
- (void)addNewAsset:(NSString *)assetURLString
{
    ALAssetsLibrary *library = [[ALAssetsLibrary alloc] init];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), 
    ^{
        [library assetForURL:[NSURL URLWithString:assetURLString] resultBlock:^(ALAsset *asset) 
        {
            if(asset != nil)
            {
                NSMutableArray *thumbPerRow = nil;
                if(([thumbnailsPerRow count] == 0) || ([[thumbnailsPerRow objectAtIndex:([thumbnailsPerRow count] - 1)] count] == COLUMNS_COUNT))
                {
                    [thumbnailsPerRow addObject:[NSMutableArray array]];
                }
                
                thumbPerRow = [thumbnailsPerRow objectAtIndex:([thumbnailsPerRow count] - 1)];

                ARImage *image = [[ARImage alloc] initWithCGImage:[asset thumbnail]];
                ARThumbImageView *imageView = [[ARThumbImageView alloc] initWithImage:image];
                [imageView setAssetURLString:assetURLString];
                [image release];
                
                UITapGestureRecognizer *tapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(mediaThumbWasSelected:)];
                [imageView addGestureRecognizer:tapGestureRecognizer];
                [tapGestureRecognizer release];
                
                [imageView setRowIndex:[thumbnailsPerRow count] - 1];
                [imageView setTag:[thumbPerRow count]];

                if([asset valueForProperty:ALAssetPropertyType] == ALAssetTypeVideo)
                {
                    [imageView setAssetType:ALAssetTypeVideo];
                    [allThumbnails addObject:imageView];
                    
                    if(sortAssetType == ALAssetTypeVideo)
                        [allFilteredThumbnails addObject:imageView];
     
                    UIImageView *watchIcon = [[UIImageView alloc] initWithFrame:CGRectMake(THUMB_SIZE / 4, THUMB_SIZE / 4, THUMB_SIZE / 2, THUMB_SIZE / 2)];
                    [watchIcon setImage:[UIImage imageNamed:@"ff2.0_media_watch.png"]];
                    [imageView addSubview:watchIcon];
                    [watchIcon release];
                    [thumbPerRow addObject:imageView];
                }
                else if([asset valueForProperty:ALAssetPropertyType] == ALAssetTypePhoto)
                {
                    [imageView setAssetType:ALAssetTypePhoto];
                    [allThumbnails addObject:imageView];
                   
                    if(sortAssetType == ALAssetTypePhoto)
                        [allFilteredThumbnails addObject:imageView];

                    [thumbPerRow addObject:imageView];
                }
                
                if ([[[GoogleAPIManager sharedInstance] uploadedDictionary] objectForKey:assetURLString] != nil)
                {   
                    [imageView performSelectorOnMainThread:@selector(setUploadedState:) withObject:[NSNumber numberWithInt:UPLOADED] waitUntilDone:NO];
                }
                else
                {
                    [imageView performSelectorOnMainThread:@selector(setUploadedState:) withObject:[NSNumber numberWithInt:NOT_UPLOADED] waitUntilDone:NO];
                }
                
                [imageView release];
                
                if([assetsToAdd count] > 0)
                {
                    [self addNewAsset:[assetsToAdd objectAtIndex:0]];
                    [assetsToAdd removeObjectAtIndex:0];
                }
                
                dispatch_async(dispatch_get_main_queue(), 
                ^{
                    [tableView reloadData];
                });
            }
        }
        failureBlock:^(NSError *error) 
        {
            NSLog(@"Failure : %@", error);
        }];
    });
    [library release];
}

- (void)observeNotifications:(NSNotification *)notification
{
    if([[notification name] isEqualToString:ARDroneMediaManagerDidRefresh])
    {
        [assetsToAdd addObject:[notification object]];
        if([assetsToAdd count] == 1) 
        {
            [self performSelector:@selector(addNewAsset:) withObject:[assetsToAdd objectAtIndex:0]];
            [assetsToAdd removeObjectAtIndex:0];
        }
    }
    else if([[notification name] isEqualToString:ARDroneMediaManagerIsReady])
    {
        [[NSNotificationCenter defaultCenter] removeObserver:self name:ARDroneMediaManagerIsReady object:nil];
        
        [self performSelectorInBackground:@selector(loadAllAssets) withObject:nil];
        [bottomBar performSelectorOnMainThread:@selector(showLoadingView:) withObject:[NSNumber numberWithBool:NO] waitUntilDone:NO];
    }
}

- (void)loadAllAssets
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    NSArray *keyArray = [[[[[ARDroneMediaManager sharedInstance] mediaDictionary] copy] autorelease] keysSortedByValueUsingComparator:^NSComparisonResult(id obj1, id obj2) 
    {
        return [(NSString *)obj1 compare:(NSString *)obj2];                
    }];
                          
    for(NSString *_assetURLString in keyArray)
    {
        [assetsToAdd addObject:_assetURLString]; 
    }
    
    [self addNewAsset:[assetsToAdd objectAtIndex:0]];
    [assetsToAdd removeObjectAtIndex:0];
    [pool release];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    // Do any additional setup after loading the view from its nib.
    [self.navigationController setNavigationBarHidden:YES];
    
    statusBar = [[ARStatusBarViewController alloc] initWithNibName:STATUS_BAR bundle:nil];
    [statusBar setDelegate:self];
    [self.view addSubview:statusBar.view];
    
    navBar = [[ARNavigationBarViewController alloc] initWithNibName:NAVIGATION_BAR bundle:nil];
    [self.view addSubview:navBar.view];
    [navBar setViewTitle:LOCALIZED_STRING(@"PHOTOS / VIDEOS")];
    if (controller) [navBar displayHomeButton];
    [navBar.leftButton addTarget:self action:@selector(goBackToHome) forControlEvents:UIControlEventTouchUpInside];
    [navBar setTransparentStyle:YES];
    
    [loadingLabel setText:LOCALIZED_STRING(@"Loading...")];
    
    bottomBar = [[ARBottomBarViewController alloc] initWithNibName:BOTTOM_BAR bundle:nil];
    [self.view addSubview:bottomBar.view];
    [bottomBar setDelegate:self];
    [bottomBar showLoadingView:[NSNumber numberWithBool:YES]];
     
    [tableView setSeparatorColor:[UIColor clearColor]];
    [tableView setAllowsSelection:NO];
    [tableView setBackgroundColor:[UIColor clearColor]];
    
    CGRect frame = tableView.frame;
    frame.size.height -= (statusBar.view.frame.size.height + bottomBar.view.frame.size.height + 8.f);
    frame.origin.y += statusBar.view.frame.size.height + 3.f;
    [tableView setFrame:frame];

    UIView *margin = [[UIView alloc] initWithFrame:CGRectMake(0.f, 0.f, self.view.frame.size.width, navBar.view.frame.size.height)];
    [tableView setTableHeaderView:margin];
    [margin release];
    
    self.allThumbnails              = [NSMutableArray array];
    self.allFilteredThumbnails      = [NSMutableArray array];
    self.thumbnailsPerRow           = [NSMutableArray array];
    self.filteredThumbnailsPerRow   = [NSMutableArray array];
    self.assetsToAdd                = [NSMutableArray array];
    
    [tableView setDelegate:self];
    [tableView setDataSource:self];
    [loadingView setHidden:YES];
    
    loadingViewController = [[ARLoadingViewController alloc] init];
    [self.view addSubview:loadingViewController.view];
    [loadingViewController setCancelButtonTitle:LOCALIZED_STRING(@"DISMISS")];
    [loadingViewController displayCancelButton:YES];

    queue = [NSOperationQueue new];
    
    if([[ARDroneMediaManager sharedInstance] mediaManagerReady])
    {
        [self performSelectorInBackground:@selector(loadAllAssets) withObject:nil];
        [bottomBar performSelectorOnMainThread:@selector(showLoadingView:) withObject:[NSNumber numberWithBool:NO] waitUntilDone:NO];
    }
    else
    {
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(observeNotifications:) name:ARDroneMediaManagerIsReady object:nil];
    }
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(observeNotifications:) name:ARDroneMediaManagerDidRefresh object:nil];
}

- (void)viewDidUnload
{
    [super viewDidUnload];
}

- (void)statusBarPreferencesClicked:(ARStatusBarViewController *)bar
{
    MenuPreferences *menuPreferences = [[MenuPreferences alloc] initWithController:controller];
    [self.navigationController pushViewController:menuPreferences animated:NO];
    [menuPreferences release];
}

- (void)goBackToHome
{
    isCancel = YES;
    if (controller)
    {
        [controller doAction:MENU_FF_ACTION_JUMP_TO_HOME];
    }
    else
    {
        [self.navigationController popViewControllerAnimated:YES];
    }
}

- (void)viewDidDisappear:(BOOL)animated
{
    needUploadState = YES;
}

- (void)viewWillAppear:(BOOL)animated
{
    if(needUploadState)
    {
        if ([allThumbnails count] == 0)
            return;
        
        for (ARThumbImageView *imageView in allThumbnails)
        {
            ThumbnailUploadStateOperation *operation = [[ThumbnailUploadStateOperation alloc] initWithImageView:imageView withDelegate:self];
            [queue addOperation:operation];
            [operation release];
        }
    }
}

#pragma mark - 
#pragma mark UITableView delegate & datasource
- (NSArray *)thumbsForIndexPath:(NSIndexPath *)indexPath
{
    NSMutableArray *array = [NSMutableArray array];
    if (sortAssetType == ALAssetTypeUnknown)
        array = [NSArray arrayWithArray:thumbnailsPerRow];
    else
        array = [NSArray arrayWithArray:filteredThumbnailsPerRow];
    
    if ([array count] == 0) return nil;
    return [array objectAtIndex:[indexPath row]];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    // Return the number of sections.
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    NSInteger numberOfRows;
    
    if (sortAssetType == ALAssetTypeUnknown) 
        numberOfRows = [thumbnailsPerRow count];
    else 
        numberOfRows = [filteredThumbnailsPerRow count];
    
    // Return the number of rows in the section.
    return numberOfRows;
}

- (UITableViewCell *)tableView:(UITableView *)_tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"Cell";
    ARMediaCell *cell = (ARMediaCell *)[tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) 
        cell = [[[ARMediaCell alloc] initWithThumbs:[self thumbsForIndexPath:indexPath] reuseIdentifier:CellIdentifier] autorelease];
    
    [cell setThumbs:[self thumbsForIndexPath:indexPath]];
    
    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return CELL_HEIGHT;
}

- (void)mediaThumbWasSelected:(id)sender
{    
    ARThumbImageView *thumb = (ARThumbImageView *)[(UITapGestureRecognizer *)sender view];
    NSInteger globalIndex = thumb.rowIndex * COLUMNS_COUNT + thumb.tag;    
    MediaViewController *mediaViewController = [[MediaViewController alloc] initWithNibName:@"MediaView" bundle:nil];   
    [mediaViewController setParent:self];
    if(sortAssetType == ALAssetTypeUnknown)
    {
        [mediaViewController setFlightMediaAssets:allThumbnails];
    }
    else
    {
        [mediaViewController setFlightMediaAssets:allFilteredThumbnails];
    }

    [mediaViewController setIndex:globalIndex];
    [self.navigationController pushViewController:mediaViewController animated:YES];
    [mediaViewController release];
}

- (void)filterGlobalArrayWithThumbType:(NSString *)_assetType
{
    [filteredThumbnailsPerRow removeAllObjects];
    [allFilteredThumbnails removeAllObjects];
    
    // Filter thumbnailsPerRow
    for (NSArray *array in thumbnailsPerRow)
    {
        for (ARThumbImageView *thumb in array)
        {
            if (thumb.assetType == _assetType)
                [allFilteredThumbnails addObject:thumb];
        }
    }
    
    NSInteger n = COLUMNS_COUNT;
    NSInteger rowsCount = ceil([allFilteredThumbnails count] / (CGFloat)COLUMNS_COUNT);
    
    for (NSInteger r = 0; r < rowsCount; ++r)
    {
        NSMutableArray *array = [NSMutableArray array];
        // If we are on last row
        if (r == rowsCount - 1)
            if ([allFilteredThumbnails count] % COLUMNS_COUNT != 0)
                n = [allFilteredThumbnails count] % COLUMNS_COUNT;
        
        for (NSInteger c = 0; c < n; ++c)
        {
            ARThumbImageView *thumb = [allFilteredThumbnails objectAtIndex:(COLUMNS_COUNT * r + c)];
            [thumb setRowIndex:r];
            [thumb setTag:c];
            [array addObject:thumb];
        }
        
        [filteredThumbnailsPerRow addObject:array];
    }
}

- (void)bottomBar:(ARBottomBarViewController *)bar sortMediaWithType:(NSString *)_assetType
{    
    NSInteger rowIndex = 0;
    sortAssetType = _assetType;
    if(sortAssetType == ALAssetTypeUnknown)
    {
        // Re-tag thumbs with correct row and column number
        for (NSArray *array in thumbnailsPerRow)
        {
            NSInteger colIndex = 0;
            for (ARThumbImageView *thumb in array)
            {
                [thumb setRowIndex:rowIndex];
                [thumb setTag:colIndex++];
            }
            ++rowIndex;
        }
    }
    else
    {
        [self filterGlobalArrayWithThumbType:sortAssetType];
    }

    [tableView reloadData];
}

- (NSMutableArray *)removeThumbsFromView:(NSMutableArray *)thumbsPerRow
{
    NSMutableArray *thumbs = [NSMutableArray array];
    for (NSArray *array in thumbsPerRow)
    {
        for (ARThumbImageView *thumb in array)
        {
            if (!thumb.remove)
                [thumbs addObject:thumb];
        }
    }
    [thumbsPerRow removeAllObjects];
    return thumbs;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // Return YES for supported orientations
    return UIInterfaceOrientationIsLandscape(interfaceOrientation);
}

- (void) executeCommandOut:(ARDRONE_COMMAND_OUT)commandId withParameter:(void *)parameter fromSender:(id)sender
{
    
}
@end
