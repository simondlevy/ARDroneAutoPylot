//
//  ARALAssetsLibrary.h
//  FreeFlight
//
//  Created by Frédéric D'HAEYER / Nicolas PAYOT on 18/01/12.
//  Copyright 2011 PARROT. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AssetsLibrary/AssetsLibrary.h>

@class ARALAssetsLibrary;
@protocol ARALAssetsLibraryDelegate <NSObject>

- (void)assetsLibraryOperationFinished:(ARALAssetsLibrary *)assetsLibrary error:(NSError *)error;

@end

@interface ARALAssetsLibrary : ALAssetsLibrary
{
    NSString *m_albumName;
    ALAssetsGroup *m_group;
    id<ARALAssetsLibraryDelegate> _delegate;
    BOOL stateInProgress;
}

@property (nonatomic, copy) NSString *m_albumName;
@property (nonatomic, retain) ALAssetsGroup *m_group;
@property (nonatomic, assign) id<ARALAssetsLibraryDelegate> delegate;

- (id)initWithDelegate:(id<ARALAssetsLibraryDelegate>)delegate;
// Create new album in Photos library
- (void)createNewAlbumWithName:(NSString *)albumName;
- (void)saveVideo:(NSString *)videoPath;
- (void)saveImage:(UIImage *)image;
// Add photo / video to a new created album 
- (void)addAssetURL:(NSURL *)assetURL;
// Reload ALAssetsGroup for ALAssetsLibrary changes (can occur at any time...)
- (void)reloadALAssetsGroup;
   
@end
