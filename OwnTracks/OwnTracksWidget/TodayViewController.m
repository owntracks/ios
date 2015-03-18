//
//  TodayViewController.m
//  OwnTracksWidget
//
//  Created by Christoph Krey on 17.03.15.
//  Copyright (c) 2015 OwnTracks. All rights reserved.
//

#import "TodayViewController.h"
#import <NotificationCenter/NotificationCenter.h>
#import <CoreLocation/CoreLocation.h>
#import "CoreData.h"
#import "Friend+Create.h"

@interface TodayViewController () <NCWidgetProviding>
@property (weak, nonatomic) IBOutlet UITableView *tableView;
@property (nonatomic) int displayMode;
@property (strong, nonatomic) NSMutableDictionary *revGeo;
@property (strong, nonatomic) NSUserDefaults *mySharedDefaults;

@end

@implementation TodayViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.displayMode = 0;
    self.mySharedDefaults = [[NSUserDefaults alloc] initWithSuiteName: @"group.org.owntracks.Owntracks"];
    self.revGeo = [[NSMutableDictionary alloc] init];
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
}

- (void)widgetPerformUpdateWithCompletionHandler:(void (^)(NCUpdateResult))completionHandler {
    self.preferredContentSize = CGSizeMake(320, 200);
    self.revGeo = [[NSMutableDictionary alloc] init];
    [self.tableView reloadData];
    completionHandler(NCUpdateResultNewData);
}


- (IBAction)tapped:(UITapGestureRecognizer *)sender {
    self.displayMode = (self.displayMode + 1) % 3;
    [self.tableView reloadData];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    NSDictionary *closeFriends = [self.mySharedDefaults objectForKey:@"closeFriends"];
    return closeFriends.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"friend" forIndexPath:indexPath];
    NSDictionary *closeFriends = [self.mySharedDefaults objectForKey:@"closeFriends"];
    NSString *name = closeFriends.allKeys[indexPath.row];
    cell.textLabel.text = name;
    
    NSDictionary *friend = closeFriends[name];
    switch (self.displayMode) {
        case 0: {
            float interval = -[friend[@"interval"] floatValue];
            cell.detailTextLabel.text = [NSString stringWithFormat:@"%.0f %@",
                                         interval > 3600 ? interval / 3600 : interval > 60 ? interval / 60 : interval,
                                         interval > 3600 ? @"h" : interval > 60 ? @"min" : @"s"];
            break;
        }
        case 1: {
            float distance = [friend[@"distance"] floatValue];
            cell.detailTextLabel.text = [NSString stringWithFormat:@"%.0f %@",
                                         distance > 1000 ? distance / 1000 : distance,
                                         distance > 1000 ? @"km" : @"m"];
            break;
        }
        case 2: {
            NSString *addressString = self.revGeo[name];
            if (addressString) {
                cell.detailTextLabel.text = addressString;
            } else {
                cell.detailTextLabel.text = @"reverse Geocoding...";
                double latitude = [friend[@"latitude"] doubleValue];
                double longitude = [friend[@"longitude"] doubleValue];
                CLGeocoder *geocoder = [[CLGeocoder alloc] init];
                CLLocation *location = [[CLLocation alloc] initWithLatitude:latitude longitude:longitude];
                [geocoder reverseGeocodeLocation:location completionHandler:
                 ^(NSArray *placemarks, NSError *error) {
                     if ([placemarks count] > 0) {
                         CLPlacemark *placemark = placemarks[0];
                         NSArray *address = placemark.addressDictionary[@"FormattedAddressLines"];
                         if (address && [address count] >= 1) {
                             NSString *addressString = address[0];
                             for (int i = 1; i < [address count]; i++) {
                                 addressString = [addressString stringByAppendingFormat:@",%@", address[i]];
                             }
                             [self.revGeo setObject:addressString forKey:name];
                         }
                     } else {
                         [self.revGeo setObject:@"no reverse Geocode" forKey:name];
                     }
                     [self.tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
                 }];
            }
            break;
        }
        default:
            break;
    }
    return cell;
}

@end
