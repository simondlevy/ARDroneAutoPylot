//
//  MediaPhotoUploadingViewController.m
//  FreeFlight
//
//  Created by Frédéric D'Haeyer on 11/22/11.
//  Copyright 2011 Parrot SA. All rights reserved.
//

#import "MediaPhotoUploadingViewController.h"
#import "Common.h"

@interface MediaPhotoUploadingViewController (private)
- (void)initAlbumsPickerView;
- (void)retrieveAlbums;
- (void)doSignIn;
- (void)enableInterface:(BOOL)enable;
- (void)hideKeyboard;
@end

@implementation MediaPhotoUploadingViewController

#define OFFSET_Y    ((UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) ? 0.f : 60.f)
#define OFFSET_Y2   ((UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) ? 90.f : 155.f)

#define UNKNOWN_USER_ERROR_CODE 404
#define AUTH_ALERT_TAG          100

@synthesize assetURLString;
@synthesize photoEntry;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    NSMutableString *nibName = [NSMutableString stringWithString:nibNameOrNil];
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
        [nibName appendString:@"-iPad"];
    
    self = [super initWithNibName:nibName bundle:nibBundleOrNil];
    if (self) 
    {
        // Custom initialization
        albums = [[NSMutableArray alloc] init];
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    self.photoEntry = nil;
    [assetURLString release];
    [navBar release];
    [toolbar release];
    [albumsPickerView release];
    [albums release];
    [loadingViewController release];
    [scrollView release];
    [super dealloc];
}

- (void)didReceiveMemoryWarning
{
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
}

- (void)setAlbumAccess:(BOOL)private
{
    newAlbumAccess = private;
    [privateButton setSelected:private];
    [publicButton setSelected:!private];
}

#pragma mark - View lifecycle
- (void)viewDidFinishLoading
{
    [photoTitle setText:[[[(GDataEntryPhoto *)[photoEntry entry] mediaGroup] mediaTitle] stringValue]];
    [photoDescription setText:[[[(GDataEntryPhoto *)[photoEntry entry] mediaGroup] mediaDescription] stringValue]];
    [photoTags setText:[[[(GDataEntryPhoto *)[photoEntry entry] mediaGroup] mediaKeywords] stringValue]];
    
    [loadingViewController hideView];
    [loadingViewController addImageWithName:@"ff2.0_loading_picasa.png"];
    [loadingViewController displayCancelButton:YES];

    // If signed to Google
    if ([[GoogleAPIManager sharedInstance] isSignedIn])
    {
        [self retrieveAlbums];
    }
    else
    {
        // Open controller to authenticate user on google account
        [self doSignIn];
    }
}

- (void)observeGoogleAPIManagerDefaultEntryDidFinished:(NSNotification *)notification
{
    self.photoEntry = (GoogleAPIManagerEntry *)[notification object]; 
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
    [navBar setViewTitle:[LOCALIZED_STRING(@"UPLOAD YOUR PICTURE") uppercaseString]];
    [navBar alignViewTitleRight];
    [navBar moveOnTop];
    [navBar.leftButton addTarget:self action:@selector(goBack) forControlEvents:UIControlEventTouchUpInside];

    loadingViewController = [[ARLoadingViewController alloc] initWithDelegate:self];
    [self.view addSubview:loadingViewController.view];
    
    activeTextView = nil;
    shouldShowAlbumsPicker = NO;
    
    toolbar = [[ARToolbar alloc] init];
    [toolbar.doneButton setTarget:self];
    
    [titleLabel setText:LOCALIZED_STRING(@"TITLE")];
    [descriptionLabel setText:LOCALIZED_STRING(@"DESCRIPTION")];
    [tagsLabel setText:LOCALIZED_STRING(@"TAGS")];
    [albumTitle setText:LOCALIZED_STRING(@"AR.Drone album")];
    [albumTitle setUserInteractionEnabled:NO];
    [privateButton setTitle:LOCALIZED_STRING(@"PRIVATE") forState:UIControlStateNormal];
    [publicButton setTitle:LOCALIZED_STRING(@"PUBLIC") forState:UIControlStateNormal];
    [uploadButton setTitle:LOCALIZED_STRING(@"UPLOAD NOW") forState:UIControlStateNormal];
    
    [photoTitle.layer setBorderWidth:2.f];
    [photoDescription.layer setBorderWidth:2.f];
    [photoTags.layer setBorderWidth:2.f];

    [photoTitle.layer setBorderColor:ORANGE(1.f).CGColor];
    [photoDescription.layer setBorderColor:ORANGE(1.f).CGColor];
    [photoTags.layer setBorderColor:ORANGE(1.f).CGColor];
    
    [photoDescription setContentInset:UIEdgeInsetsMake(-5.f, -5.f, 0.f, 0.f)];
    [photoTags setContentInset:UIEdgeInsetsMake(-5.f, -5.f, 0.f, 0.f)];
        
    [privateButton setUserInteractionEnabled:NO];
    [publicButton setUserInteractionEnabled:NO];
    [self setAlbumAccess:YES];

    self.photoEntry = nil;
    needAuthRequest = NO;
    
    [loadingViewController displaySpinner];
    [loadingViewController showView];
    
    NSLog(@"Asset to upload : %@", assetURLString);
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(observeGoogleAPIManagerDefaultEntryDidFinished:) name:GoogleAPIManagerDefaultEntryDidFinished object:nil];
    [[GoogleAPIManager sharedInstance] performSelector:@selector(getDefaultEntry:) withObject:assetURLString afterDelay:1.0];
    viewDidLoad = YES;
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    needsToBeUploaded = NO;
    
    if (!viewDidLoad)
    {
        if ([[GoogleAPIManager sharedInstance] isSignedIn])
            [self retrieveAlbums];
        else if(needAuthRequest)
        {
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:LOCALIZED_STRING(@"Authentication Failed")
                                                            message:LOCALIZED_STRING(@"Do you want to retry?") delegate:self
                                                  cancelButtonTitle:LOCALIZED_STRING(@"No") otherButtonTitles:LOCALIZED_STRING(@"Yes"), nil];
            [alert setTag:AUTH_ALERT_TAG];
            [alert show];
            [alert release];
        }
    }
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

