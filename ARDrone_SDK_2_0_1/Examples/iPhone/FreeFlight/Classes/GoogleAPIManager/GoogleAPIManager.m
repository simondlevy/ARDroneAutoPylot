//
//  GoogleAPIManager.m
//  FreeFlight
//
//  Created by Frédéric D'Haeyer on 11/14/11.
//  Copyright 2011 Parrot SA. All rights reserved.
//

#import "GoogleAPIManager.h"
#import "ARUtils.h"

#define kDefaultClientID            @"147984446908.apps.googleusercontent.com"
#define kDefaultSecretID            @"Zg2kBxBqMK1cKMVTdkDJwcpa"
#define kDefaultDeveloperKey        @"AI39si7MBT09Ww1Duu4iACHY1ftDE5Aj91xXS61IkYi3nRbtqXOYS9Ka2NpyLfvZwddelFfmhduH6A-XhkGOb7vVIaBQCassxA"

#define kDefaultUploadingXMLFile    @"uploading.plist"
#define kDefaultUploadedXMLFile     @"uploaded.plist"

#define GOOGLEAPIMANAGER_BUFFER_SIZE   2048

#pragma mark GoogleAPIManagerEntry
@implementation GoogleAPIManagerEntry
@synthesize entry;
@synthesize assetURLString;
- (id)initWithDataEntryBase:(GDataEntryBase *)_entry withAssetURLString:(NSString *)_assetURLString
{
    self = [super init];
    if(self)
    {
        self.entry = _entry;
        self.assetURLString = _assetURLString;
    }
    
    return self;
}

- (void)dealloc
{
    self.entry = nil;
    self.assetURLString = nil;
    [super dealloc];
}
@end

#pragma mark GoogleAPIManager class
@interface GoogleAPIManager (private)
// Tickets
- (GDataServiceTicket *)uploadTicket;
- (void)setUploadTicket:(GDataServiceTicket *)ticket;
- (void)cancelUploadTicket;
- (GDataServiceTicket *)entriesFetchTicket;
- (void)setEntriesFetchTicket:(GDataServiceTicket *)ticket;
- (void)cancelFetchTicket;
- (void)fetchAllEntries;
// Services
- (GDataServiceGoogleYouTube *)youTubeService;
- (GDataServiceGooglePhotos *)picasaService;
// internal methods
- (void)mediaDidRemove:(NSNotification *)notification;
@end

NSString *const GoogleAPIManagerDefaultEntryDidFinished = @"GoogleAPIManagerDefaultEntryDidFinished";

@implementation GoogleAPIManager
@synthesize authenticationController;
@synthesize uploadedDictionary;
@synthesize username;
@synthesize password;

static GoogleAPIManager *sharedGoogleAPIManager = nil;

- (id)init
{
    self = [super init];
    if(self)
    {
        GTMHTTPUploadFetcher *fetcher = [[GTMHTTPUploadFetcher alloc] init];
        [fetcher release];
        
        // First, we'll try to get the saved Google authentication, if any, from
        // the keychain
        self.username = nil;
        self.password = nil;
        
        NSString *documentsDirectory = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask, YES) objectAtIndex:0];
        self.uploadedDictionary = [NSMutableDictionary dictionaryWithContentsOfFile:[documentsDirectory stringByAppendingPathComponent:kDefaultUploadedXMLFile]];
        if (uploadedDictionary == nil)
        {
            self.uploadedDictionary = [NSMutableDictionary dictionary];
            [uploadedDictionary writeToFile:[documentsDirectory stringByAppendingPathComponent:kDefaultUploadedXMLFile] atomically:YES];
        }
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(mediaDidRemove:) name:ARDroneMediaManagerDidRemove object:nil];
    }
    
    return self;
}

+ (GoogleAPIManager*)sharedInstance
{
    @synchronized(self)
    {
        if (sharedGoogleAPIManager == nil) 
        {
            sharedGoogleAPIManager = [[super allocWithZone:NULL] init];
        }
    }
    
    return sharedGoogleAPIManager;
}

