//
//  ARDroneMediaManager.m
//  FreeFlight
//
//  Created by Frédéric D'Haeyer on 2/10/12.
//  Copyright (c) 2012 Parrot SA. All rights reserved.
//
#import <UIKit/UIKit.h>
#import <utils/ardrone_video_atoms.h>
#import "ARDroneMediaManager.h"
#include "ConstantsAndMacros.h"

#define ARDRONE_MEDIAMANAGER_PROCESSING_XML_FILE    @"processing.plist"
#define ARDRONE_MEDIAMANAGER_XML_FILE               @"media.plist"
#define ARDRONE_MEDIAMANAGER_TIFFMAKER              @"Parrot AR.Drone"

static NSThread *mediaManagerThread = nil;
static bool_t mediaManagerInitialized = FALSE;

// Observers
NSString *const ARDroneMediaManagerIsReady = @"ARDroneMediaManagerIsReady";
NSString *const ARDroneMediaManagerDidRefresh = @"ARDroneMediaManagerDidRefresh";
NSString *const ARDroneMediaManagerDidRemove = @"ARDroneMediaManagerDidRemove";

@interface ARDroneMediaManager (private)
- (void)mediaManagerThreadFunction;
- (void)transferToCameraRoll:(ARDroneMediaManagerRetrievingBlock)_retrievingBlock;
- (void)removeMediaPath:(NSString *)mediaPath;
@end

/*************************************/
/* ALAssetRepresentation (private)   */
/*************************************/
static ARDroneMediaManager *singleton = nil;

@interface ALAssetRepresentation (private)
- (BOOL) getNextAtom:(movie_atom_t *)atom fromOffset:(long long *)offset;
- (NSString *) ardtAtomExist;
@end

@implementation ALAssetRepresentation (private)
- (BOOL) getNextAtom:(movie_atom_t *)atom fromOffset:(long long *)offset
{
    BOOL result = NO;
    long long current_offset = *offset;
    if([self getBytes:(uint8_t *)&atom->size fromOffset:current_offset length:sizeof(uint32_t) error:nil] != 0)
    {
        atom->size = ntohl(atom->size);
        current_offset += sizeof(uint32_t);
        if([self getBytes:(uint8_t *)&atom->tag[0] fromOffset:current_offset length:sizeof(uint32_t) error:nil] != 0)
        {
            current_offset += sizeof(uint32_t);
            *offset = current_offset;
            result = YES;
        }
        // NO ELSE because if error, we continue the parsing
    }
    // NO ELSE because if error, we continue the parsing
    
    return result;
}

- (NSString *)ardtAtomExist
{
    BOOL result = NO;
    NSString *retval = nil;
    movie_atom_t atom = { 0 };
    long long atomOffset = 0;
    
    do
    {
        result = [self getNextAtom:&atom fromOffset:&atomOffset];
        atomOffset += (atom.size - 8);
    }
    while (result && 
           ('a' != atom.tag [0] ||
            'r' != atom.tag [1] ||
            'd' != atom.tag [2] ||
            't' != atom.tag [3] ) );
    
    // If result == YES, we found atom "ardt"
    if(result)
    {
        atomOffset -= (atom.size - 8);
        atom.data = (uint8_t *)vp_os_malloc(sizeof(uint8_t) * ((atom.size - 8) + 1));
        vp_os_memset(atom.data, 0, sizeof(uint8_t) * ((atom.size - 8) + 1)); // +1 for '\0'
        if((atom.size - 8) > 0)
        {
        [self getBytes:atom.data fromOffset:atomOffset length:(atom.size - 8) error:nil];
        retval = [NSString stringWithUTF8String:(const char *)atom.data + 4];
        }
        vp_os_free(atom.data);
    }
    // NO ELSE - we didn't find atom 'ardt' atom, nothing to do.
    
    return retval;
}
@end

@implementation ARDroneMediaManager
@synthesize documentsPath;
@synthesize processingDictionary;
@synthesize mediaDictionary;
@synthesize mediaManagerReady;
@synthesize mediaToTransferIsReady;
@synthesize cancelRefresh;

