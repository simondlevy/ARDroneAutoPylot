//
//  ARNavigationController.m
//  FreeFlight
//
//  Created by Nicolas Payot on 25/08/11.
//  Copyright 2011 PARROT. All rights reserved.
//

#import "ARNavigationController.h"

@implementation ARNavigationController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (id)initWithController:(MenuController *)menuController
{
    self = [super initWithNibName:@"ARNavigationController" bundle:nil];
    if (self)
    {
        controller = menuController;
    }
    return  self;
}

- (void)dealloc
{
    [super dealloc];
}

- (void)didReceiveMemoryWarning
{
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc that aren't in use.
}

#pragma mark - View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // Return YES for supported orientations
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

- (void)executeCommandOut:(ARDRONE_COMMAND_OUT)commandId withParameter:(void *)parameter fromSender:(id)sender
{
    
}

@end
