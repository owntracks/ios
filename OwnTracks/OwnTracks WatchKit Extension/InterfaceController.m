//
//  InterfaceController.m
//  OwnTracks WatchKit Extension
//
//  Created by Christoph Krey on 17.03.15.
//  Copyright (c) 2015 OwnTracks. All rights reserved.
//

#import "InterfaceController.h"
#import "FriendRowController.h"

@interface InterfaceController()
@property (weak, nonatomic) IBOutlet WKInterfaceTable *table;

@end


@implementation InterfaceController

- (void)awakeWithContext:(id)context {
    [super awakeWithContext:context];

    // Configure interface objects here.
}

- (void)willActivate {
    // This method is called when watch view controller is about to be visible to user
    [super willActivate];
    
    NSUserDefaults *mySharedDefaults = [[NSUserDefaults alloc] initWithSuiteName: @"group.org.owntracks.Owntracks"];
    
    NSDictionary *closeFriends = [mySharedDefaults objectForKey:@"closeFriends"];
    [self.table setNumberOfRows:closeFriends.count withRowType:@"friend"];
    
    NSInteger rowCount = self.table.numberOfRows;
    NSArray *allKeys = closeFriends.allKeys;
        
    for (NSInteger i = 0; i < rowCount; i++) {
        NSString *name = allKeys[i];
        NSDictionary *friend = closeFriends[name];
        
        float distance = [friend[@"distance"] floatValue];
        NSString *distanceString = [NSString stringWithFormat:@"%.0f%@",
                                    distance > 1000 ? distance / 1000 : distance,
                                    distance > 1000 ? @"km" : @"m"];
        
        float interval = -[friend[@"interval"] floatValue];
        NSString *intervalString = [NSString stringWithFormat:@"%.0f%@",
                                    interval > 3600 ? interval / 3600 : interval > 60 ? interval / 60 : interval,
                                    interval > 3600 ? @"hours" : interval > 60 ? @"min" : @"sec"];
        
        NSString* detailText = [NSString stringWithFormat:@"%@\n%@ %@",
                                name,
                                distanceString,
                                intervalString];
        
        FriendRowController *friendRowController = [self.table rowControllerAtIndex:i];
        [friendRowController.label setText:detailText];
    }
}

- (void)didDeactivate {
    // This method is called when watch view controller is no longer visible
    [super didDeactivate];
}

@end



