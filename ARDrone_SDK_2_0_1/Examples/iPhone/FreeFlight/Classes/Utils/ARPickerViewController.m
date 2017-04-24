//
//  ARPickerViewController.m
//  ARDroneAcademy
//
//  Created by Nicolas Payot on 03/05/11.
//  Copyright 2011 PARROT. All rights reserved.
//

#import "ARPickerViewController.h"


@implementation ARPickerViewController

@synthesize dataSourceArrays;
@synthesize selectedRow;

- (id)initWithArrayOfArrays:(NSArray *)arrays
{
    self = [super init];
    if (self != nil)
    {
        [self setShowsSelectionIndicator:YES];
        [self sizeToFit];
        [self setAutoresizingMask:(UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight)];
        self.dataSourceArrays = [NSArray arrayWithArray:arrays];
        [self setDelegate:self];
        [self setDataSource:self];
    }
    return self;
}

- (void)dealloc
{
    [dataSourceArrays release];
    [selectedRow release];
    [self setDelegate:nil];
    [self setDataSource:nil];
    [super dealloc];
}

// Specifies how many columns should be display
- (NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView
{
    return [dataSourceArrays count];
}

// Specifies how many rows countries picker view should display
- (NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component
{    
    return ([dataSourceArrays objectAtIndex:component] != nil ? [[dataSourceArrays objectAtIndex:component] count] : 0);
}

// Called n number of times, where n is the number returned by numberOfRowsInComponent
- (NSString *)pickerView:(UIPickerView *)pickerView titleForRow:(NSInteger)row forComponent:(NSInteger)component
{
    return ([dataSourceArrays objectAtIndex:component] != nil ? [[dataSourceArrays objectAtIndex:component] objectAtIndex:row] : nil);
}

// A row was selected
- (void)pickerView:(UIPickerView *)pickerView didSelectRow:(NSInteger)row inComponent:(NSInteger)component
{
    self.selectedRow = ([dataSourceArrays objectAtIndex:component] != nil ? [[dataSourceArrays objectAtIndex:component] objectAtIndex:row] : nil);
}

@end
