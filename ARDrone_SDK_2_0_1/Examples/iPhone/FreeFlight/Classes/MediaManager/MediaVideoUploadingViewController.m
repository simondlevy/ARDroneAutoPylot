//
//  MediaVideoUploadingViewController.m
//  FreeFlight
//
//  Created by Frédéric D'Haeyer on 11/22/11.
//  Copyright 2011 Parrot SA. All rights reserved.
//
#import "MediaVideoUploadingViewController.h"

@interface MediaVideoUploadingViewController (private)
- (void)setVideoAccess:(BOOL)private;
- (NSString *)keyAtIndex:(NSUInteger)index;
- (void)retrieveCategories;
- (void)doSignIn;
- (void)initPrivacyPickerView;
@end

@implementation MediaVideoUploadingViewController

#define OFFSET_Y    ((UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) ? 0.f : 60.f)
#define OFFSET_Y2   ((UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) ? 90.f : 155.f)

@synthesize assetURLString;
@synthesize videoEntry;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    NSMutableString *nibName = [NSMutableString stringWithString:nibNameOrNil];
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
        [nibName appendString:@"-iPad"];
    
    self = [super initWithNibName:nibName bundle:nibBundleOrNil];
    if (self) 
    {
        // Custom initialization
        categories = [[NSMutableDictionary alloc] init];
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    self.videoEntry = nil;
    [assetURLString release];
    [navBar release];
    [toolbar release];
    [categoriesPickerView release];
    [categories release];
    [privateButton release];
    [publicButton release];
    [scrollView release];
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
- (void)viewDidFinishLoading
{
    [videoTitle setText:[[[(GDataEntryYouTubeUpload *)[videoEntry entry] mediaGroup] mediaTitle] stringValue]];
    [videoDescription setText:[[[(GDataEntryYouTubeUpload *)[videoEntry entry] mediaGroup] mediaDescription] stringValue]];
    [videoTags setText:[[[(GDataEntryYouTubeUpload *)[videoEntry entry] mediaGroup] mediaKeywords] stringValue]];
    
    [loadingViewController hideView];
    [loadingViewController addImageWithName:@"ff2.0_loading_youtube.png"];
    [loadingViewController displayCancelButton:YES];

    // If not signed to Google
    if ([[GoogleAPIManager sharedInstance] isSignedIn])
    {
        [self retrieveCategories];
    }
    else
    {
        // Open controller to authenticate user on google account
        [self doSignIn];
    }
}

- (void)observeGoogleAPIManagerDefaultEntryDidFinished:(NSNotification *)notification
{
    self.videoEntry = (GoogleAPIManagerEntry *)[notification object]; 
    needAuthRequest = YES;
    [self performSelectorOnMainThread:@selector(viewDidFinishLoading) withObject:nil waitUntilDone:NO];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:GoogleAPIManagerDefaultEntryDidFinished object:nil];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
    navBar = [[ARNavigationBarViewController alloc] initWithNibName:NAVIGATION_BAR bundle:nil];
    [self.view addSubview:navBar.view];
    [navBar setViewTitle:LOCALIZED_STRING(@"UPLOAD YOUR VIDEO")];
    [navBar alignViewTitleRight];
    [navBar moveOnTop];
    [navBar.leftButton addTarget:self action:@selector(goBack) forControlEvents:UIControlEventTouchUpInside];
    
    // Init loading view
    loadingViewController = [[ARLoadingViewController alloc] initWithDelegate:self];
    [self.view addSubview:loadingViewController.view];
    
    activeTextView = nil;
    
    toolbar = [[ARToolbar alloc] init];
    [toolbar.doneButton setTarget:self];
    
    [titleLabel setText:LOCALIZED_STRING(@"TITLE")];
    [descriptionLabel setText:LOCALIZED_STRING(@"DESCRIPTION")];
    [tagsLabel setText:LOCALIZED_STRING(@"TAGS")];
    [videoCategory setText:LOCALIZED_STRING(@"Retrieving categories...")];
    [privateButton setTitle:LOCALIZED_STRING(@"PRIVATE") forState:UIControlStateNormal];
    [publicButton setTitle:LOCALIZED_STRING(@"PUBLIC") forState:UIControlStateNormal];
    [uploadButton setTitle:LOCALIZED_STRING(@"UPLOAD NOW") forState:UIControlStateNormal];
    
    [videoTitle.layer setBorderWidth:2.f];
    [videoDescription.layer setBorderWidth:2.f];
    [videoTags.layer setBorderWidth:2.f];
    
    [videoTitle.layer setBorderColor:ORANGE(1.f).CGColor];
    [videoDescription.layer setBorderColor:ORANGE(1.f).CGColor];
    [videoTags.layer setBorderColor:ORANGE(1.f).CGColor];
    
    [videoDescription setContentInset:UIEdgeInsetsMake(-5.f, -5.f, 0.f, 0.f)];
    [videoTags setContentInset:UIEdgeInsetsMake(-5.f, -5.f, 0.f, 0.f)];
    
    [videoCategory setUserInteractionEnabled:NO];
    [privateButton setUserInteractionEnabled:NO];
    [publicButton setUserInteractionEnabled:NO];
    
    [self setVideoAccess:YES];

    self.videoEntry = nil;
    needAuthRequest = NO;
    
    [loadingViewController displaySpinner];
    [loadingViewController showView];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(observeGoogleAPIManagerDefaultEntryDidFinished:) name:GoogleAPIManagerDefaultEntryDidFinished object:nil];
    [[GoogleAPIManager sharedInstance] performSelector:@selector(getDefaultEntry:) withObject:assetURLString afterDelay:1.0];
    viewDidLoad = YES;
}