+ (id)allocWithZone:(NSZone *)zone
{
    return [[self sharedInstance] retain];
}

- (id)copyWithZone:(NSZone *)zone
{
    return self;
}

- (id)retain
{
    return self;
}

- (NSUInteger)retainCount
{
    return NSUIntegerMax;  //denotes an object that cannot be released
}

- (oneway void)release
{
    //do nothing
}

- (id)autorelease
{
    return self;
}

#pragma mark Google Authentication
- (void)mediaDidRemove:(NSNotification *)notification
{
    NSString *documentsDirectory = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask, YES) objectAtIndex:0];
    if([uploadedDictionary objectForKey:[notification object]] != nil)
    {
        [uploadedDictionary removeObjectForKey:[notification object]];
        [uploadedDictionary writeToFile:[documentsDirectory stringByAppendingPathComponent:kDefaultUploadedXMLFile] atomically:YES];
    }
}

- (NSString *)signedInUsername
{
    return username;
}

- (BOOL)isSignedIn
{
    return ((username != nil) && (password != nil));
}

- (void)signOut
{
    [self cancelAllActions];
    
    self.username = nil;
    self.password = nil;
    
    [[self picasaService] setUserCredentialsWithUsername:username password:password];
    [[self youTubeService] setUserCredentialsWithUsername:username password:password];
}

// SignIn
- (void)ticket:(GDataServiceTicket *)ticket authenticatedWithError:(NSError *)error 
{
    if (error != nil)
    {
        self.username = nil;
        self.password = nil;
    }
    
    if ([(NSObject *)authenticationController respondsToSelector:@selector(googleAPIManagerDidFinishSignedIn:error:)])
    {
        [authenticationController googleAPIManagerDidFinishSignedIn:self error:error];
    }
    
    self.authenticationController = nil;
    [self setEntriesFetchTicket:nil];
}

- (void)signIn:(id <GoogleAPIManagerDelegate>)controller username:(NSString *)_username password:(NSString *)_password
{
    [self signOut];

    self.username = _username;
    self.password = _password;
    
    GDataServiceGooglePhotos *service = [self picasaService];
    self.authenticationController = controller;
    GDataServiceTicket *ticket = [service authenticateWithDelegate:self didAuthenticateSelector:@selector(ticket:authenticatedWithError:)];
    [self setEntriesFetchTicket:ticket];
} 

#pragma mark GoogleAPIManager Services
- (GDataServiceGoogleYouTube *)youTubeService 
{
    static GDataServiceGoogleYouTube* service = nil;
    
    if(!service)
    {
        service = [[GDataServiceGoogleYouTube alloc] init];
        
        [service setShouldCacheResponseData:YES];
        [service setServiceShouldFollowNextLinks:YES];
        [service setIsServiceRetryEnabled:YES];
    }
    
    // update the username/password each time the service is requested
    [service setYouTubeDeveloperKey:kDefaultDeveloperKey];
    if ([username length] && [password length]) 
    {
        [service setUserCredentialsWithUsername:username
                                       password:password];
    } 
    else 
    {
        [service setUserCredentialsWithUsername:nil
                                       password:nil];
    }
    
    return service;
}

- (GDataServiceGooglePhotos *)picasaService
{
    static GDataServiceGooglePhotos* service = nil;
    
    if (!service) 
    {
        service = [[GDataServiceGooglePhotos alloc] init];
        
        [service setShouldCacheResponseData:YES];
        [service setServiceShouldFollowNextLinks:YES];
    }
    
    // update the username/password each time the service is requested
    if ([username length] && [password length]) 
    {
        [service setUserCredentialsWithUsername:username
                                       password:password];
    } 
    else 
    {
        [service setUserCredentialsWithUsername:nil
                                       password:nil];
    }
    
    return service;
}