// Making a thread-safe singleton creation
+ (ARDroneMediaManager *)sharedInstance 
{        
    if (nil != singleton) 
        return singleton;
    // Lock
    static dispatch_once_t pred;
    // This code is executed at most once
    dispatch_once(&pred, ^{ 
        singleton = [[super allocWithZone:NULL] init]; 
    });
    return singleton;
}

- (id)init
{
    self = [super init];
    if (self) 
    {
        self.documentsPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
        mediaToTransferCount = 0;
        mediaManagerReady = NO;
        mediaToTransferIsReady = YES;
        mediaToTransfer = [[NSMutableArray alloc] init];
        self.mediaDictionary = [NSMutableDictionary dictionary];
    }    
    return self;
}

- (void)dealloc
{
    // Never called but here for clarity
    [super dealloc];
}

- (void)mediaManagerInit
{
	if(!mediaManagerInitialized)
	{
        mediaManagerInitialized = TRUE;
        mediaManagerReady = NO;
        mediaToTransferIsReady = YES;
        // Start retrieve thread
        mediaManagerThread = [[NSThread alloc] initWithTarget:self selector:@selector(mediaManagerThreadFunction) object:nil];
        [mediaManagerThread start];
    }
    // NO ELSE - Media Manager Thread is stopping- nothing to do
}

- (void)mediaManagerShutdown
{
	if(mediaManagerInitialized)
	{
        [mediaManagerThread cancel];
        [self setCancelRefresh:YES];
    }
    // NO ELSE - Media Manager Thread is stopping- nothing to do
}

- (void)retrieveAssetsWithGroup:(ALAssetsGroup *)group
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

    // RETRIEVING ALL ASSETS IN CAMERA ROLL
    void (^assetEnumerator)(ALAsset *, NSUInteger, BOOL *) = ^(ALAsset *asset, NSUInteger index, BOOL *stop) 
    {
        NSAutoreleasePool *_pool = [[NSAutoreleasePool alloc] init];
        if(asset != nil) 
        {
            NSString *retval = nil;
            NSArray *utis =  (NSArray*)[asset valueForProperty:ALAssetPropertyRepresentations];
            ALAssetRepresentation *representation = [asset representationForUTI:[utis objectAtIndex:0]];
            if([asset valueForProperty:ALAssetPropertyType] == ALAssetTypeVideo)
            {
                NSString *ardtValue = [representation ardtAtomExist];
                if(ardtValue != nil)
                {
                    if([mediaDictionary valueForKey:[[representation url] absoluteString]] == nil)
                    {
                        NSArray *components = [ardtValue componentsSeparatedByString:@"|"];
                        if([components count] == 2)
                        {
                            retval = [[representation url] absoluteString];
                            [mediaDictionary setValue:[[ardtValue componentsSeparatedByString:@"|"] objectAtIndex:1] forKey:retval];
                            [[NSNotificationCenter defaultCenter] postNotificationName:ARDroneMediaManagerDidRefresh object:retval];
                        }
                        // NO ELSE - Ignoring this video - ardt value format not recognized
                    }
                    // NO ELSE - Media already exists
                }
                // NO ELSE - Ignoring this video - ardt value format not recognized
            }
            else if([asset valueForProperty:ALAssetPropertyType] == ALAssetTypePhoto)
            {
                NSDictionary *metadata = [representation metadata];
                //NSLog(@"metadata : %@", metadata);
                if(metadata != nil)
                {
                    NSDictionary *tiffDictionary = [metadata valueForKey:(NSString *)kCGImagePropertyTIFFDictionary];
                    if(tiffDictionary != nil)
                    {
                        NSString *tiffMaker = [tiffDictionary valueForKey:(NSString *)kCGImagePropertyTIFFMake];
                        if((tiffMaker != nil) && ([tiffMaker compare:ARDRONE_MEDIAMANAGER_TIFFMAKER] == NSOrderedSame))
                        {
                            if([mediaDictionary valueForKey:[[representation url] absoluteString]] == nil)
                            {
                                NSString *tiffDescription = [tiffDictionary valueForKey:(NSString *)kCGImagePropertyTIFFImageDescription];
                                retval = [[representation url] absoluteString];
                                [mediaDictionary setValue:tiffDescription forKey:retval];
                                [[NSNotificationCenter defaultCenter] postNotificationName:ARDroneMediaManagerDidRefresh object:retval];
                            }
                        }
                    }
                }
            }
            // NO ELSE, ALAssetPropertyType == ALAssetTypeUnknown => We don't process this type
        }
        else
        {
            NSLog(@"write to %@", [documentsPath stringByAppendingPathComponent:ARDRONE_MEDIAMANAGER_XML_FILE]);
            [[[mediaDictionary copy] autorelease] writeToFile:[documentsPath stringByAppendingPathComponent:ARDRONE_MEDIAMANAGER_XML_FILE] atomically:YES];
        }
        
        *stop = cancelRefresh;
        [_pool release];
    };
    
    

    [group enumerateAssetsUsingBlock:assetEnumerator];
    
    [pool release];
}