- (void)goBack
{
    [[GoogleAPIManager sharedInstance] cancelAllActions];
    [self.navigationController popViewControllerAnimated:YES];
}

- (void)retrieveAlbums
{
    [plusButton setHidden:YES];
    [albumTitle setText:LOCALIZED_STRING(@"Retrieving albums...")];
    [selectAlbumButton setUserInteractionEnabled:NO];
    [spinner startAnimating];
    
    [[GoogleAPIManager sharedInstance] getPhotoAlbums:self];
}

#pragma mark - 
#pragma mark - IBActions 

- (void)selectAlbumButtonClicked
{
    shouldShowAlbumsPicker = YES;
    for (NSInteger i = 0; i < [albums count]; ++i)
        if ([[[(GDataEntryPhotoAlbum *)[albums objectAtIndex:i] title] stringValue] isEqualToString:albumTitle.text])
            [albumsPickerView selectRow:i inComponent:0 animated:NO];
    
    [albumsPickerView setShowsSelectionIndicator:YES];
    [albumTitle setInputView:albumsPickerView];
    [albumTitle setUserInteractionEnabled:YES];
    [albumTitle becomeFirstResponder];
}

- (void)privateButtonClicked
{
    [self setAlbumAccess:YES];
}

- (void)publicButtonClicked
{
    [self setAlbumAccess:NO];
}

- (void)uploadButtonClicked:(id)sender
{
    GDataMediaGroup *mediaGroup = [(GDataEntryPhoto *)[photoEntry entry] mediaGroup];
    
    GDataMediaTitle *title = [GDataMediaTitle textConstructWithString:photoTitle.text];
    GDataMediaKeywords *keywords = [GDataMediaKeywords keywordsWithString:photoTags.text];
    GDataMediaDescription *desc = [GDataMediaDescription textConstructWithString:photoDescription.text];
    
    [(GDataEntryPhoto *)[photoEntry entry] setTitle:title];
    [(GDataEntryPhoto *)[photoEntry entry] setPhotoDescription:desc];
    
    [mediaGroup setMediaTitle:title];
    [mediaGroup setMediaKeywords:keywords];
    [mediaGroup setMediaDescription:desc];
    [(GDataEntryPhoto *)[photoEntry entry] setMediaGroup:mediaGroup];
    
    if ([albums count] != 0)
    {      
        needsToBeUploaded = NO;
        [[GoogleAPIManager sharedInstance] uploadPhoto:self album:[albums objectAtIndex:[albumsPickerView selectedRowInComponent:0]] entry:photoEntry];
        [loadingViewController setLoadingText:LOCALIZED_STRING(@"UPLOADING...")];
        [loadingViewController displayProgressBar];
        [loadingViewController showView];
    }
    else // There is no album for Picasa user account
    {
        needsToBeUploaded = YES;
        [[GoogleAPIManager sharedInstance] createAlbum:self title:LOCALIZED_STRING(@"AR.Drone album") private:newAlbumAccess];
        [loadingViewController setLoadingText:LOCALIZED_STRING(@"CREATING ALBUM...")];
        [loadingViewController displaySpinner];
        [loadingViewController showView];
    }
}

