//
//  ARAlert.m
//  FreeFlight
//
//  Created by Frédéric D'Haeyer on 11/17/11.
//  Copyright 2011 Parrot SA. All rights reserved.
//

#import "ARAlertView.h"

@implementation ARAlertView

+ (void)displayAlertView:(NSString *)title format:(NSString *)format, ... 
{
    NSString *result = format;
    if (format) {
        va_list argList;
        va_start(argList, format);
        result = [[[NSString alloc] initWithFormat:format
                                         arguments:argList] autorelease];
        va_end(argList);
    }
    
    UIAlertView *alertView = [[[UIAlertView alloc] initWithTitle:title message:result delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil] autorelease];
    [alertView show];
}

@end
