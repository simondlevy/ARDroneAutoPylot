//
//  ARButton.m
//  FreeFlight
//
//  Created by Nicolas Payot on 09/11/11.
//  Copyright 2011 PARROT. All rights reserved.
//

#import "ARButton.h"
#import "Common.h"

@implementation ARButton

@synthesize isTransparent;

- (id)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self) 
    {
        isTransparent = NO;
        selected = NO;
        
        // Default is clear color
        red = redH = green = greenH = blue = blueH = alpha = alphaH = 0.f;
        
        const CGFloat *rgb = CGColorGetComponents(self.backgroundColor.CGColor);
        
        isTransparent = NO;
        selected = NO;
        
        // If background color was set
        if (rgb != NULL)
        {
            red = redH = rgb[0];
            green = greenH = rgb[1];
            blue = blueH = rgb[2];
            alpha = alphaH = rgb[3];
        }
        
        grayScale = nil;
    }
    return self;
}

- (void)dealloc
{
    [grayScale release];
    [super dealloc];
}

- (void)setBackgroundColorHighlighted:(UIColor *)color
{
    const CGFloat *rgbH = CGColorGetComponents(color.CGColor);
    
    // Color is black or white
    if (CGColorGetNumberOfComponents(color.CGColor) == 4)
    {
        redH = rgbH[0];
        greenH = rgbH[1];
        blueH = rgbH[2];
        alphaH = rgbH[3];
        
        grayScale = nil;
    }
    else 
    {
        grayScale = [[UIColor colorWithWhite:rgbH[0] alpha:rgbH[1]] retain];
    }
}

- (void)changeBackgroundColor:(BOOL)highlighted
{
    if (highlighted)
    {
        [self.imageView setImage:[self imageForState:UIControlStateHighlighted]];
        [self.titleLabel setTextColor:[self titleColorForState:UIControlStateHighlighted]];
        [self setBackgroundColor:(grayScale != nil ? grayScale : [UIColor colorWithRed:redH green:greenH blue:blueH alpha:alphaH])];
    }
    else 
    {
        [self setBackgroundColor:[UIColor colorWithRed:red green:green blue:blue alpha:alpha]];
    }
}

- (void)setHighlighted:(BOOL)highlighted
{    
    if (selected)
    {
        [self changeBackgroundColor:YES];
    }
    else
    {
        [super setHighlighted:highlighted];
        [self changeBackgroundColor:highlighted];
    }
}

- (void)setEnabled:(BOOL)enabled
{    
    if (!enabled)
    {
        [self.titleLabel setTextColor:[self titleColorForState:UIControlStateDisabled]];
        [self.imageView setImage:[self imageForState:UIControlStateDisabled]];
    }
    else
    {
        [self.titleLabel setTextColor:[self titleColorForState:UIControlStateNormal]];
        [self.imageView setImage:[self imageForState:UIControlStateNormal]];
    }
}

- (void)setSelected:(BOOL)_selected
{
    selected = _selected;
    [self setHighlighted:selected];
}

- (BOOL)isSelected
{
    return selected;
}

@end
