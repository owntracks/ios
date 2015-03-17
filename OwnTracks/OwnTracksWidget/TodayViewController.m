//
//  TodayViewController.m
//  OwnTracksWidget
//
//  Created by Christoph Krey on 17.03.15.
//  Copyright (c) 2015 OwnTracks. All rights reserved.
//

#import "TodayViewController.h"
#import <NotificationCenter/NotificationCenter.h>
#import "CoreData.h"
#import "Friend+Create.h"

@interface TodayViewController () <NCWidgetProviding>
@property (weak, nonatomic) IBOutlet UILabel *label;


@end

@implementation TodayViewController

- (void)viewDidLoad {
    [super viewDidLoad];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)widgetPerformUpdateWithCompletionHandler:(void (^)(NCUpdateResult))completionHandler {
    // Perform any setup necessary in order to update the view.
    
    // If an error is encountered, use NCUpdateResultFailed
    // If there's no update required, use NCUpdateResultNoData
    // If there's an update, use NCUpdateResultNewData
    
    NSUserDefaults *mySharedDefaults = [[NSUserDefaults alloc] initWithSuiteName: @"group.org.owntracks.Owntracks"];

    NSDictionary *closeFriends = [mySharedDefaults objectForKey:@"closeFriends"];
    NSString *string = @"";
    for (NSString *name in closeFriends.allKeys) {
        NSDictionary *friend = closeFriends[name];
        
        float distance = [friend[@"distance"] floatValue];
        NSString *distanceString = [NSString stringWithFormat:@"%.0f%@",
                                    distance > 1000 ? distance / 1000 : distance,
                                    distance > 1000 ? @"km" : @"m"];
        
        float interval = -[friend[@"interval"] floatValue];
        NSString *intervalString = [NSString stringWithFormat:@"%.0f%@",
                                          interval > 3600 ? interval / 3600 : interval > 60 ? interval / 60 : interval,
                                          interval > 3600 ? @"hours" : interval > 60 ? @"min" : @"sec"];
        
        string = [string stringByAppendingFormat:@"%@ %@ %@\n",
                  name,
                  distanceString,
                  intervalString];
    }
    self.label.text = string;

    completionHandler(NCUpdateResultNewData);
}

- (IBAction)tapped:(UITapGestureRecognizer *)sender {
    [self.extensionContext openURL:[NSURL URLWithString:@"owntracks://"] completionHandler:^(BOOL success) {
       //
    }];
}

@end
