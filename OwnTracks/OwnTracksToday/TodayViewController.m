//
//  TodayViewController.m
//  OwnTracksToday
//
//  Created by Christoph Krey on 02.04.15.
//  Copyright © 2015-2021  OwnTracks. All rights reserved.
//

#import "TodayViewController.h"
#import <NotificationCenter/NotificationCenter.h>
#import <CoreLocation/CoreLocation.h>

@interface TodayViewController () <NCWidgetProviding>
@property (weak, nonatomic) IBOutlet UITableView *tableView;
@property (strong, nonatomic) NSDictionary *sharedFriends;
@property (nonatomic) int mode;
@property (nonatomic) NSInteger monitoring;
@property (nonatomic) unsigned long offset;
@property (nonatomic) unsigned long page;
@property (nonatomic) CGSize maxSize;
@property (weak, nonatomic) IBOutlet UILabel *label;
@property (weak, nonatomic) IBOutlet UIButton *backward;
@property (weak, nonatomic) IBOutlet UIButton *forward;
@property (weak, nonatomic) IBOutlet UIButton *button;

@end

#define TOP 22.0
#define ROW 44.0

@implementation TodayViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.mode = 0;
    self.page = 1;
    self.offset = 0;

    [self.extensionContext setWidgetLargestAvailableDisplayMode:NCWidgetDisplayModeExpanded];
}

- (void)widgetActiveDisplayModeDidChange:(NCWidgetDisplayMode)activeDisplayMode
                         withMaximumSize:(CGSize)maxSize {
    NSLog(@"widgetActiveDisplayModeDidChange: %ld withMaximumSize %f %f",
          (long)activeDisplayMode,
          maxSize.width,
          maxSize.height);

    self.maxSize = maxSize;

    self.offset = 0;
    self.page = MAX(MIN((long)((maxSize.height - TOP) / ROW),
                        self.sharedFriends.count),
                    2);
    self.preferredContentSize = CGSizeMake(maxSize.width, self.page * ROW + TOP);
    [self.view setNeedsLayout];
    [self.view setNeedsDisplay];
}

- (void)viewDidLayoutSubviews {
    [self show];
    [self.tableView reloadData];
}

- (void)widgetPerformUpdateWithCompletionHandler:(void (^)(NCUpdateResult))completionHandler {
    NSUserDefaults *shared = [[NSUserDefaults alloc] initWithSuiteName:@"group.org.owntracks.Owntracks"];
    self.sharedFriends = [shared dictionaryForKey:@"sharedFriends"];
    NSLog(@"sharedFriends: %ld", self.sharedFriends.count);
    self.monitoring = [shared integerForKey:@"monitoring"];
    NSLog(@"monitoring: %ld", (long)self.monitoring);
    self.offset = 0;
    self.page = MAX(MIN((long)((self.maxSize.height - TOP) / ROW),
                        self.sharedFriends.count),
                    2);
    self.preferredContentSize = CGSizeMake(self.maxSize.width, self.page * ROW + TOP);
    [self.view setNeedsLayout];
    [self.view setNeedsDisplay];
    [self show];
    [self.tableView reloadData];

    completionHandler(NCUpdateResultNewData);
}

