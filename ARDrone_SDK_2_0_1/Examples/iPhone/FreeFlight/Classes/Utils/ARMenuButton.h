//
//  ARMenuButton.h
//  FreeFlight
//
//  Created by Nicolas Payot on 10/10/11.
//  Copyright 2011 PARROT. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Common.h"
#import "ARUtils.h"

@interface ARLabel : UILabel
{
    CGSize constraintSize;
}
@end

@interface ARMenuButton : UIButton
{    
    UIImageView *background;
    ARLabel *infoLabel;
    BOOL active;
    BOOL infoDisplayed;
}

@property (nonatomic, assign, getter = isActive) BOOL active;
@property (nonatomic, retain) UIImageView *background;
@property (nonatomic, retain) ARLabel *infoLabel;

- (void)displayInfo;

@end