- (IBAction)plusButtonClicked:(id)sender
{
    [albumTitle setUserInteractionEnabled:YES];
    [albumTitle becomeFirstResponder];
    [albumTitle setPlaceholder:@"New Album"];
}

- (BOOL)isAlbumNameCorrect:(NSString *)albumName
{
    BOOL retVal = YES;
    // Max length for album title in Picasa
    if (albumName.length > 100) retVal = NO;
    return retVal;
}

- (void)createNewAlbum
{
    [privateButton setUserInteractionEnabled:NO];
    [publicButton setUserInteractionEnabled:NO];
    
    [self hideKeyboard];
    if (albumTitle.text.length == 0) 
    {
        if ([albums count] != 0)
        {
            [albumTitle setText:[[(GDataEntryPhotoAlbum *)[albums objectAtIndex:[albumsPickerView selectedRowInComponent:0]] title] stringValue]];
            NSString *access = [(GDataEntryPhotoAlbum *)[albums objectAtIndex:[albumsPickerView selectedRowInComponent:0]] access];
            [self setAlbumAccess:([access compare:kGDataPhotoAccessPublic] != NSOrderedSame)];
        }
        else
            [albumTitle setText:LOCALIZED_STRING(@"AR.Drone album")];
    }
    else
    {
        if ([self isAlbumNameCorrect:albumTitle.text])
        {
            [[GoogleAPIManager sharedInstance] createAlbum:self title:albumTitle.text private:newAlbumAccess];
            [loadingViewController setLoadingText:LOCALIZED_STRING(@"CREATING ALBUM...")];
            [loadingViewController displaySpinner];
            [loadingViewController showView];
        }
        else
        {
            UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:LOCALIZED_STRING(@"Incorrect album title") 
                                                                message:LOCALIZED_STRING(@"Album title should not be longer than 100 characters") delegate:nil 
                                                      cancelButtonTitle:@"OK" otherButtonTitles:nil, nil];
            [alertView show];
            [alertView release];
        }
    }
}

#pragma mark - 
#pragma mark - UIAlerViewDelegate

- (void) alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (alertView.tag == AUTH_ALERT_TAG)
    {
        if (buttonIndex == 0)
            [self goBack];
        else
            [self doSignIn];
    }
    else if (alertView.tag == UNKNOWN_USER_ERROR_CODE)
    {
        [self goBack];        
    }
}

#pragma mark - 
#pragma mark - GoogleAPIManager Delegate

- (void)albumCreated
{
    [loadingViewController hideView];
    [self retrieveAlbums];
}

- (void)googleAPIManagerCreateAlbumDidFinish:(GoogleAPIManager *)googleAPIManager error:(NSError *)error
{
    if (error == nil)
        [loadingViewController setLoadingText:LOCALIZED_STRING(@"ALBUM CREATED!")];
    else
        [loadingViewController setLoadingText:LOCALIZED_STRING(@"FAILED TO CREATE ALBUM!")];

    [self performSelector:@selector(albumCreated) withObject:nil afterDelay:LOADING_TIMEOUT];
}

- (void)googleAPIManagerGetAlbumsDidFinish:(GoogleAPIManager *)googleAPIManager albums:(NSArray *)_albums error:(NSError *)error
{
    [albums removeAllObjects];
    [albumTitle setText:LOCALIZED_STRING(@"AR.Drone album")];
        
    if (error != nil)
    {
        [loadingViewController setLoadingText:LOCALIZED_STRING(@"FAILED TO RETRIEVE ALBUM!")];
        if ([error code] == UNKNOWN_USER_ERROR_CODE)
        {
            UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:LOCALIZED_STRING(@"Cannot Retrieve Album")
                                                                message:LOCALIZED_STRING(@"Unknown user. Please finalize your account creation on https://picasaweb.google.com.") 
                                                               delegate:self 
                                                      cancelButtonTitle:@"OK" otherButtonTitles:nil, nil];
            [alertView setTag:UNKNOWN_USER_ERROR_CODE];
            [alertView show];
            [alertView release];
        }
    }
    else
    {
        if ([_albums count] != 0)
        {
            [selectAlbumButton setUserInteractionEnabled:YES];
            [albums addObjectsFromArray:_albums];
            [self initAlbumsPickerView];
            [albumTitle setText:[[(GDataEntryPhotoAlbum *)[albums objectAtIndex:[albumsPickerView selectedRowInComponent:0]] title] stringValue]];
            NSString *access = [(GDataEntryPhotoAlbum *)[albums objectAtIndex:[albumsPickerView selectedRowInComponent:0]] access];
            [self setAlbumAccess:([access compare:kGDataPhotoAccessPublic] != NSOrderedSame)];
        }
        [plusButton setHidden:NO];
    }

    [loadingViewController hideView];
    [spinner stopAnimating];
    [uploadButton setHidden:NO];
    
    if (error == nil && needsToBeUploaded) [self uploadButtonClicked:nil];
}