- (void)mediaManagerThreadFunction
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    
    // REMOVE ALL PROCESSING MEDIA
    self.processingDictionary = [NSMutableDictionary dictionaryWithContentsOfFile:[documentsPath stringByAppendingPathComponent:ARDRONE_MEDIAMANAGER_PROCESSING_XML_FILE]];
    
    if(processingDictionary == nil)
    {
        self.processingDictionary = [NSMutableDictionary dictionary];
        [processingDictionary writeToFile:[documentsPath stringByAppendingPathComponent:ARDRONE_MEDIAMANAGER_PROCESSING_XML_FILE] atomically:YES];
    }
    else
    {
        NSDictionary *localProcessingDictionary = [processingDictionary copy];
        NSEnumerator *keyEnumerator = [localProcessingDictionary keyEnumerator];
        NSString *mediaPath = nil;
        // Remove media if exporting to camera roll was cancelled
        while(((mediaPath = [keyEnumerator nextObject]) != nil) && ![mediaManagerThread isCancelled])
        {
            [self removeMediaPath:mediaPath];
            [self.processingDictionary removeObjectForKey:mediaPath];
        }
        [localProcessingDictionary release];
        // Save in plist dictionary
        [(NSDictionary *)self.processingDictionary writeToFile:[documentsPath stringByAppendingPathComponent:ARDRONE_MEDIAMANAGER_PROCESSING_XML_FILE] atomically:YES];
    }
    
    // GETTING ALL ASSETS ALREADY EXIST
    NSMutableDictionary *tmpMediaDictionary = [NSMutableDictionary dictionaryWithContentsOfFile:[documentsPath stringByAppendingPathComponent:ARDRONE_MEDIAMANAGER_XML_FILE]];
    
    if(tmpMediaDictionary == nil)
    {
        [[[mediaDictionary copy] autorelease] writeToFile:[documentsPath stringByAppendingPathComponent:ARDRONE_MEDIAMANAGER_XML_FILE] atomically:YES];
    }
    else
    {
        // Sort array to give all sorting media
        NSArray *keyArray = [tmpMediaDictionary keysSortedByValueUsingComparator:^NSComparisonResult(id obj1, id obj2) 
        {
            return [(NSString *)obj1 compare:(NSString *)obj2];
        }];

        for(NSString *assetAbsoluteURLString in keyArray)
        {
            if([mediaManagerThread isCancelled])
                break;

            void (^resultBlock)(ALAsset *) = ^(ALAsset *asset) 
            {
                if(![mediaManagerThread isCancelled])
                {
                    if(asset != nil)
                    {
                        [mediaDictionary setValue:[tmpMediaDictionary valueForKey:assetAbsoluteURLString] forKey:assetAbsoluteURLString];
                        [[NSNotificationCenter defaultCenter] postNotificationName:ARDroneMediaManagerDidRefresh object:assetAbsoluteURLString];
                        [[[mediaDictionary copy] autorelease] writeToFile:[documentsPath stringByAppendingPathComponent:ARDRONE_MEDIAMANAGER_XML_FILE] atomically:YES];
                    }
                    else
                    {
                        [[NSNotificationCenter defaultCenter] postNotificationName:ARDroneMediaManagerDidRemove object:assetAbsoluteURLString];
                    }
                }
            };
            
            void (^failureBlock)(NSError *) = ^(NSError *error) 
            {
                NSLog(@"Failure : %@", error);
            };
            
            ALAssetsLibrary *library = [[ALAssetsLibrary alloc] init];
            // Because we can't remove the object with lastAssetLoaded value
            [library assetForURL:[NSURL URLWithString:assetAbsoluteURLString] resultBlock:resultBlock failureBlock:failureBlock];
            [library release];
        }
    }
    
    // SEARCH IN DOCUMENTS PATH IF MEDIA NEED TO TRANSFER
    if(![mediaManagerThread isCancelled])
    {
        void (^retrievingBlock)(float, NSString *) = ^(float percent, NSString *assetURLString) 
        {
            if([mediaManagerThread isCancelled])
                return;
            
            if(assetURLString != nil)
            {
                [[NSNotificationCenter defaultCenter] postNotificationName:ARDroneMediaManagerDidRefresh object:assetURLString];
            }
            
            if(percent == 1.0)
            {
                mediaManagerReady = YES;
                [[NSNotificationCenter defaultCenter] postNotificationName:ARDroneMediaManagerIsReady object:nil];
            }
        };
        
        [self transferToCameraRoll:retrievingBlock];
    }
    // NO ELSE - Media Manager Thread is stopping - nothing to do
    
    void (^assetGroupEnumerator)(ALAssetsGroup *, BOOL *) =  ^(ALAssetsGroup *group, BOOL *stop) 
    {
        NSLog(@"group : %@, %d", group, [group numberOfAssets]);
        if((group != nil) && ([(NSNumber *)[group valueForProperty:ALAssetsGroupPropertyType] intValue] == ALAssetsGroupSavedPhotos))
        {
            // Get count of assets
            NSInteger numberOfAssets = 0;
            [group setAssetsFilter:[ALAssetsFilter allVideos]];
            numberOfAssets += [group numberOfAssets];
            [group setAssetsFilter:[ALAssetsFilter allPhotos]];
            numberOfAssets += [group numberOfAssets];
            [group setAssetsFilter:[ALAssetsFilter allAssets]];

            if(numberOfAssets > 0)
            {
                [self performSelectorInBackground:@selector(retrieveAssetsWithGroup:) withObject:group];
            }
        }
    };
    
    void (^failureBlock)(NSError *) = ^(NSError *error)
    {
        NSLog(@"Failure : %@", error);
    };
    
    cancelRefresh = NO;
    ALAssetsLibrary *library = [[ALAssetsLibrary alloc] init];
    [library enumerateGroupsWithTypes:ALAssetsGroupAll
                                usingBlock:assetGroupEnumerator
                              failureBlock:failureBlock];    
    [library release];

    [pool release];
}