- (void) viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];

    if (!viewDidLoad)
    {
        if ([[GoogleAPIManager sharedInstance] isSignedIn])
        {
            [self retrieveCategories];
        }
        else if(needAuthRequest)
        {
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:LOCALIZED_STRING(@"Authentication Failed") 
                                                            message:LOCALIZED_STRING(@"Do you want to retry?") 
                                                           delegate:self cancelButtonTitle:LOCALIZED_STRING(@"No") otherButtonTitles:LOCALIZED_STRING(@"Yes"), nil];
            [alert show];
            [alert release];
        }
    }
}

- (void)setVideoAccess:(BOOL)private
{
    privateVideo = private;
    [privateButton setSelected:private];
    [publicButton setSelected:!private];
}

- (void)doSignIn
{
    viewDidLoad = NO;
    GoogleAPISignViewController *signInViewController = [[GoogleAPISignViewController alloc] initWithNibName:@"GoogleAPISignView" bundle:nil];
    [self.navigationController pushViewController:signInViewController animated:YES];
    [signInViewController release];
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

- (void)enableInterface:(BOOL)enable
{
    if (enable)
    {
        for (UIView *view in self.view.subviews)
            [view setUserInteractionEnabled:YES];
    }
    else
    {
        for (UIView *view in self.view.subviews)
            [view setUserInteractionEnabled:NO];
        [navBar.view setUserInteractionEnabled:YES];
    }
}

- (void)goBack
{
    [[GoogleAPIManager sharedInstance] cancelAllActions];
    [self.navigationController popViewControllerAnimated:YES];
}

- (void)retrieveCategories
{
    [videoCategory setText:LOCALIZED_STRING(@"Retrieving categories...")];
    [selectCategoryButton setUserInteractionEnabled:NO];
    [spinner startAnimating];
    [[GoogleAPIManager sharedInstance] getYouTubeCategories:self];
}

#pragma mark - 
#pragma mark - IBActions

- (void)privateButtonClicked
{
    [self setVideoAccess:YES];
}

- (void)publicButtonClicked
{
    [self setVideoAccess:NO];
}

- (IBAction)selectCategoryButtonClicked
{
    [videoCategory setUserInteractionEnabled:YES];

    for (NSInteger i = 0; i < [categories count]; ++i)
    {
        if([(NSString *)[categories objectForKey:[self keyAtIndex:i]] compare:videoCategory.text] == NSOrderedSame)
            [categoriesPickerView selectRow:i inComponent:0 animated:NO];
    }
    
    [categoriesPickerView setShowsSelectionIndicator:YES];
    [videoCategory setInputView:categoriesPickerView];
    [videoCategory becomeFirstResponder];
}

- (IBAction)uploadButtonClicked
{
    GDataMediaTitle *title = [GDataMediaTitle textConstructWithString:videoTitle.text];
    
    GDataMediaCategory *category = [GDataMediaCategory mediaCategoryWithString:[self keyAtIndex:[categoriesPickerView selectedRowInComponent:0]]];
    [category setScheme:kGDataSchemeYouTubeCategory];
    
    GDataMediaDescription *desc = [GDataMediaDescription textConstructWithString:videoDescription. text];
    
    GDataMediaKeywords *keywords = [GDataMediaKeywords keywordsWithString:videoTags.text];
    
    GDataYouTubeMediaGroup *mediaGroup = [(GDataEntryYouTubeUpload *)[videoEntry entry] mediaGroup];
    [mediaGroup setMediaTitle:title];
    [mediaGroup setMediaDescription:desc];
    [mediaGroup setMediaCategories:[NSArray arrayWithObject:category]];
    [mediaGroup setMediaKeywords:keywords];
    [mediaGroup setIsPrivate:privateVideo];
    
    [(GDataEntryYouTubeUpload *)[videoEntry entry] setMediaGroup:mediaGroup];
    
    [loadingViewController setLoadingText:LOCALIZED_STRING(@"UPLOADING...")];
    [loadingViewController displayProgressBar];
    [loadingViewController showView];

    [[GoogleAPIManager sharedInstance] uploadVideo:self entry:videoEntry];
}

#pragma mark - 
#pragma mark - GoogleAPIManager Delegate

// Categories getter callback
- (void)initCategoriesPickerView
{       
    NSMutableArray *categories_array = [NSMutableArray arrayWithCapacity:[categories count]];
    for(int idx = 0 ; idx < [categories count] ; idx++)
        [categories_array addObject:[categories objectForKey:[self keyAtIndex:idx]]];
    
    categoriesPickerView = [[ARPickerViewController alloc] initWithArrayOfArrays:[NSArray arrayWithObject:categories_array]];
    [categoriesPickerView setShowsSelectionIndicator:NO];
}

- (void)googleAPIManagerGetCategoriesDidFinish:(GoogleAPIManager *)googleAPIManager categories:(NSDictionary *)_categories error:(NSError *)error
{
    [spinner stopAnimating];
    
    if (error == nil)
    {
        [categories removeAllObjects];
        [categories addEntriesFromDictionary:_categories];
        [self initCategoriesPickerView];
        NSString *categoryKey = [[[[(GDataEntryYouTubeUpload *)[videoEntry entry] mediaGroup] mediaCategories] objectAtIndex:0] stringValue];
        [videoCategory setText:[categories objectForKey:categoryKey]];
        
        [uploadButton setHidden:NO];
        [selectCategoryButton setUserInteractionEnabled:YES];
        [privateButton setUserInteractionEnabled:YES];
        [publicButton setUserInteractionEnabled:YES];
    }
    else
    {
        [loadingViewController setLoadingText:LOCALIZED_STRING(@"FAILED TO RETRIEVE CATEGORIES!")];
        [loadingViewController displaySpinner];
        [loadingViewController showView];
        
        [self performSelector:@selector(goBack) withObject:nil afterDelay:LOADING_TIMEOUT];
    }
}

// upload callback
- (void)uploadFinishedWithSuccess:(NSNumber *)success
{
    [loadingViewController hideView];
    
    if ([success boolValue])
        [self goBack];
}

- (void)googleAPIManagerVideoUploadDidFinish:(GoogleAPIManager *)googleAPIManager entry:(GDataEntryBase *)entry error:(NSError *)error
{
    if(error == nil)
        [loadingViewController setLoadingText:LOCALIZED_STRING(@"VIDEO UPLOADED!")];
    else
    {
        if(error.code == 401)
        {
            [loadingViewController setLoadingText:[NSString stringWithFormat:@"%@ %@", LOCALIZED_STRING(@"FAILED TO UPLOAD VIDEO!"), LOCALIZED_STRING(@"Please create a channel on http://www.youtube.com.")]];
        }
        else
        {
            [loadingViewController setLoadingText:LOCALIZED_STRING(@"FAILED TO UPLOAD VIDEO!")];
        }
        [self enableInterface:YES];
    }

    [self performSelector:@selector(uploadFinishedWithSuccess:) withObject:[NSNumber numberWithBool:(error == nil)] afterDelay:LOADING_TIMEOUT];
}

- (void)googleAPIManagerUploadDidProgress:(GoogleAPIManager *)googleAPIManager percentValue:(float)percent
{
    [loadingViewController setProgressBarValue:percent];
}

#pragma mark - 
#pragma mark - UIPickerViewDelegate

- (NSString *)keyAtIndex:(NSUInteger)index
{
    NSArray *keyArray = [categories keysSortedByValueUsingComparator:
                         ^NSComparisonResult(id obj1, id obj2) { return [(NSString *)obj1 compare:(NSString *)obj2]; }];
    return [keyArray objectAtIndex:index];
}

- (void)keyboardWillShow:(CGFloat)offset
{    
    // Sets up animation
    [UIView beginAnimations:nil context:NULL];
    [UIView setAnimationDuration:0.2];
    [scrollView setContentOffset:CGPointMake(0.f, offset)];
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

- (void)hideKeyboard
{
    [self keyboardWillHide];
    [activeTextView resignFirstResponder];
}

- (void)categoryWasSelected:(id)sender
{
    [videoCategory setText:[categories objectForKey:[self keyAtIndex:[categoriesPickerView selectedRowInComponent:0]]]];
    [self hideKeyboard];
}

#pragma mark - 
#pragma mark - UITextFieldDelegate

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    return YES;
}

- (BOOL)textFieldShouldBeginEditing:(UITextField *)textField
{
    activeTextView = textField;
    if (textField == videoCategory)
    {
        [videoCategory setUserInteractionEnabled:NO];
        [[toolbar doneButton] setAction:@selector(categoryWasSelected:)];
    }
    else
        [[toolbar doneButton] setAction:@selector(hideKeyboard)];
    
    [textField setInputAccessoryView:toolbar]; 
    return YES;
}

#pragma mark - 
#pragma mark - UITextViewDelegate

- (BOOL)textViewShouldBeginEditing:(UITextView *)textView
{
    activeTextView = textView;

    if (textView == videoDescription)
        [self keyboardWillShow:OFFSET_Y];
    else if (textView == videoTags)
        [self keyboardWillShow:OFFSET_Y2];
    
    [[toolbar doneButton] setAction:@selector(hideKeyboard)];
    [textView setInputAccessoryView:toolbar];

    return YES;
}

#pragma mark - 
#pragma mark - UIAlertViewDelegate

- (void) alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if(buttonIndex == 0)
        [self goBack];
    else
        [self doSignIn];
}

#pragma mark - 
#pragma mark - ARLoadingViewDelegate

- (void)loadingViewControllerCancelButtonClicked:(ARLoadingViewController *)loadingViewController
{
    [[GoogleAPIManager sharedInstance] cancelAllActions];
}

@end
