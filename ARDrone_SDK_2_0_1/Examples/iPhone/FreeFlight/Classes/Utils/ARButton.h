//
//  ARButton.h
//  FreeFlight
//
//  Created by Nicolas Payot on 09/11/11.
//  Copyright 2011 PARROT. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface ARButton : UIButton {
    BOOL isTransparent;
    BOOL selected;
    CGFloat red, green, blue, alpha;
    CGFloat redH, greenH, blueH, alphaH;
    UIColor *grayScale;
}

@property (nonatomic, assign, setter = setTransparent:) BOOL isTransparent;

- (void)setBackgroundColorHighlighted:(UIColor *)color;

@end