- (void)removeMediaPath:(NSString *)mediaPath
{
    if([[NSFileManager defaultManager] fileExistsAtPath:mediaPath])
    {
        NSString *dirPath = [mediaPath stringByDeletingLastPathComponent];
        [[NSFileManager defaultManager] removeItemAtPath:mediaPath error:nil];
        NSDirectoryEnumerator *dirEnumerator = [[NSFileManager defaultManager] enumeratorAtPath:dirPath];
        if([[dirEnumerator allObjects] count] == 0)
        {
            [[NSFileManager defaultManager] removeItemAtPath:dirPath error:nil];
        }
    }
}

- (NSInteger)mediaManagerGetDroneVersion:(ALAsset *)asset
{
    NSInteger retval = 1;

    // get droneVersion
    if([asset valueForProperty:ALAssetPropertyType] == ALAssetTypePhoto)
    {
        NSArray *utis =  (NSArray*)[asset valueForProperty:ALAssetPropertyRepresentations];
        ALAssetRepresentation *representation = [asset representationForUTI:[utis objectAtIndex:0]];
        
        int width = [(NSNumber *)[[representation metadata] objectForKey:(NSString *)kCGImagePropertyPixelWidth] intValue];
        int height = [(NSNumber *)[[representation metadata] objectForKey:(NSString *)kCGImagePropertyPixelHeight] intValue];
        
        if((width == hdtv720P_WIDTH) && (height == hdtv720P_HEIGHT))
            retval = 2;
    }
    else if([asset valueForProperty:ALAssetPropertyType] == ALAssetTypeVideo)
    {
        NSArray *utis =  (NSArray*)[asset valueForProperty:ALAssetPropertyRepresentations];
        ALAssetRepresentation *representation = [asset representationForUTI:[utis objectAtIndex:0]];
        
        NSString *ardtValue = [representation ardtAtomExist];
        if(ardtValue != nil)
        {
            NSArray *components = [ardtValue componentsSeparatedByString:@"|"];
            if([components count] == 2)
                retval = [(NSString *)[components objectAtIndex:0] integerValue];
        }
    }
    
    return retval;
}