- (void)show {
    self.label.text = [NSString stringWithFormat:@"%lu - %lu / %lu",
                  MIN(self.offset + 1, self.sharedFriends.count),
                  MIN(self.offset + self.page, self.sharedFriends.count),
                  (unsigned long)self.sharedFriends.count];
    self.forward.enabled = self.sharedFriends.count > self.offset + self.page;
    self.backward.enabled = self.offset >= self.page;

    switch (self.monitoring) {
        case 0:
            [self.button setImage:[UIImage imageNamed:@"Manual"] forState:UIControlStateNormal];
            break;
        case 1:
            [self.button setImage:[UIImage imageNamed:@"Significant"] forState:UIControlStateNormal];
            break;
        case 2:
            [self.button setImage:[UIImage imageNamed:@"Move"] forState:UIControlStateNormal];
            break;
        case -1:
        default:
            [self.button setImage:[UIImage imageNamed:@"Quiet"] forState:UIControlStateNormal];
            break;
    }
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView
 numberOfRowsInSection:(NSInteger)section {
    NSInteger min = MIN(self.page, self.sharedFriends.count - self.offset);
    NSLog(@"numberOfRowsInSection %ld", (long)min);
    return min;
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"sharedFriend" forIndexPath:indexPath];
    
    NSString *name = [self.sharedFriends allKeys][indexPath.row + self.offset];
    NSDictionary *friend = self.sharedFriends[name];
    cell.textLabel.text = name;
    
    switch (self.mode) {
        default:
        case 0: {
            double distance = [friend[@"distance"] doubleValue];
            cell.detailTextLabel.text = [NSString stringWithFormat:@"%0.f%@",
                                         distance / 1000.0,
                                         NSLocalizedString(@"km",
                                                           @"short for kilometer on Today")
                                         ];
            break;
        }
        case 1: {
            NSDate *timestamp = friend[@"timestamp"];
            NSTimeInterval interval = -[timestamp timeIntervalSinceNow];
            if (interval < 60) {
                cell.detailTextLabel.text = [NSString stringWithFormat:@"%0.f%@",
                                             interval,
                                             NSLocalizedString(@"sec",
                                                               @"short for second on Today")
                                            ];
            } else if (interval < 3600) {
                cell.detailTextLabel.text = [NSString stringWithFormat:@"%0.f%@",
                                             interval / 60,
                                             NSLocalizedString(@"min",
                                                               @"short for minute on Today")
                                             ];
            } else if (interval < 24 * 3600) {
                cell.detailTextLabel.text = [NSString stringWithFormat:@"%0.f%@",
                                             interval / 3600,
                                             NSLocalizedString(@"h",
                                                               @"short for hour on Today")
                                             ];
            } else {
                cell.detailTextLabel.text = [NSString stringWithFormat:@"%0.f%@",
                                             interval / (24 * 3600),
                                             NSLocalizedString(@"d",
                                                               @"short for day on Today")
                                             ];
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
                     cell.detailTextLabel.text = NSLocalizedString(@"cannot resolve address",
                                                                   @"error message on Today");
                 }
             }];
            cell.detailTextLabel.text = NSLocalizedString(@"resolving address...",
                                                          @"temporary message on Today");

            break;
        }
    }
    NSData *imageData = friend[@"image"];
    if (imageData) {
        UIImage *image = [UIImage imageWithData:imageData];
        cell.imageView.image = [UIImage imageWithCGImage:image.CGImage
                                           scale:(MAX(image.size.width, image.size.height) / 44)
                                     orientation:UIImageOrientationUp];
    } else {
        cell.imageView.image = nil;
    }
    
    return cell;
}

- (void)tableView:(UITableView *)tableView
didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    self.mode = (self.mode + 1) % 3;
    [tableView deselectRowAtIndexPath:indexPath animated:true];
    [tableView reloadData];
}

- (IBAction)forwardPressed:(UIButton *)sender {
    self.offset += self.page;
    NSLog(@"forwardPressed %lu", (long)self.offset);

    [self show];
    [self.tableView reloadData];
}

- (IBAction)backwardPressed:(UIButton *)sender {
    self.offset -= self.page;
    NSLog(@"backwardPressed %lu", (long)self.offset);
    [self show];
    [self.tableView reloadData];
}

- (IBAction)buttonPressed:(UIButton *)sender {
    switch (self.monitoring) {
        case 0:
            self.monitoring = -1;
            break;
        case 1:
            self.monitoring = 0;
            break;
        case 2:
            self.monitoring = 1;
            break;
        case -1:
        default:
            self.monitoring = 2;
            break;
    }
    NSUserDefaults *shared = [[NSUserDefaults alloc] initWithSuiteName:@"group.org.owntracks.Owntracks"];
    [shared setInteger:self.monitoring forKey:@"monitoring"];
    [shared synchronize];
    [self show];
}
@end
