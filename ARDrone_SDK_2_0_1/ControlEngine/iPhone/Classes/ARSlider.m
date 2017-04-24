//
//  ARSlider.m
//  ARDroneEngine
//
//  Created by Nicolas BRULEZ on 22/12/11.
//  Copyright (c) 2011 Parrot. All rights reserved.
//

#import "ARSlider.h"
#import "ARDroneTypes.h"

@implementation ARSlider

#define LABEL_OFFSET 10.f

- (id)initWithCoder:(NSCoder *)aDecoder
{
    if (self = [super initWithCoder:aDecoder])
    {
        defaultSliderHeight = self.frame.size.height;
        
        UIImage *scrollBarGray = nil;
        UIImage *scrollBarOrange  = nil;
        UIImage *scrollBtn = nil;
        CGFloat labelSize = 12.f;
        
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
        {
            scrollBarGray = [[UIImage imageNamed:@"scroll_bar_gray_iPad.png"] stretchableImageWithLeftCapWidth:20 topCapHeight:0];
            scrollBarOrange = [[UIImage imageNamed:@"scroll_bar_orange_iPad.png"] stretchableImageWithLeftCapWidth:20 topCapHeight:0];
            scrollBtn = [[UIImage imageNamed:@"scroll_btn_iPad.png"] stretchableImageWithLeftCapWidth:20 topCapHeight:0];
            labelSize = 18.f;
        }
        else
        {
            scrollBarGray = [[UIImage imageNamed:@"scroll_bar_gray.png"] stretchableImageWithLeftCapWidth:20 topCapHeight:0];
            scrollBarOrange = [[UIImage imageNamed:@"scroll_bar_orange.png"] stretchableImageWithLeftCapWidth:20 topCapHeight:0];
            scrollBtn = [[UIImage imageNamed:@"scroll_btn.png"] stretchableImageWithLeftCapWidth:20 topCapHeight:0];
        }
        
        // fix color bar only for ios6, delete these lines if is resolved by Apple
        if ([[[UIDevice currentDevice] systemVersion] floatValue] >= 6.0)
            scrollBarGray = [scrollBarGray resizableImageWithCapInsets:UIEdgeInsetsMake(0, 5, 0, 5)];
        
        
        [self setMinimumTrackImage:scrollBarOrange forState:UIControlStateNormal];
        [self setMaximumTrackImage:scrollBarGray forState:UIControlStateNormal];
        [self setThumbImage:scrollBtn forState:UIControlStateNormal];
        
        sliderHeight = scrollBtn.size.height;
        
        minLabel = [[UILabel alloc] init];
        maxLabel = [[UILabel alloc] init];
        
        [minLabel setFont:[UIFont fontWithName:HELVETICA size:labelSize]];
        [minLabel setTextColor:WHITE(1.f)];
        [minLabel setBackgroundColor:[UIColor clearColor]];
        [minLabel setText:[NSString stringWithFormat:@"%d", (int)self.minimumValue]];
        [minLabel sizeToFit];
        
        [maxLabel setFont:[UIFont fontWithName:HELVETICA size:labelSize]];
        [maxLabel setTextColor:WHITE(1.f)];
        [maxLabel setBackgroundColor:[UIColor clearColor]];
        [maxLabel setText:[NSString stringWithFormat:@"%d", (int)self.maximumValue]];
        [maxLabel sizeToFit];
        
        CGRect frame = minLabel.frame;
        frame.origin.x = LABEL_OFFSET;
        frame.origin.y = (self.frame.size.height - frame.size.height) / 2.f;
        [minLabel setFrame:frame];
        
        frame = maxLabel.frame;
        frame.origin.x = self.frame.size.width - frame.size.width - LABEL_OFFSET;
        frame.origin.y = (self.frame.size.height - frame.size.height) / 2.f;
        [maxLabel setFrame:frame];
        
        minLabelBlackValue = ((minLabel.frame.size.width + LABEL_OFFSET) / (self.frame.size.width)) * (self.maximumValue - self.minimumValue) + self.minimumValue;
        maxLabelBlackValue = (1.0 - ((maxLabel.frame.size.width + LABEL_OFFSET) / (self.frame.size.width))) * (self.maximumValue - self.minimumValue) + self.minimumValue;
    }
    return self;
}

- (void)drawRect:(CGRect)rect
{
    [super drawRect:rect];
    [self addSubview:minLabel];
    [self addSubview:maxLabel];
}

- (CGRect)thumbRectForBounds:(CGRect)bounds trackRect:(CGRect)rect value:(float)value
{
    // Called when value changes
    if (value <= minLabelBlackValue)
        [minLabel setTextColor:BLACK(1.f)];
    else
        [minLabel setTextColor:WHITE(1.f)];
    
    if (value >= maxLabelBlackValue)
        [maxLabel setTextColor:BLACK(1.f)];
    else
        [maxLabel setTextColor:WHITE(1.f)];
    
    return [super thumbRectForBounds:bounds trackRect:rect value:value];
}

- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent*)event 
{
    CGRect bounds = self.bounds;
    bounds = CGRectInset(bounds, 0.f, defaultSliderHeight - sliderHeight);
    return CGRectContainsPoint(bounds, point);
}

@end