// Should not allocate a new instance, so return the current one
+ (id)allocWithZone:(NSZone*)zone 
{
    return [[self sharedInstance] retain];
}

// Should not generate multiple copies of the singleton
- (id)copyWithZone:(NSZone *)zone 
{
    return self;
}

// Do nothing, as no retain counter for this object
- (id)retain 
{
    return self;
}

// Replace the retain counter so we can never release this object
- (NSUInteger)retainCount 
{
    return NSUIntegerMax;
}

- (oneway void)release 
{
    // Empty, as we don't want to let the user release this object
}

// Do nothing, other than return the shared instance - as this is expected from autorelease
- (id)autorelease 
{
    return self;
}

- (void)saveMedia:(NSString *)mediaPath transferingBlock:(ARDroneMediaManagerTranferingBlock)_transferingBlock
{
    if ([mediaPath.pathExtension isEqualToString:ARDRONE_MEDIAMANAGER_MOV_EXTENSION])
    {
        [self.processingDictionary setObject:mediaPath forKey:mediaPath];        
        [(NSDictionary *)self.processingDictionary writeToFile:[documentsPath stringByAppendingPathComponent:ARDRONE_MEDIAMANAGER_PROCESSING_XML_FILE] atomically:YES];
        
        // Write to uploading file
        ALAssetsLibrary *library = [[ALAssetsLibrary alloc] init];
        [library writeVideoAtPathToSavedPhotosAlbum:[NSURL URLWithString:mediaPath]  completionBlock:^(NSURL *assetURL, NSError *error)
         {
             [self removeMediaPath:mediaPath];
             [self.processingDictionary removeObjectForKey:mediaPath];
             [(NSDictionary *)self.processingDictionary writeToFile:[documentsPath stringByAppendingPathComponent:ARDRONE_MEDIAMANAGER_PROCESSING_XML_FILE] atomically:YES];
             
             if(error != nil)
             {
                 _transferingBlock(nil);
             }
             else
             {
                 if([mediaDictionary valueForKey:[assetURL absoluteString]] == nil)
                 {
                     NSArray *pathComponents = [mediaPath pathComponents];
                     [mediaDictionary setValue:[(NSString *)[pathComponents objectAtIndex:pathComponents.count - 2] stringByAppendingPathComponent:[pathComponents objectAtIndex:pathComponents.count - 1]] forKey:[assetURL absoluteString]];
                     [[[mediaDictionary copy] autorelease] writeToFile:[documentsPath stringByAppendingPathComponent:ARDRONE_MEDIAMANAGER_XML_FILE] atomically:YES];
                 }
                 // NO ELSE because if the value exists, we don't need to add again.
                 _transferingBlock([assetURL absoluteString]);
             }
         }];
        [library release];
    }
    else if ([mediaPath.pathExtension isEqualToString:ARDRONE_MEDIAMANAGER_JPG_EXTENSION])
    {
        [self.processingDictionary setObject:mediaPath forKey:mediaPath];        
        [(NSDictionary *)self.processingDictionary writeToFile:[documentsPath stringByAppendingPathComponent:ARDRONE_MEDIAMANAGER_PROCESSING_XML_FILE] atomically:YES];

        NSArray *pathComponents = [mediaPath pathComponents];
        NSData *data = [NSData dataWithContentsOfFile:mediaPath];
        NSDictionary *metadataDictionary = [NSDictionary dictionaryWithObject:[NSDictionary dictionaryWithObjectsAndKeys:ARDRONE_MEDIAMANAGER_TIFFMAKER, (NSString *)kCGImagePropertyTIFFMake, [(NSString *)[pathComponents objectAtIndex:pathComponents.count - 2] stringByAppendingPathComponent:[pathComponents objectAtIndex:pathComponents.count - 1]],  (NSString *)kCGImagePropertyTIFFImageDescription, nil] forKey:(NSString *)kCGImagePropertyTIFFDictionary];
        
        ALAssetsLibrary *library = [[ALAssetsLibrary alloc] init];
        [library writeImageDataToSavedPhotosAlbum:data metadata:metadataDictionary completionBlock:^(NSURL *assetURL, NSError *error) 
        {
            [self removeMediaPath:mediaPath];
            [self.processingDictionary removeObjectForKey:mediaPath];
            [(NSDictionary *)self.processingDictionary writeToFile:[documentsPath stringByAppendingPathComponent:ARDRONE_MEDIAMANAGER_PROCESSING_XML_FILE] atomically:YES];
            
            if(error != nil)
            {
                _transferingBlock(nil);
            }
            else
            {
                if([mediaDictionary valueForKey:[assetURL absoluteString]] == nil)
                {
                    [mediaDictionary setValue:[(NSString *)[pathComponents objectAtIndex:pathComponents.count - 2] stringByAppendingPathComponent:[pathComponents objectAtIndex:pathComponents.count - 1]] forKey:[assetURL absoluteString]];
                    [[[mediaDictionary copy] autorelease] writeToFile:[documentsPath stringByAppendingPathComponent:ARDRONE_MEDIAMANAGER_XML_FILE] atomically:YES];
                }
                // NO ELSE because if the value exists, we don't need to add again.
                _transferingBlock([assetURL absoluteString]);
            }
        }];
        [library release];
    }
    // NO ELSE - other media is not supported
}

