//
//  MenuPreferences.m
//  FreeFlight
//
//  Created by Frédéric D'Haeyer on 11/14/11.
//  Copyright 2011 Parrot SA. All rights reserved.
//

#import "MenuPreferences.h"

@interface MenuPreferences (private)
- (void)updateSignInButton;
@end

@implementation MenuPreferences

@synthesize displayHomeIcon;

- (id) initWithController:(MenuController*)menuController
{
	if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
		self = [super initWithNibName:@"MenuPreferences-iPad" bundle:nil];
	else
		self = [super initWithNibName:@"MenuPreferences" bundle:nil];
	
	if (self)
	{
		controller = menuController;
        displayHomeIcon = NO;
	}
	return self;
}

- (void)dealloc
{
    [navBar release];
    [googleAccountSignIn release];
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
    [self.navigationController setNavigationBarHidden:YES];
    
    // Do any additional setup after loading the view from its nib.
    navBar = [[ARNavigationBarViewController alloc] initWithNibName:NAVIGATION_BAR bundle:nil];
    [self.view addSubview:navBar.view];
    [navBar moveOnTop];
    [navBar setViewTitle:LOCALIZED_STRING(@"PREFERENCES")];
    if (displayHomeIcon) [navBar displayHomeButton];
    [navBar.leftButton addTarget:self action:@selector(goBack) forControlEvents:UIControlEventTouchUpInside];
    
    [googleAccountLabel setText:LOCALIZED_STRING(@"Google Account")];
    
    [self updateSignInButton];
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
	return UIInterfaceOrientationIsLandscape(interfaceOrientation);
}

- (void)executeCommandOut:(ARDRONE_COMMAND_OUT)commandId withParameter:(void*)parameter fromSender:(id)sender
{
    
}

- (void)goBack
{
    if ([self.navigationController.viewControllers objectAtIndex:0] == self)
    {
        [controller doAction:MENU_FF_ACTION_JUMP_TO_HOME];
    }
    else
        [self.navigationController popViewControllerAnimated:NO];
}

- (void)updateSignInButton
{
    [googleAccountSignIn setTag:[[GoogleAPIManager sharedInstance] isSignedIn]];
    
    if ((BOOL)googleAccountSignIn.tag)
    {
        [googleAccountSignIn setTitle:[LOCALIZED_STRING(@"SIGN OUT") uppercaseString] forState:UIControlStateNormal];
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
            [googleAccountSignIn setImage:[UIImage imageNamed:@"ff2.0_arrow_left_iPad.png"] forState:UIControlStateNormal];
        else
            [googleAccountSignIn setImage:[UIImage imageNamed:@"ff2.0_arrow_left.png"] forState:UIControlStateNormal];
        
    }
    else
    {
        [googleAccountSignIn setTitle:[LOCALIZED_STRING(@"SIGN IN") uppercaseString] forState:UIControlStateNormal];
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
            [googleAccountSignIn setImage:[UIImage imageNamed:@"ff2.0_arrow_right_iPad.png"] forState:UIControlStateNormal];
        else
            [googleAccountSignIn setImage:[UIImage imageNamed:@"ff2.0_arrow_right.png"] forState:UIControlStateNormal];
    }
}

#pragma mark - 
#pragma mark - IBActions

- (IBAction)buttonClick:(id)sender
{
    if(sender == googleAccountSignIn)
    {
        if((BOOL)[googleAccountSignIn tag])
        {
            [[GoogleAPIManager sharedInstance] signOut];
            [[NSUserDefaults standardUserDefaults] removeObjectForKey:GOOGLE_USERNAME_KEY];
            [[NSUserDefaults standardUserDefaults] removeObjectForKey:GOOGLE_PASSWORD_KEY];
            [self updateSignInButton];
        }
        else
        {
            // Open controller to authenticate on Google Account
            GoogleAPISignViewController *signInViewController = [[GoogleAPISignViewController alloc] initWithNibName:@"GoogleAPISignView" bundle:nil];
            [self.navigationController pushViewController:signInViewController animated:YES];
            [signInViewController release];
        }
    }
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self updateSignInButton];
}

@end
