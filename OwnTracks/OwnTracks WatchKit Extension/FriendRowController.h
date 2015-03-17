//
//  FriendRowController.h
//  OwnTracks
//
//  Created by Christoph Krey on 17.03.15.
//  Copyright (c) 2015 OwnTracks. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <WatchKit/WatchKit.h>

@interface FriendRowController : NSObject
@property (weak, nonatomic) IBOutlet WKInterfaceLabel *label;
@property (weak, nonatomic) IBOutlet WKInterfaceLabel *detail;

@end
