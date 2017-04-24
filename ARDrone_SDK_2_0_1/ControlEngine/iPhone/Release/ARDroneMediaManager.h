//
//  ARDroneMediaManager.h
//  ARDroneEngine
//
//  Created by Frédéric D'Haeyer on 2/10/12.
//  Copyright (c) 2012 Parrot SA. All rights reserved.
//
#import <Foundation/Foundation.h>
#import <AssetsLibrary/AssetsLibrary.h>
#import <ImageIO/CGImageProperties.h>
#import <CoreLocation/CoreLocation.h>

#define ARDRONE_MEDIAMANAGER_MOV_EXTENSION          @"mov"
#define ARDRONE_MEDIAMANAGER_JPG_EXTENSION          @"jpg"
#define ARDRONE_MEDIAMANAGER_ENC_EXTENSION          @"enc"

// Observers
extern NSString *const ARDroneMediaManagerIsReady;
extern NSString *const ARDroneMediaManagerDidRefresh;
extern NSString *const ARDroneMediaManagerDidRemove;

// This block is always executed. If failure, an NSError is passed.
typedef void (^ARDroneMediaManagerTranferingBlock)(NSString *assetURLString);
typedef void (^ARDroneMediaManagerRetrievingBlock)(float percent, NSString *assetURLString);

// C Function Prototypes
void ARDroneMediaManagerSetTransferInProgress(void);

@interface ARDroneMediaManager : NSObject
{
    NSMutableDictionary *processingDictionary;
    NSMutableDictionary *mediaDictionary;
    NSMutableArray *mediaAssets;
    NSMutableArray *mediaToTransfer;
    NSUInteger mediaToTransferCount;
    NSString *documentsPath;
    BOOL cancelRefresh;
    BOOL mediaManagerReady;
    BOOL mediaToTransferIsReady;
}

@property (nonatomic, copy) NSString *documentsPath;
@property (nonatomic, retain) NSMutableDictionary *processingDictionary;
@property (nonatomic, retain) NSMutableDictionary *mediaDictionary;
@property (nonatomic, assign, readonly) BOOL mediaManagerReady;
@property (nonatomic, assign, readonly) BOOL mediaToTransferIsReady;
@property (nonatomic, assign) BOOL cancelRefresh;

+ (ARDroneMediaManager *)sharedInstance;

- (void)mediaManagerInit;
- (void)mediaManagerShutdown;
- (void)mediaManagerTransferToCameraRoll:(NSString *)mediaPath;
- (NSInteger)mediaManagerGetDroneVersion:(ALAsset *)asset;
@end
