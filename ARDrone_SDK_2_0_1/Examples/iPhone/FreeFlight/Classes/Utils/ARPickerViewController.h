//
//  ARPickerViewController.h
//  ARDroneAcademy
//
//  Created by Nicolas Payot on 03/05/11.
//  Copyright 2011 PARROT. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface ARPickerViewController : UIPickerView <UIPickerViewDataSource, UIPickerViewDelegate> {
    NSArray *dataSourceArrays;
    NSString *selectedRow;
}

@property (nonatomic, retain) NSArray *dataSourceArrays;
@property (nonatomic, copy) NSString *selectedRow;

- (id)initWithArrayOfArrays:(NSArray *)arrays;

@end
