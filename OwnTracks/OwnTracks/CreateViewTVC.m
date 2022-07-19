//
//  CreateViewTVC.m
//  OwnTracks
//
//  Created by Christoph Krey on 18.07.22.
//  Copyright © 2022 OwnTracks. All rights reserved.
//

#import "CreateViewTVC.h"
#import "CoreData.h"
#import "Settings.h"
#import "OwnTracksAppDelegate.h"
#import "Friend+CoreDataClass.h"

@interface CreateViewTVC ()
@property (weak, nonatomic) IBOutlet UITextField *label;
@property (weak, nonatomic) IBOutlet UIDatePicker *from;
@property (weak, nonatomic) IBOutlet UIDatePicker *to;

@end

@implementation CreateViewTVC

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;
    
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    self.label.text = @"my share";
    self.from.date = [NSDate now];
    self.to.date = [self.from.date dateByAddingTimeInterval:3600.0];
}

- (IBAction)savePressed:(UIBarButtonItem *)sender {
    NSLog(@"save %@, %@, %@",
          self.label.text,
          self.from.description,
          self.to.description);
    
    NSManagedObjectContext *moc = [CoreData sharedInstance].mainMOC;
    NSString *topic = [Settings theGeneralTopicInMOC:moc];
    Friend *myself = [Friend existsFriendWithTopic:topic
                            inManagedObjectContext:moc];
    
    NSDictionary *json = @{
        @"_type": @"request",
        @"request": @"share",
        @"from":  [NSISO8601DateFormatter stringFromDate:self.from.date
                                                timeZone:[NSTimeZone timeZoneWithName:@"GMT"] formatOptions:NSISO8601DateFormatWithInternetDateTime],
        @"to": [NSISO8601DateFormatter stringFromDate:self.to.date
                                             timeZone:[NSTimeZone timeZoneWithName:@"GMT"] formatOptions:NSISO8601DateFormatWithInternetDateTime],
        @"label": self.label.text,
        @"identifier": @(trunc([[NSDate now] timeIntervalSince1970]))
    };
    
    OwnTracksAppDelegate *ad = (OwnTracksAppDelegate *)[UIApplication sharedApplication].delegate;
    [ad.connection sendData:[NSJSONSerialization dataWithJSONObject:json
                                                            options:NSJSONWritingSortedKeys
                                                              error:nil]
                        topic:[[Settings theGeneralTopicInMOC:moc] stringByAppendingString:@"/request"]
                   topicAlias:@(0)
                          qos:[Settings intForKey:@"qos_preference"
                                            inMOC:moc]
                       retain:NO];
}
@end