- (void)notifyDefaultEntry:(NSString *)assetURLString assetType:(NSString *)assetType data:(NSData *)data droneVersion:(NSInteger)droneVersion
{
    GoogleAPIManagerEntry *entry = [[GoogleAPIManagerEntry alloc] initWithDataEntryBase:nil withAssetURLString:assetURLString];
    NSString *filename = [[[ARDroneMediaManager sharedInstance] mediaDictionary] valueForKey:assetURLString];
    NSRange year = {0, 4}, month = {4, 2}, day = {6, 2};    
    if(assetType == ALAssetTypeVideo)
    {
        NSString *keywords_string = nil;
        switch(droneVersion)
        {
            case 1:
                keywords_string = @"ardroneacademy, Parrot, ardrone, quadricopter, video, flying camera, AR.Drone Academy, AR.FreeFlight 2.0, AR.FreeFlight, arfreeflight, AR.Drone, Wi-Fi, iPhone, iPad, Android, quadrotor, rotor, aerial photo, ardrone-1.0-VIDEO";
                break;
                
            case 2:
            default:
                keywords_string = @"ardroneacademy, Parrot, AR.Drone 2.0, ARDrone 2, ardrone2, ardrone, quadricopter, HD, video, HDvideo, 720p, ardrone-2.0-HD720P, flying camera, AR.Drone Academy, AR.FreeFlight 2.0, AR.FreeFlight, arfreeflight, AR.Drone, Wi-Fi, iPhone, iPad, Android, quadrotor, rotor, aerial photo, water resistant, magnetometer";
                break;
        }
        
        NSArray *components = [[filename lastPathComponent] componentsSeparatedByString:@"_"];
        NSString *mediaDate = [NSString stringWithFormat:@"%@/%@/%@", [(NSString *)[components objectAtIndex:1] substringWithRange:year], [(NSString *)[components objectAtIndex:1] substringWithRange:month], [(NSString *)[components objectAtIndex:1] substringWithRange:day]];  
        
        // gather all the metadata needed for the mediaGroup
        GDataMediaTitle *title = [GDataMediaTitle textConstructWithString:
                                  [NSString stringWithFormat:LOCALIZED_STRING(@"AR.Drone %d.%d Video: %@"), droneVersion, 0, mediaDate]];
        
        GDataMediaCategory *category = [GDataMediaCategory mediaCategoryWithString:kDefaultCategory];
        [category setScheme:kGDataSchemeYouTubeCategory];
        
        GDataMediaDescription *desc = [GDataMediaDescription textConstructWithString:LOCALIZED_STRING(@"Video recorded with a Parrot AR.Drone!\n\nOfficial Website: http://www.ardrone.com\nFollow AR.Drone on: http://www.twitter.com/ardrone\nBecome a Fan on: http://www.facebook.com/parrot")];
        
        GDataMediaKeywords *keywords = [GDataMediaKeywords keywordsWithString:keywords_string];
        
        GDataYouTubeMediaGroup *mediaGroup = [GDataYouTubeMediaGroup mediaGroup];
        [mediaGroup setMediaTitle:title];
        [mediaGroup setMediaDescription:desc];
        [mediaGroup setMediaCategories:[NSArray arrayWithObject:category]];
        [mediaGroup setMediaKeywords:keywords];
        [mediaGroup setIsPrivate:NO];
        
        // create the upload entry with the mediaGroup and the file
        GDataEntryYouTubeUpload *newEntry = [GDataEntryYouTubeUpload uploadEntryWithMediaGroup:mediaGroup data:(NSData *)data MIMEType:@"video/quicktime" slug:[filename lastPathComponent]];    
        
        [newEntry setTitle:title];
        
        [entry setEntry:(GDataEntryBase *)newEntry];
    }
    else if(assetType == ALAssetTypePhoto)
    {
        NSString *keywords_string = nil;
        switch(droneVersion)
        {
            case 1:
                keywords_string = @"ardroneacademy, Parrot, ardrone, quadricopter, photo, JPEG, flying camera, AR.Drone Academy, AR.FreeFlight 2.0, AR.FreeFlight, arfreeflight, AR.Drone, Wi-Fi, iPhone, iPad, Android, quadrotor, rotor, aerial photo, ardrone-JPEGPHOTO";
                break;
                
            case 2:
            default:
                keywords_string = @"ardroneacademy, Parrot, AR.Drone 2.0, ARDrone 2, ardrone2, ardrone, quadricopter, photo, JPEG, ardrone-2.0-JPEGPHOTO, flying camera, AR.Drone Academy, AR.FreeFlight 2.0, AR.FreeFlight, arfreeflight, AR.Drone, Wi-Fi, iPhone, iPad, Android, quadrotor, rotor, aerial photo, water resistant, magnetometer";
                break;
        }

        // make a new entry for the photo
        GDataEntryPhoto *newEntry = [GDataEntryPhoto photoEntry];
        
        NSArray *components = [[filename lastPathComponent] componentsSeparatedByString:@"_"];
        NSString *mediaDate = [NSString stringWithFormat:@"%@/%@/%@", [(NSString *)[components objectAtIndex:1] substringWithRange:year], [(NSString *)[components objectAtIndex:1] substringWithRange:month], [(NSString *)[components objectAtIndex:1] substringWithRange:day]];  
        GDataMediaTitle *title = [GDataMediaTitle textConstructWithString:[NSString stringWithFormat:LOCALIZED_STRING(@"AR.Drone %d.%d Photo: %@"), droneVersion, 0, mediaDate]];
        
        // gather all the metadata needed for the mediaGroup
        GDataMediaKeywords *keywords = [GDataMediaKeywords keywordsWithString:keywords_string];
        
        GDataMediaDescription *desc = [GDataMediaDescription textConstructWithString:LOCALIZED_STRING(@"Picture taken with a Parrot AR.Drone!\n\nOfficial Website: http://www.ardrone.com\nFollow AR.Drone on: http://www.twitter.com/ardrone\nBecome a Fan on: http://www.facebook.com/parrot")];
        
        [newEntry setTitle:title];
        [newEntry setPhotoDescription:desc];
        
        GDataMediaGroup *mediaGroup = [GDataMediaGroup mediaGroup];
        [mediaGroup setMediaTitle:title];
        [mediaGroup setMediaDescription:desc];
        [mediaGroup setMediaKeywords:keywords];
        
        [newEntry setMediaGroup:mediaGroup];
        
        [newEntry setPhotoMIMEType:@"image/jpeg"];

        // attach the NSData and set the MIME type for the photo
        [newEntry setPhotoData:(NSData *)data];
        
        // the slug is just the upload file's filename
        [newEntry setUploadSlug:[filename lastPathComponent]];
        
        [entry setEntry:(GDataEntryBase *)newEntry];
    }    
    
    [[NSNotificationCenter defaultCenter] postNotificationName:GoogleAPIManagerDefaultEntryDidFinished object:entry];
    
    [entry release];
}

