//
//  ARAlertView.h
//  FreeFlight
//
//  Created by Frédéric D'Haeyer on 11/17/11.
//  Copyright 2011 Parrot SA. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Common.h"

@interface ARAlertView : NSObject 
{

}

+ (void)displayAlertView:(NSString *)title format:(NSString *)format, ...;

@end
