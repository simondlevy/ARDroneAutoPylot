//
//  ARSlider.h
//  ARDroneEngine
//
//  Created by Nicolas BRULEZ on 22/12/11.
//  Copyright (c) 2011 Parrot. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface ARSlider : UISlider 
{
    CGFloat defaultSliderHeight;
    CGFloat sliderHeight;
    UILabel *minLabel;
    UILabel *maxLabel;
    float minLabelBlackValue;
    float maxLabelBlackValue;
}

@end
