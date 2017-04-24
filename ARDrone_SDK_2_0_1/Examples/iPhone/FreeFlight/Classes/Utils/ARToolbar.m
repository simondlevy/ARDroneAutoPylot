//
//  ARToolbarDoneButton.m
//  ARDroneAcademy
//
//  Created by Nicolas Payot on 03/05/11.
//  Copyright 2011 PARROT. All rights reserved.
//
#import "ARToolbar.h"

@implementation ARToolbar

@synthesize doneButton;

- (id)init
{
    self = [super init];
    if (self)
    {
        self.barStyle = UIBarStyleBlack;
        self.translucent = YES;
        self.tintColor = nil;
        [self sizeToFit];
        
        // Places button at the right of the bar
        UIBarButtonItem *flexibleSpaceBar = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];    
        doneButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:nil action:nil];
        [self setItems:[NSArray arrayWithObjects:flexibleSpaceBar, doneButton, nil]];
        [flexibleSpaceBar release];
    }
    return self;
}

- (void)dealloc
{
    [doneButton release];
    [super dealloc];
}

@end
