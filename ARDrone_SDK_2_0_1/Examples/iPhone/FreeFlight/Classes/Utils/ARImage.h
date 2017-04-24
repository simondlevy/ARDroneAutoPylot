//
//  ARImage.h
//  FreeFlight
//
//  Created by Nicolas Payot on 02/09/11.
//  Copyright 2011 PARROT. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface ARImage : UIImage {
    NSInteger tag;
}

@property (nonatomic, assign) NSInteger tag;

- (ARImage *)generateThumbnailWithFrame:(CGRect)frame;
- (ARImage *)scaleWithThreshold:(CGFloat)biggestSide;

@end