- (void)getDefaultEntry:(NSString *)assetURLString
{
    ALAssetsLibrary *library = [[ALAssetsLibrary alloc] init];
    [library assetForURL:[NSURL URLWithString:assetURLString] resultBlock:^(ALAsset *asset) 
    {
        if(asset != nil)
        {
            // Get data of asset
            NSMutableData *data = [[NSMutableData alloc] init];
            NSArray *utis =  (NSArray*)[asset valueForProperty:ALAssetPropertyRepresentations];
            ALAssetRepresentation *representation = [asset representationForUTI:[utis objectAtIndex:0]];
            uint8_t *buffer = malloc(sizeof(uint8_t) * GOOGLEAPIMANAGER_BUFFER_SIZE);
            NSUInteger length = 0;
            while((length = [representation getBytes:buffer fromOffset:[data length] length:GOOGLEAPIMANAGER_BUFFER_SIZE error:nil]) != 0)
            {
                [data appendBytes:buffer length:length];
            }
            free(buffer);

           [self notifyDefaultEntry:assetURLString assetType:(NSString *)[asset valueForProperty:ALAssetPropertyType] data:data droneVersion:[[ARDroneMediaManager sharedInstance] mediaManagerGetDroneVersion:asset]];
            [data release];
        }
    } 
    failureBlock:^(NSError *error) 
    {
        NSLog(@"Failure : %@", error);
    }];
    [library release];
}

