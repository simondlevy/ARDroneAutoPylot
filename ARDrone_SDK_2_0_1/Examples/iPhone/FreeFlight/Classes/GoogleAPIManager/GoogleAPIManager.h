//
//  GoogleAPIManager.h
//  FreeFlight
//
//  Created by Frédéric D'Haeyer on 11/14/11.
//  Copyright 2011 Parrot SA. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Common.h"
#import "ARDroneMediaManager.h"
#import "GTMOAuth2SignIn.h"
#import "GData.h"
#import "GDataEntryYouTubeUpload.h"
#import "GDataServiceGooglePhotos.h"
#import "GDataAuthenticationFetcher.h"
#import "GDataEntryPhotoAlbum.h"
#import "GDataEntryPhoto.h"
#import "GDataFeedPhoto.h"
#import "GTMHTTPUploadFetcher.h"

#define kDefaultCategory    @"Film"

extern NSString *const GoogleAPIManagerDefaultEntryDidFinished;

@class GoogleAPIManager;

// GoogleAPIManager Class
@protocol GoogleAPIManagerDelegate 
@optional
// Authentification
- (void)googleAPIManagerDidFinishSignedIn:(GoogleAPIManager *)googleAPIManager error:(NSError *)error;

// Common on video and photo
- (void)googleAPIManagerUploadDidProgress:(GoogleAPIManager *)googleAPIManager percentValue:(float)percent;

// Videos
- (void)googleAPIManagerGetCategoriesDidFinish:(GoogleAPIManager *)googleAPIManager categories:(NSDictionary *)categories error:(NSError *)error;
- (void)googleAPIManagerVideoUploadDidFinish:(GoogleAPIManager *)googleAPIManager entry:(GDataEntryBase *)entry error:(NSError *)error;

// Photos
- (void)googleAPIManagerGetAlbumsDidFinish:(GoogleAPIManager *)googleAPIManager albums:(NSArray *)albums error:(NSError *)error;
- (void)googleAPIManagerCreateAlbumDidFinish:(GoogleAPIManager *)googleAPIManager error:(NSError *)error;
- (void)googleAPIManagerPhotoUploadDidFinish:(GoogleAPIManager *)googleAPIManager entry:(GDataEntryPhoto *)entry error:(NSError *)error;
@end

@interface GoogleAPIManagerEntry : NSObject
{
    GDataEntryBase *entry;
    NSString *assetURLString;
}

@property (nonatomic, retain) GDataEntryBase *entry;
@property (nonatomic, copy) NSString *assetURLString;

- (id)initWithDataEntryBase:(GDataEntryBase *)_entry withAssetURLString:(NSString *)_assetURLString;
@end

@interface GoogleAPIManager : NSObject 
{
    GDataServiceTicket *mUploadTicket, *mEntriesFetchTicket;
    NSMutableDictionary *uploadedDictionary;
    NSString *username;
    NSString *password;
    
    id<GoogleAPIManagerDelegate> authenticationController; 
}

@property (nonatomic, retain) NSMutableDictionary *uploadedDictionary;
@property (nonatomic, retain) id<GoogleAPIManagerDelegate> authenticationController;
@property (nonatomic, copy) NSString *username;
@property (nonatomic, copy) NSString *password;

+ (GoogleAPIManager *)sharedInstance;

// Authentication
- (NSString *)signedInUsername;
- (BOOL)isSignedIn;
- (void)signOut;
- (void)signIn:(id <GoogleAPIManagerDelegate>)controller username:(NSString *)username password:(NSString *)password;
- (void)cancelAllActions;

// Default Entry -> entry is returned by sending notification GoogleAPIManagerDefaultEntryDidFinished (GoogleAPIManagerEntry)
- (void)getDefaultEntry:(NSString *)assetURLString;

// Videos
- (void)getYouTubeCategories:(id <GoogleAPIManagerDelegate>)controller;
- (void)uploadVideo:(id <GoogleAPIManagerDelegate>)controller entry:(GoogleAPIManagerEntry *)entry;

// Photo
- (void)getPhotoAlbums:(id <GoogleAPIManagerDelegate>)controller;
- (void)uploadPhoto:(id <GoogleAPIManagerDelegate>)controller album:(GDataEntryPhotoAlbum *)album entry:(GoogleAPIManagerEntry *)entry;
- (void)createAlbum:(id <GoogleAPIManagerDelegate>)controller title:(NSString *)title private:(BOOL)bPrivate;
@end
