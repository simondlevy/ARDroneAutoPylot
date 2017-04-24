//
//  ARImage.m
//  FreeFlight
//
//  Created by Nicolas Payot on 02/09/11.
//  Copyright 2011 PARROT. All rights reserved.
//

#import "ARImage.h"

@implementation ARImage

@synthesize tag;

- (id)initWithCGImage:(CGImageRef)imageRef
{
    self = [super initWithCGImage:imageRef];
    if (self) self.tag = 0;
    return self;
}

- (id)initWithData:(NSData *)data
{
    self = [super initWithData:data];
    if (self) self.tag = 0;
    return self;
}

- (ARImage *)generateThumbnailWithFrame:(CGRect)frame
{
    // Create an image context that will essentially "hold" the new image
    UIGraphicsBeginImageContext(CGSizeMake(frame.size.width, frame.size.height));
    // Redraw the image in a smaller rectangle.
    [self drawInRect:frame];
    // Make a "copy" of the image from the current context
    ARImage *thumb = [[ARImage alloc] initWithCGImage:UIGraphicsGetImageFromCurrentImageContext().CGImage];
    UIGraphicsEndImageContext();
    return [thumb autorelease];
}

- (ARImage *)scaleWithThreshold:(CGFloat)biggestSide
{
    if (self.size.width <= biggestSide && self.size.height <= biggestSide) 
        return self;
    
    // Calculate scaleFactor
    CGFloat scaleFactor = biggestSide / (self.size.width > self.size.height ? self.size.width : self.size.height);
    CGSize newSize = CGSizeMake(self.size.width * scaleFactor, self.size.height * scaleFactor);
    // Create an image context that will essentially "hold" the new image
    UIGraphicsBeginImageContext(CGSizeMake(newSize.width, newSize.height));
    // Redraw the image in a smaller rectangle.
    [self drawInRect:CGRectMake(0.f, 0.f, newSize.width, newSize.height)];
    // Make a "copy" of the image from the current context
    ARImage *image = [[ARImage alloc] initWithCGImage:UIGraphicsGetImageFromCurrentImageContext().CGImage];
    UIGraphicsEndImageContext();
    return [image autorelease];
}

@end