- (void)getYouTubeCategories:(id <GoogleAPIManagerDelegate>)controller
{
    NSURL *categoriesURL = [NSURL URLWithString:kGDataSchemeYouTubeCategory];
    
    GTMHTTPFetcher *fetcher = [GTMHTTPFetcher fetcherWithURL:categoriesURL];
    [fetcher setComment:@"YouTube categories"];
    [fetcher beginFetchWithCompletionHandler:^(NSData *data, NSError *error) 
     {
         NSMutableDictionary *categories = nil;
         
         if(error == nil)
         {
             // The categories document looks like
             //  <app:categories>
             //    <atom:category term='Film' label='Film &amp; Animation'>
             //      <yt:browsable />
             //      <yt:assignable />
             //    </atom:category>
             //  </app:categories>
             //
             // We only want the categories which are assignable. We'll use XPath to
             // select those, then get the string value of the resulting term attribute
             // nodes.
             NSString *const path = @"app:categories/atom:category[yt:assignable]";
             NSXMLDocument *xmlDoc = [[[NSXMLDocument alloc] initWithData:data
                                                                  options:0
                                                                    error:&error] autorelease];
             if (xmlDoc == nil) 
             {
                 NSLog(@"category fetch could not parse XML: %@", error);
             } 
             else 
             {
                 NSArray *nodes = [xmlDoc nodesForXPath:path
                                                  error:&error];
                 unsigned int numberOfNodes = [nodes count];
                 if (numberOfNodes == 0) 
                 {
                     NSLog(@"category fetch could not find nodes: %@", error);
                 } 
                 else 
                 {
                     // Add categorie for
                     // add the category labels as menu items, and the category terms as
                     // the menu item representedObjects.
                     categories = [[NSMutableDictionary alloc] initWithCapacity:numberOfNodes];
                     
                     for (int idx = 0; idx < numberOfNodes; idx++) 
                     {
                         NSXMLElement *category = [nodes objectAtIndex:idx];
                         
                         NSString *term = [[category attributeForName:@"term"] stringValue];
                         NSString *label = [[category attributeForName:@"label"] stringValue];
                         
                         if (label == nil) 
                             label = term;
                         
                         [categories setObject:label forKey:term];
                     }
                 }
             }
         }
         
         if([(NSObject *)controller respondsToSelector:@selector(googleAPIManagerGetCategoriesDidFinish:categories:error:)])
         {
             [controller googleAPIManagerGetCategoriesDidFinish:self categories:categories error:error];
         }
         
         [categories release];
     }];
}

- (void)uploadVideo:(id <GoogleAPIManagerDelegate>)controller entry:(GoogleAPIManagerEntry *)entry
{
    [self cancelUploadTicket];
    
    NSString *documentsDirectory = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask, YES) objectAtIndex:0];

    GDataServiceGoogleYouTube *service = [self youTubeService];
        
    [service setServiceUploadProgressHandler:^(GDataServiceTicketBase *_ticket, unsigned long long numberOfBytesRead, unsigned long long dataLength) 
    {        
        if([(NSObject *)controller respondsToSelector:@selector(googleAPIManagerUploadDidProgress:percentValue:)])
        {
            [controller googleAPIManagerUploadDidProgress:self percentValue:numberOfBytesRead / (float)dataLength];
        }
    }];

    GDataServiceTicket *ticket = [service fetchEntryByInsertingEntry:[entry entry] forFeedURL:[GDataServiceGoogleYouTube youTubeUploadURLForUserID:kGDataServiceDefaultUser] completionHandler:^(GDataServiceTicket *_ticket, GDataEntryBase *_entry, NSError *error) 
          {
              if([(NSObject *)controller respondsToSelector:@selector(googleAPIManagerVideoUploadDidFinish:entry:error:)])
              {
                  [controller googleAPIManagerVideoUploadDidFinish:self entry:_entry error:error];
              }
              
              if(error == nil)
              {
                  // Write to uploaded file
                  [self.uploadedDictionary setObject:[[[_entry HTMLLink] URL] absoluteString] forKey:[entry assetURLString]];
                  [(NSDictionary *)self.uploadedDictionary writeToFile:[documentsDirectory stringByAppendingPathComponent:kDefaultUploadedXMLFile] atomically:YES];
              }
              
              [self setUploadTicket:nil];
          }];

    // NSLog(@"upload ticket %@", ticket);
    [self setUploadTicket:ticket];
}