// upload callback
- (void)uploadFinishedWithSuccess:(NSNumber *)success
{
    [loadingViewController hideView];
    
    if ([success boolValue])
        [self goBack];
}

- (void)googleAPIManagerPhotoUploadDidFinish:(GoogleAPIManager *)googleAPIManager entry:(GDataEntryPhoto *)entry error:(NSError *)error
{
    if (error == nil)
        [loadingViewController setLoadingText:LOCALIZED_STRING(@"PHOTO UPLOADED!")];
    else
        [loadingViewController setLoadingText:LOCALIZED_STRING(@"FAILED TO UPLOAD PHOTO!")];

    [self performSelector:@selector(uploadFinishedWithSuccess:) withObject:[NSNumber numberWithBool:(error == nil)] afterDelay:LOADING_TIMEOUT];
}

- (void)googleAPIManagerUploadDidProgress:(GoogleAPIManager *)googleAPIManager percentValue:(float)percent
{
    [loadingViewController setProgressBarValue:percent];
}


#pragma mark - 
#pragma mark - UIPickerViewDelegate

- (void)setAlbumTitleAndAccess
{
    [albumTitle setText:[[(GDataEntryPhotoAlbum *)[albums objectAtIndex:[albumsPickerView selectedRowInComponent:0]] title] stringValue]];
    NSString *access = [(GDataEntryPhotoAlbum *)[albums objectAtIndex:[albumsPickerView selectedRowInComponent:0]] access];
    [self setAlbumAccess:([access compare:kGDataPhotoAccessPublic] != NSOrderedSame)];
    [self hideKeyboard];
}

// Albums getter callback
- (void)initAlbumsPickerView
{
    NSMutableArray *albumsArray = [[NSMutableArray alloc] initWithCapacity:[albums count]];
    for (int idx = 0 ; idx < [albums count] ; ++idx)
        [albumsArray addObject:[[(GDataEntryBase *)[albums objectAtIndex:idx] title] stringValue]];
    
    albumsPickerView = [[ARPickerViewController alloc] initWithArrayOfArrays:[NSArray arrayWithObject:albumsArray]];
    [albumsPickerView setShowsSelectionIndicator:NO];
    [albumsArray release];
}

#pragma mark - 
#pragma mark - UITextFieldDelegate

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
    shouldShowAlbumsPicker = NO;
    [activeTextView resignFirstResponder];
    [activeTextView setUserInteractionEnabled:NO];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    [self hideKeyboard];
    if (activeTextView == albumTitle)
        [self createNewAlbum];
    
    return YES;
}

- (BOOL)textFieldShouldBeginEditing:(UITextField *)textField
{
    activeTextView = textField;
    [[toolbar doneButton] setAction:@selector(hideKeyboard)];
    
    if (activeTextView == albumTitle)
    {
        if (!shouldShowAlbumsPicker)
        {
            [self keyboardWillShow:OFFSET_Y2];
            [textField setInputView:nil];
            [textField setText:@""];
            
            [privateButton setUserInteractionEnabled:YES];
            [publicButton setUserInteractionEnabled:YES];
            
            [[toolbar doneButton] setAction:@selector(createNewAlbum)];
        }
        else
            [[toolbar doneButton] setAction:@selector(setAlbumTitleAndAccess)];
    }
    
    [textField setInputAccessoryView:toolbar];
    return YES;
}

#pragma mark - 
#pragma mark - UITextViewDelegate

- (BOOL)textViewShouldBeginEditing:(UITextView *)textView
{
    activeTextView = textView;
    
    if (textView == photoDescription)
        [self keyboardWillShow:OFFSET_Y];
    else if (textView == photoTags)
        [self keyboardWillShow:OFFSET_Y2];
        
    [[toolbar doneButton] setAction:@selector(hideKeyboard)];
    [textView setInputAccessoryView:toolbar];
    return YES;
}

#pragma mark - 
#pragma mark - ARLoadingViewController delegate

- (void)loadingViewControllerCancelButtonClicked:(ARLoadingViewController *)loadingViewController
{
    [[GoogleAPIManager sharedInstance] cancelAllActions];
}

@end
