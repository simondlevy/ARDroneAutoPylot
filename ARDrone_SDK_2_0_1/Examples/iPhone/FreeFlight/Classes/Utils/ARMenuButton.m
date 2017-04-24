//
//  ARMenuButton.m
//  FreeFlight
//
//  Created by Nicolas Payot on 10/10/11.
//  Copyright 2011 PARROT. All rights reserved.
//

#import "ARMenuButton.h"

@implementation ARLabel

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) constraintSize = CGSizeMake(frame.size.width, MAXFLOAT);
    return self;
}

- (void)setText:(NSString *)text
{
    [super setText:text];
    
    // Store original font settings
    UIFont *font = [UIFont fontWithName:self.font.fontName size:self.font.pointSize];
    // Calculate the needed font size
    for (int i = (int)font.pointSize; i > (int)self.minimumFontSize; --i)
    {
        font = [font fontWithSize:i];        
        CGSize size = [self.text sizeWithFont:font constrainedToSize:constraintSize lineBreakMode:self.lineBreakMode];
        if (size.height <= self.frame.size.height) break;
    }
    [self setFont:font];
}

@end

@implementation ARMenuButton

#define kARMenuButtonContentOffset  15.f

@synthesize background;
@synthesize infoLabel;
@synthesize active;

- (id)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self)
    {		
        active = YES;   
        infoDisplayed = NO;
        
        background = [[UIImageView alloc] initWithFrame:CGRectMake(0.f, 0.f, self.frame.size.width, self.frame.size.height)];
        [background setBackgroundColor:WHITE(0.5f)];
        [background setImage:[UIImage imageNamed:@"ff2.0_menu_button_nok.png"]];
        
        infoLabel = [[ARLabel alloc] initWithFrame:CGRectMake(kARMenuButtonContentOffset, kARMenuButtonContentOffset, 
                                                              self.frame.size.width - 2 * kARMenuButtonContentOffset, 
                                                              self.frame.size.height - 2 * kARMenuButtonContentOffset)];
        [infoLabel setBackgroundColor:[UIColor clearColor]];
        [infoLabel setTextColor:BLACK(0.3f)];
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
        {
            [infoLabel setFont:[UIFont fontWithName:HELVETICA size:20.f]];
            [infoLabel setMinimumFontSize:15.f];
        }
        else
        {
            [infoLabel setFont:[UIFont fontWithName:HELVETICA size:13.f]];
            [infoLabel setMinimumFontSize:10.f];
        }
        [infoLabel setTextAlignment:UITextAlignmentCenter];
        [infoLabel setLineBreakMode:UILineBreakModeWordWrap];
        [infoLabel setNumberOfLines:0];
    }
    return self;
}

- (void)dealloc
{
    [background release];
    [infoLabel release];
    [super dealloc];
}

- (void)setHighlighted:(BOOL)highlighted
{
    [super setHighlighted:highlighted];
        
    if (highlighted)
        [self setBackgroundColor:ORANGE((active) ? 1.f : .5f)];
    else 
        [self setBackgroundColor:BLACK((active) ? 0.5f : 0.25f)];
}

- (void)setActive:(BOOL)_active
{    
    active = _active;
    
    if (self.highlighted)
        [self setBackgroundColor:ORANGE((active) ? 1.f : .5f)];
    else 
        [self setBackgroundColor:BLACK((active) ? 0.5f : 0.25f)];
}

- (void)displayInfo
{
	if (active) return;
    
    if ((infoDisplayed = !infoDisplayed))
    {
        [self addSubview:background];
        [self.titleLabel removeFromSuperview];
        [self addSubview:infoLabel];
        [self performSelector:@selector(hideInfo) withObject:nil afterDelay:2.f];
    }
    else
    {
        [background removeFromSuperview];
        [infoLabel removeFromSuperview];
        [self addSubview:self.titleLabel];
        [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(hideInfo) object:nil];
    }
}

- (void)hideInfo
{
    infoDisplayed = NO;
    [background removeFromSuperview];
    [infoLabel removeFromSuperview];
    [self addSubview:self.titleLabel];
}

@end