#pragma mark GoogleAPIManager Photos
- (void)getPhotoAlbums:(id <GoogleAPIManagerDelegate>)controller
{
    [self cancelFetchTicket];
    
    GDataServiceGooglePhotos *service = [self picasaService];
    
    NSURL *feedURL = [GDataServiceGooglePhotos photoFeedURLForUserID:kGDataServiceDefaultUser
                                                             albumID:nil
                                                           albumName:nil
                                                             photoID:nil
                                                                kind:nil
                                                              access:nil];
    GDataServiceTicket *ticket = [service fetchFeedWithURL:feedURL
              completionHandler:^(GDataServiceTicket *ticket, GDataFeedBase *feed, NSError *error)
        {
            if([(NSObject *)controller respondsToSelector:@selector(googleAPIManagerGetAlbumsDidFinish:albums:error:)])
            {
                [controller googleAPIManagerGetAlbumsDidFinish:self albums:[feed entries] error:error];
            }
            
            [self setEntriesFetchTicket:nil];                         
        }];

    [self setEntriesFetchTicket:ticket];
}

- (void)createAlbum:(id <GoogleAPIManagerDelegate>)controller title:(NSString *)title private:(BOOL)bPrivate
{
    [self cancelFetchTicket];
    [self cancelUploadTicket];
    
    GDataServiceGooglePhotos *service = [self picasaService];
    
    NSURL *feedURL = [GDataServiceGooglePhotos photoFeedURLForUserID:kGDataServiceDefaultUser
                                                             albumID:nil
                                                           albumName:nil
                                                             photoID:nil
                                                                kind:nil
                                                              access:nil];
    GDataServiceTicket *ticket = [service fetchFeedWithURL:feedURL
         completionHandler:^(GDataServiceTicket *_ticket, GDataFeedBase *feed, NSError *error)
          {
              if(error == nil)
              {
                  NSString *description = [NSString stringWithFormat:@"%@", LOCALIZED_STRING(@"Photos taken with an AR.Drone 2.0. More info on http://www.ardrone2.com.")];
                  NSString *access = (bPrivate ? kGDataPhotoAccessPrivate : kGDataPhotoAccessPublic);
                  
                  GDataEntryPhotoAlbum *newAlbum = [GDataEntryPhotoAlbum albumEntry];
                  [newAlbum setTitleWithString:title];
                  [newAlbum setPhotoDescriptionWithString:description];
                  [newAlbum setAccess:access];
                  
                  NSURL *postLink = [[(GDataFeedPhotoUser *)feed postLink] URL];

                  GDataServiceTicket *ticket2 = [service fetchEntryByInsertingEntry:newAlbum forFeedURL:postLink completionHandler:^(GDataServiceTicket *_ticket2, GDataEntryBase *entry, NSError *error) 
                   {
                       if([(NSObject *)controller respondsToSelector:@selector(googleAPIManagerCreateAlbumDidFinish:error:)])
                       {
                           [controller googleAPIManagerCreateAlbumDidFinish:self error:error];
                       }
                       
                       [self setUploadTicket:nil];
                   }];
                  
                  [self setUploadTicket:ticket2];
              }
              else
              {
                  if([(NSObject *)controller respondsToSelector:@selector(googleAPIManagerCreateAlbumDidFinish:error:)])
                  {
                      [controller googleAPIManagerCreateAlbumDidFinish:self error:error];
                  }
              }
              
              [self setEntriesFetchTicket:nil];
          }];
    
        [self setEntriesFetchTicket:ticket];
}

