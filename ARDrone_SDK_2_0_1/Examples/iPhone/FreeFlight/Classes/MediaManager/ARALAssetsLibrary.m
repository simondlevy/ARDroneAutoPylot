//
//  ARALAssetsLibrary.m
//  FreeFlight
//
//  Created by Frédéric D'HAEYER / Nicolas PAYOT on 18/01/12.
//  Copyright 2011 PARROT. All rights reserved.
//

#import "ARALAssetsLibrary.h"

/* ================================================================
 * 
 * Make sure to add an observer on default notification center 
 * for "ALAssetsLibraryChangedNotification" within the class that 
 * will use ARALAssetsLibrary.
 * Observer should reload ALAssetsGroup.
 *
 * (Indeed, cached ALAssetsGroup is released for all ALAssetsLibray 
 * changes...
 *
 * ================================================================
 */
@interface ARALAssetsLibrary (private)
- (void)reloadALAssetsGroup;
@end

@implementation ARALAssetsLibrary

@synthesize m_albumName;
@synthesize m_group;
@synthesize delegate = _delegate;

- (id)initWithDelegate:(id<ARALAssetsLibraryDelegate>)aDelegate
{
    self = [super init];
    if (self)
    {
        self.m_albumName = nil;
        self.m_group = nil;
        self.delegate = aDelegate;
        stateInProgress = NO;
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reloadALAssetsGroup) 
                                                     name:ALAssetsLibraryChangedNotification object:nil];
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self 
                                                    name:ALAssetsLibraryChangedNotification object:nil];
    [m_albumName release];
    [m_group release];
    [super dealloc];
}

- (void)createNewAlbumWithName:(NSString *)albumName
{        
    self.m_albumName = albumName;
    
    __block BOOL albumWasFound = NO;
    
    // Search all photo albums in the library
    [self enumerateGroupsWithTypes:ALAssetsGroupAlbum usingBlock:^(ALAssetsGroup *group, BOOL *stop)
     {
         // Compare the names of the albums
         if ([m_albumName compare:[group valueForProperty:ALAssetsGroupPropertyName]] == NSOrderedSame) 
         {
             NSLog(@"%@ is already created.", m_albumName);
             albumWasFound = YES;
             self.m_group = group;
             [self.delegate assetsLibraryOperationFinished:self error:nil];
             *stop = YES;
         }
         
         if (group == nil && !albumWasFound)
         {
             // Create new album
             [self addAssetsGroupAlbumWithName:m_albumName resultBlock:^(ALAssetsGroup *group)
              {
                  NSLog(@"%@ was created.", m_albumName);
                  self.m_group = group;
                  [self.delegate assetsLibraryOperationFinished:self error:nil];
              } failureBlock:^(NSError *error)
              {
                  [self.delegate assetsLibraryOperationFinished:self error:error];
              }];
             *stop = YES;
         }
     } failureBlock:^(NSError *error)
     {
         [self.delegate assetsLibraryOperationFinished:self error:error];
     }];
}

- (void)saveImage:(UIImage *)image
{    
    // Write the image data to the assets library (camera roll)
    [self writeImageToSavedPhotosAlbum:image.CGImage orientation:(ALAssetOrientation)image.imageOrientation completionBlock:^(NSURL *assetURL, NSError *error)
    {
        // Error handling
        if (error != nil) 
        {
            //completionBlock(error);
            [self.delegate assetsLibraryOperationFinished:self error:error];
            return;
        }
        // Add the asset to the custom photo album
        [self addAssetURL:assetURL]; 
    }];
}

- (void)saveVideo:(NSString *)videoPath
{
    [self writeVideoAtPathToSavedPhotosAlbum:[NSURL URLWithString:videoPath] 
                             completionBlock:^(NSURL *assetURL, NSError *error) 
    {
        // Error handling
         if (error != nil) 
         {
             [self.delegate assetsLibraryOperationFinished:self error:error];
             return;
        }
        // Add the asset to the custom photo album
        [self addAssetURL:assetURL];
     }];
}

- (void)addAssetURL:(NSURL *)assetURL
{
    [self assetForURL:assetURL resultBlock:^(ALAsset *asset)
    {      
         if (m_group == nil)
         {
             NSLog(@"Error: a new album needs to be created first.");
         }
         else
         {
             if (![m_group addAsset:asset])
             {
                 NSLog(@"Error: asset could not be added to the album: %@", m_albumName);
                 [self performSelector:@selector(addAssetURL:) withObject:assetURL];
             }
             else 
             {
                 NSLog(@"Asset was added to the album: %@", m_albumName);
                 stateInProgress = YES;
             }
         }
     } failureBlock:^(NSError *error)
     {
         [self.delegate assetsLibraryOperationFinished:self error:error];
     }];
}

- (void)reloadALAssetsGroup
{    
    // Search all photo albums in the library
    [self enumerateGroupsWithTypes:ALAssetsGroupAlbum usingBlock:^(ALAssetsGroup *group, BOOL *stop)
     {
         // Compare the names of the albums
         if ([m_albumName compare:[group valueForProperty:ALAssetsGroupPropertyName]] == NSOrderedSame) 
         {
             self.m_group = group;
             *stop = YES;
             
             if(stateInProgress)
             {
                 stateInProgress = NO;
                 [self.delegate assetsLibraryOperationFinished:self error:nil];
             }
         
         }
     } failureBlock:^(NSError *error)
     {
         [self.delegate assetsLibraryOperationFinished:self error:error];
     }];
}

@end
