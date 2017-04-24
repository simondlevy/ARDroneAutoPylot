//
//  ARStatusBarViewController.m
//  FreeFlight
//
//  Created by Nicolas Payot on 07/10/11.
//  Copyright 2011 PARROT. All rights reserved.
//

#import "ARStatusBarViewController.h"
#import "Common.h"

@implementation ARStatusBarViewController
@synthesize delegate = _delegate;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    NSMutableString *nibName = [NSMutableString stringWithString:nibNameOrNil];
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
        [nibName appendString:@"-iPad"];
    
    self = [super initWithNibName:nibName bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)dealloc
{
    [batteryIcon release];
    [batteryLabel release];
    [timeLabel release];
    [settingsIcon release];
    [settingsButton release];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
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
    
    [settingsButton setTitle:LOCALIZED_STRING(@"PREFERENCES") forState:UIControlStateNormal];
    [[UIDevice currentDevice] setBatteryMonitoringEnabled:YES];
    [self updateBatteryLevel];
    // Add observer on batteryLevel changes
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateBatteryLevel) name:UIDeviceBatteryLevelDidChangeNotification object:nil];
    
    [self updateWatch];
    
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:[NSString stringWithFormat:@"ss"]];
    CGFloat n = [[dateFormatter stringFromDate:[NSDate date]] floatValue];
    [dateFormatter release];
    [self performSelector:@selector(startWatchTimer) withObject:nil afterDelay:(60 - n)];
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

- (void)updateBatteryLevel
{
    NSInteger val = (NSInteger)floorf([[UIDevice currentDevice] batteryLevel] * 100);
    
    if (val == 0)
        [batteryIcon setImage:[UIImage imageNamed:@"ff2.0_battery_000.png"]];
    else if (val <= 20)
        [batteryIcon setImage:[UIImage imageNamed:@"ff2.0_battery_020.png"]];
    else if (val <= 40)
        [batteryIcon setImage:[UIImage imageNamed:@"ff2.0_battery_040.png"]];
    else if (val <= 60)
        [batteryIcon setImage:[UIImage imageNamed:@"ff2.0_battery_060.png"]];
    else if (val <= 80)
        [batteryIcon setImage:[UIImage imageNamed:@"ff2.0_battery_080.png"]];
    else // val <= 100
        [batteryIcon setImage:[UIImage imageNamed:@"ff2.0_battery_100.png"]];

    [batteryLabel setText:[NSString stringWithFormat:@"%.0f%%", [[UIDevice currentDevice] batteryLevel] * 100]];
}

- (void)centersTime
{
    [timeLabel sizeToFit];
    
    CGRect frame = timeIcon.frame;
    frame.origin.x = (self.view.frame.size.width - (frame.size.width + 4.f + timeLabel.frame.size.width)) / 2.f;
    [timeIcon setFrame:frame];
    
    frame = timeLabel.frame;
    frame.origin.x = timeIcon.frame.origin.x + timeIcon.frame.size.width + 4.f;
    frame.origin.y = (self.view.frame.size.height - frame.size.height) / 2.f;
    [timeLabel setFrame:frame];
}

- (void)startWatchTimer
{
    [self updateWatch];
    [NSTimer scheduledTimerWithTimeInterval:60.f target:self selector:@selector(updateWatch) userInfo:nil repeats:YES];
}

- (void)updateWatch
{
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setFormatterBehavior:NSDateFormatterBehavior10_4];
    [formatter setDateStyle:NSDateFormatterNoStyle];
    [formatter setTimeStyle:NSDateFormatterShortStyle];
    [timeLabel setText:[formatter stringForObjectValue:[NSDate date]]];
    [self centersTime];
    [formatter release];
}

- (void)openSettings
{
    if([self.delegate respondsToSelector:@selector(statusBarPreferencesClicked:)])
        [self.delegate statusBarPreferencesClicked:self];
}

@end
