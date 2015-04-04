//
//  TodayViewController.m
//  OwnTracksToday
//
//  Created by Christoph Krey on 02.04.15.
//  Copyright (c) 2015 OwnTracks. All rights reserved.
//

#import "TodayViewController.h"
#import <NotificationCenter/NotificationCenter.h>
#import <CoreLocation/CoreLocation.h>

@interface TodayViewController () <NCWidgetProviding>
@property (weak, nonatomic) IBOutlet UITableView *tableView;
@property (strong, nonatomic) NSDictionary *sharedFriends;
@property (nonatomic) int mode;

@end

@implementation TodayViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.mode = 0;
}

- (CGSize)preferredContentSize {
    CGSize size = CGSizeMake(320, 44*4);
    return size;
}

- (void)widgetPerformUpdateWithCompletionHandler:(void (^)(NCUpdateResult))completionHandler {
    NSUserDefaults *shared = [[NSUserDefaults alloc] initWithSuiteName:@"group.org.owntracks.Owntracks"];
    self.sharedFriends = [shared valueForKey:@"sharedFriends"];
    NSLog(@"sharedFriends: %@", self.sharedFriends);
    [self.tableView reloadData];

    completionHandler(NCUpdateResultNewData);
}

- (UIEdgeInsets)widgetMarginInsetsForProposedMarginInsets:(UIEdgeInsets)defaultMarginInsets {
    UIEdgeInsets edgeInsets = UIEdgeInsetsMake(0, 8, 0, 8);
    return edgeInsets;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.sharedFriends.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"sharedFriend" forIndexPath:indexPath];
    
    NSString *name = [self.sharedFriends allKeys][indexPath.row];
    NSDictionary *friend = self.sharedFriends[name];
    cell.textLabel.text = name;
    
    switch (self.mode) {
        default:
        case 0: {
            double distance = [friend[@"distance"] doubleValue];
            cell.detailTextLabel.text = [NSString stringWithFormat:@"%0.f km", distance / 1000.0];
            break;
        }
        case 1: {
            NSDate *timestamp = friend[@"timestamp"];
            NSTimeInterval interval = -[timestamp timeIntervalSinceNow];
            if (interval < 60) {
                cell.detailTextLabel.text = [NSString stringWithFormat:@"%0.f sec", interval];
            } else if (interval < 3600) {
                cell.detailTextLabel.text = [NSString stringWithFormat:@"%0.f min", interval / 60];
            } else if (interval < 24 * 3600) {
                cell.detailTextLabel.text = [NSString stringWithFormat:@"%0.f h", interval / 3600];
            } else {
                cell.detailTextLabel.text = [NSString stringWithFormat:@"%0.f d", interval / (24 * 3600)];
            }
            break;
        }
        case 2: {
            CLLocation *location = [[CLLocation alloc] initWithLatitude:[friend[@"latitude"] doubleValue]
                                                               longitude:[friend[@"longitude"] doubleValue]];
            CLGeocoder *geocoder = [[CLGeocoder alloc] init];
            [geocoder reverseGeocodeLocation:location completionHandler:
             ^(NSArray *placemarks, NSError *error) {
                 if ([placemarks count] > 0) {
                     CLPlacemark *placemark = placemarks[0];
                     NSString *place = [NSString stringWithFormat:@"%@ %@ %@ %@ %@ %@",
                                        [placemark isKindOfClass:[CLPlacemark class]] ?
                                        placemark.subThoroughfare ? placemark.subThoroughfare : @"-" : @"???",
                                        [placemark isKindOfClass:[CLPlacemark class]] ?
                                        placemark.thoroughfare ? placemark.thoroughfare : @"-" : @"???",
                                        [placemark isKindOfClass:[CLPlacemark class]] ?
                                        placemark.locality ? placemark.locality : @"-" : @"???",
                                        [placemark isKindOfClass:[CLPlacemark class]] ?
                                        placemark.postalCode ? placemark.postalCode : @"-": @"???",
                                        [placemark isKindOfClass:[CLPlacemark class]] ?
                                        placemark.administrativeArea ? placemark.administrativeArea : @"-" : @"???",
                                        [placemark isKindOfClass:[CLPlacemark class]] ?
                                        placemark.country ? placemark.country : @"-": @"???"];
                     cell.detailTextLabel.text = place;
                 } else {
                     cell.detailTextLabel.text = @"cannot resolve address...";
                 }
             }];
            cell.detailTextLabel.text = @"resolving...";
            break;
        }
    }
    NSData *imageData = friend[@"image"];
    if (imageData) {
        UIImage *image = [UIImage imageWithData:imageData];
        cell.imageView.image = [UIImage imageWithCGImage:image.CGImage
                                           scale:(MAX(image.size.width, image.size.height) / 44)
                                     orientation:UIImageOrientationUp];
    }
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    self.mode = (self.mode + 1) % 3;
    [tableView deselectRowAtIndexPath:indexPath animated:true];
    [tableView reloadData];
}
@end
