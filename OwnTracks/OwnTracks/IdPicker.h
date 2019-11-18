//
//  IdPicker.h
//  OwnTracks
//
//  Created by Christoph Krey on 18.02.15.
//  Copyright (c) 2015-2019 Christoph Krey. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface IdPicker : UITextField<UIPickerViewDataSource,UIPickerViewDelegate>
@property (strong, nonatomic) NSArray <NSDictionary *> *array;
@property (nonatomic) int arrayId;

@end