- (void)transferNextMedia:(ARDroneMediaManagerRetrievingBlock)_retrievingBlock
{
    if([mediaToTransfer count] > 0)
    {
        [[ARDroneMediaManager sharedInstance] saveMedia:[mediaToTransfer objectAtIndex:0] transferingBlock:^(NSString *assetURLString) 
        {
             _retrievingBlock(1.0 - ([mediaToTransfer count] / (float)mediaToTransferCount), assetURLString);
            
             // Remove object
             [mediaToTransfer removeObjectAtIndex:0];
             
             // Transfer next object 
             [self performSelector:@selector(transferNextMedia:) withObject:_retrievingBlock];
        }];
    }
    else
    {
        _retrievingBlock(1.0, nil);
        mediaToTransferCount = 0;
    }
}

- (void)transferToCameraRoll:(ARDroneMediaManagerRetrievingBlock)_retrievingBlock 
{
    NSDirectoryEnumerator *dirEnumerator = [[NSFileManager defaultManager] enumeratorAtPath:documentsPath];
    NSString *filePath = nil;
    
    [mediaToTransfer removeAllObjects];
    while((filePath = [dirEnumerator nextObject]) != nil) 
    {
        if([filePath.pathExtension isEqualToString:ARDRONE_MEDIAMANAGER_MOV_EXTENSION] 
           || [filePath.pathExtension isEqualToString:ARDRONE_MEDIAMANAGER_JPG_EXTENSION])
        {
            [mediaToTransfer addObject:[documentsPath stringByAppendingPathComponent:filePath]];
        }
        // NO ELSE because we don't process other extension.
    }
    
    mediaToTransferCount = [mediaToTransfer count];
    [self transferNextMedia:_retrievingBlock];
}

- (void)mediaManagerTransferToCameraRoll:(NSString *)mediaPath
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    
    void (^transferingBlock)(NSString *) = ^(NSString *assetURLString) 
    {
        if(assetURLString != nil)
        {
            [[NSNotificationCenter defaultCenter] postNotificationName:ARDroneMediaManagerDidRefresh object:assetURLString];
            mediaToTransferIsReady = YES;
        }
    };

    while(!mediaManagerReady || !mediaToTransferIsReady)
        [NSThread sleepForTimeInterval:1.0];

    mediaToTransferIsReady = NO;
    [self saveMedia:mediaPath transferingBlock:transferingBlock];
    
    [pool release];
}

@end