- (void)uploadPhoto:(id <GoogleAPIManagerDelegate>)controller album:(GDataEntryPhotoAlbum *)album entry:(GoogleAPIManagerEntry *)entry
{
    [self cancelUploadTicket];
    [self cancelFetchTicket];
    
    NSString *documentsDirectory = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask, YES) objectAtIndex:0];
    
    GDataServiceGooglePhotos *service = [self picasaService];
    
    [service setServiceUploadProgressHandler:^(GDataServiceTicketBase *_ticket, unsigned long long numberOfBytesRead, unsigned long long dataLength) 
    {
        if([(NSObject *)controller respondsToSelector:@selector(googleAPIManagerUploadDidProgress:percentValue:)])
        {
            [controller googleAPIManagerUploadDidProgress:self percentValue:numberOfBytesRead / (float)dataLength];
        }
    }];
    

    NSURL *feedURL = [[album feedLink] URL];
    GDataServiceTicket *ticket = [service fetchFeedWithURL:feedURL completionHandler:^(GDataServiceTicket *_ticket, GDataFeedBase *feed, NSError *error) 
    {
        if(error == nil)
        {
            NSURL *uploadURL = [[feed uploadLink] URL];
            GDataServiceTicket *ticket2 = [service fetchEntryByInsertingEntry:[entry entry] forFeedURL:uploadURL 
                   completionHandler:^(GDataServiceTicket *_ticket2, GDataEntryBase *_entry, NSError *error) 
                  {
                      if(error == nil)
                      {
                          // Write to uploaded file
                          [self.uploadedDictionary setObject:[[[_entry HTMLLink] URL] absoluteString] forKey:[entry assetURLString]];
                          [(NSDictionary *)self.uploadedDictionary writeToFile:[documentsDirectory stringByAppendingPathComponent:kDefaultUploadedXMLFile] atomically:YES];
                      }

                      if([(NSObject *)controller respondsToSelector:@selector(googleAPIManagerPhotoUploadDidFinish:entry:error:)])
                      {
                          [controller googleAPIManagerPhotoUploadDidFinish:self entry:(GDataEntryPhoto *)_entry error:error];
                      }
                      
                      [self setUploadTicket:nil];
                  }];
            
            // NSLog(@"upload ticket %@", ticket);
            [self setUploadTicket:ticket2];
        }
        else
        {
            if([(NSObject *)controller respondsToSelector:@selector(googleAPIManagerPhotoUploadDidFinish:entry:error:)])
            {
                [controller googleAPIManagerPhotoUploadDidFinish:self entry:nil error:error];
            }
        }
        [self setEntriesFetchTicket:nil];
    }];
    
    [self setEntriesFetchTicket:ticket];
}        

#pragma mark Tickets
- (void)cancelUploadTicket
{
    if (mUploadTicket != nil)
    {
        [mUploadTicket cancelTicket];
        [self setUploadTicket:nil];
    }
}

- (void)cancelFetchTicket
{
    if (mEntriesFetchTicket != nil)
    {
        [mEntriesFetchTicket cancelTicket];
        [self setEntriesFetchTicket:nil];
    }
}

- (void)cancelAllActions
{
    [self cancelFetchTicket];
    [self cancelUploadTicket];
}

- (GDataServiceTicket *)uploadTicket 
{
    return mUploadTicket;
}

- (void)setUploadTicket:(GDataServiceTicket *)ticket 
{
    [mUploadTicket autorelease];
    mUploadTicket = [ticket retain];
}

- (GDataServiceTicket *)entriesFetchTicket 
{
    return mEntriesFetchTicket;
}

- (void)setEntriesFetchTicket:(GDataServiceTicket *)ticket 
{
    [mEntriesFetchTicket autorelease];
    mEntriesFetchTicket = [ticket retain];
}

@end
