//
//  IdPicker.m
//  OwnTracks
//
//  Created by Christoph Krey on 18.02.15.
//  Copyright (c) 2015-2021 Christoph Krey. All rights reserved.
//

#import "IdPicker.h"

@interface IdPicker()
@property (strong, nonatomic) UIPickerView *pickerView;
@property (nonatomic) NSUInteger maxLines;

@end

@implementation IdPicker

- (void)initialize {
    self.pickerView = [[UIPickerView alloc] init];
    (self.pickerView).autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
    self.pickerView.delegate = self;
    self.pickerView.dataSource = self;
    self.inputView = self.pickerView;

    UIBarButtonItem *doneButton = [[UIBarButtonItem alloc]
                                   initWithTitle:NSLocalizedString(@"Done", @"Done")
                                   style:UIBarButtonItemStyleDone
                                   target:self action:@selector(done:)];
    UIBarButtonItem *flexibleSpace = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace
                                                                                   target:nil
                                                                                   action:nil];
    UIToolbar *toolBar = [[UIToolbar alloc]initWithFrame:
                          CGRectMake(0, self.frame.size.height-50, self.frame.size.width, 50)];
    NSArray *toolbarItems = @[flexibleSpace, doneButton];
    toolBar.items = toolbarItems;
    self.inputAccessoryView = toolBar;
}

- (void)done:(UIBarButtonItem *)button {
    [self resignFirstResponder];
}

- (void)setArrayId:(int)arrayId {
    _arrayId = arrayId;
        for (int i = 0; i < self.array.count; i++) {
            NSDictionary *item = self.array[i];
            if ([item valueForKey:@"identifier"]) {
                int identifier = [item[@"identifier"] intValue];
                if (identifier == self.arrayId) {
                    [self.pickerView selectRow:i inComponent:0 animated:FALSE];
                    if ([self.array[i] valueForKey:@"name"]) {
                        self.text = self.array[i][@"name"];
                    } else {
                        self.text = @"";
                    }
                }
            }
        }
}

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self)
    {
        [self initialize];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self)
    {
        [self initialize];
    }
    return self;
}

- (NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView {
    return 1;
}

- (NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component {
    NSInteger count = 0;

    for (NSDictionary *item in self.array) {
        if (![[item valueForKey:@"hidden"] boolValue]) {
            count++;
        }
    }
    return count;
}

- (CGFloat)pickerView:(UIPickerView *)pickerView rowHeightForComponent:(NSInteger)component {
    int height = 33;
    for (NSDictionary *item in self.array) {
        if (![[item valueForKey:@"hidden"] boolValue] &&
            [item valueForKey:@"name"]) {
            NSString *string = item[@"name"];
            
            height = MAX(ceil(string.length / 60.0) * 33, height);
        }
    }
    return height;
}

- (UIView *)pickerView:(UIPickerView *)pickerView
            viewForRow:(NSInteger)row
          forComponent:(NSInteger)component
           reusingView:(UIView *)view {

    NSMutableArray <NSString *> *nonHiddenRows = [[NSMutableArray alloc] init];
    for (NSDictionary *item in self.array) {
        if (![[item valueForKey:@"hidden"] boolValue]) {
            NSString *string ;
            if ([item valueForKey:@"name"]) {
                string = item[@"name"];
            } else {
                string = @"...";
            }
            [nonHiddenRows addObject:string];
        }
    }

    UILabel *label = [[UILabel alloc] init];
    label.textAlignment = NSTextAlignmentCenter;
    label.text = nonHiddenRows[row];
    return label;
}

- (void)pickerView:(UIPickerView *)pickerView didSelectRow:(NSInteger)row inComponent:(NSInteger)component {
    if ([self.array[row] valueForKey:@"identifier"]) {
        self.arrayId = [self.array[row][@"identifier"] intValue];
    } else {
        self.arrayId = 0;
    }
    [self sendActionsForControlEvents:UIControlEventValueChanged];
}

@end
