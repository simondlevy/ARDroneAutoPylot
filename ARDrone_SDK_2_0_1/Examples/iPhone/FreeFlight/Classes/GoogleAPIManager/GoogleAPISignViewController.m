//
//  GoogleAPISignViewController.m
//  FreeFlight
//
//  Created by Frederic D'HAEYER on 30/11/11.
//  Copyright 2011 PARROT. All rights reserved.
//
#import "GoogleAPISignViewController.h"
#import "Common.h"

@implementation GoogleAPISignViewController

typedef enum
{
    NO_INTERNET_CONNECTION  = -1009,
    AUTHENTICATION_FAILURE  = 403
} eErrorCode;

#define OFFSET 95.f

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    NSMutableString *nibName = [NSMutableString stringWithString:nibNameOrNil];
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
        [nibName appendString:@"-iPad"];
    
    return (self = [super initWithNibName:nibName bundle:nibBundleOrNil]);
}

- (void)dealloc
{
    [navBar release];
    [loginTextField release];
    [passwordTextField release];
    [signInButton release];
    [yesButton release];
    [noButton release];
    [yesPin release];
    [noPin release];
    [loadingViewController release];
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
    
    navBar = [[ARNavigationBarViewController alloc] initWithNibName:NAVIGATION_BAR bundle:nil];
    [self.view addSubview:navBar.view];
    [navBar displayBackButton];
    [navBar setViewTitle:LOCALIZED_STRING(@"CONNECTION TO ACCOUNT")];
    [navBar alignViewTitleRight];
    [navBar moveOnTop];
    [navBar.leftButton addTarget:self action:@selector(goBack) forControlEvents:UIControlEventTouchUpInside];
        
    [loginLabel setText:LOCALIZED_STRING(@"LOGIN")];
    [passwordLabel setText:LOCALIZED_STRING(@"PASSWORD")];
    [rememberLabel setText:LOCALIZED_STRING(@"Remember?")];
    [yesButton setTitle:LOCALIZED_STRING(@"Yes") forState:UIControlStateNormal];
    [noButton setTitle:LOCALIZED_STRING(@"No") forState:UIControlStateNormal];
    [signInButton setTitle:LOCALIZED_STRING(@"SIGN IN") forState:UIControlStateNormal];
    
    [loginTextField.layer setBorderWidth:2.f];
    [passwordTextField.layer setBorderWidth:2.f];
    [loginTextField.layer setBorderColor:ORANGE(1.f).CGColor];
    [passwordTextField.layer setBorderColor:ORANGE(1.f).CGColor];
    [loginTextField setDelegate:self];
    [passwordTextField setDelegate:self];
    
    [loginTextField setReturnKeyType:UIReturnKeyJoin];
    [passwordTextField setReturnKeyType:UIReturnKeyJoin];
    rememberCredentials = YES;
    
    loadingViewController =  [[ARLoadingViewController alloc] init];
    [self.view addSubview:loadingViewController.view];
    [loadingViewController setLoadingText:LOCALIZED_STRING(@"SIGNING IN...")];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self.navigationController setNavigationBarHidden:YES];
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

- (void)goBack
{
    [self.navigationController popViewControllerAnimated:YES];
}

#pragma mark - 
#pragma mark - UITextField delegate

- (void)keyboardWillShow
{    
    // Sets up animation
    [UIView beginAnimations:nil context:NULL];
    [UIView setAnimationDuration:0.2];
    [scrollView setContentOffset:CGPointMake(0.f, OFFSET)];
    [UIView commitAnimations];
}

- (void)keyboardWillHide
{
    [UIView beginAnimations:nil context:NULL];
    [UIView setAnimationDuration:0.2];
    // Reset original content offset
    [scrollView setContentOffset:CGPointMake(0.f, 0.f)];
    [UIView commitAnimations];
}

- (BOOL)textFieldShouldBeginEditing:(UITextField *)textField
{
    [self keyboardWillShow];
    return YES;
}

- (void)textFieldDidBeginEditing:(UITextField *)textField
{
    activeTextField = textField;
}

- (void)textFieldDidEndEditing:(UITextField *)textField
{
    activeTextField = nil;
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    [self keyboardWillHide];
    [textField resignFirstResponder];
    [self signIn];
    return YES;
}

#pragma mark - 
#pragma mark - IBactions

- (IBAction)signIn
{
    if (([loginTextField.text length] > 0) && ([passwordTextField.text length] > 0))
    {
        [loadingViewController showView];
        [[GoogleAPIManager sharedInstance] signIn:self username:loginTextField.text password:passwordTextField.text];
    }
}

- (void)rememberGoogleCredentials:(id)sender
{
    if (sender == yesButton)
    {
        [yesPin setImage:[UIImage imageNamed:@"ff2.0_pin_selected.png"]];
        [noPin setImage:[UIImage imageNamed:@"ff2.0_pin_not_selected.png"]];
        rememberCredentials = YES;
    }
    else
    {
        [yesPin setImage:[UIImage imageNamed:@"ff2.0_pin_not_selected.png"]];
        [noPin setImage:[UIImage imageNamed:@"ff2.0_pin_selected.png"]];
        rememberCredentials = NO;
    }
}

#pragma mark - 
#pragma mark - GoogleAPImanagerDelegate

- (void)googleAPIManagerDidFinishSignedIn:(GoogleAPIManager *)googleAPIManager error:(NSError *)error
{
    [loadingViewController hideView];
    
    if (error != nil)
    {
        eErrorCode errorCode = [error code];
        switch (errorCode)
        {
            case AUTHENTICATION_FAILURE:
                [ARAlertView displayAlertView:LOCALIZED_STRING(@"Authentication Failed") format:LOCALIZED_STRING(@"Wrong username / password.")];
                break;
            case NO_INTERNET_CONNECTION:
                [ARAlertView displayAlertView:LOCALIZED_STRING(@"Authentication Failed") format:LOCALIZED_STRING(@"Internet connection not available. Please make sure to have a 3G/Wi-Fi connection available.")];
                break;
            default:
                [ARAlertView displayAlertView:LOCALIZED_STRING(@"Authentication Failed") format:LOCALIZED_STRING(@"Unkown error.")];
        }
        
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:GOOGLE_USERNAME_KEY];
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:GOOGLE_PASSWORD_KEY];
    }
    else
    {
        if (rememberCredentials)
        {
            [[NSUserDefaults standardUserDefaults] setValue:[loginTextField text] forKey:GOOGLE_USERNAME_KEY];
            [[NSUserDefaults standardUserDefaults] setValue:[passwordTextField text] forKey:GOOGLE_PASSWORD_KEY];
        }
        else
        {
            [[NSUserDefaults standardUserDefaults] removeObjectForKey:GOOGLE_USERNAME_KEY];
            [[NSUserDefaults standardUserDefaults] removeObjectForKey:GOOGLE_PASSWORD_KEY];
        }
        
        [self goBack];
    }
}

@end
