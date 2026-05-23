//
//  DashcamGridViewController.m
//  OwnTracks
//

#import "DashcamGridViewController.h"
#import "DashcamPlayerViewController.h"
#import "LocationAPISyncService.h"
#import "WebAppURLResolver.h"
#import "CoreData.h"
#import "Friend+CoreDataClass.h"
#import <CocoaLumberjack/CocoaLumberjack.h>

static const DDLogLevel ddLogLevel = DDLogLevelInfo;

/// Default lookback window when first opening the tab.
static NSTimeInterval const kDashcamDefaultWindowSeconds = 60 * 60 * 24 * 7;
/// Width threshold below which the grid collapses to 1 column.
static CGFloat const kDashcamGridMinCellWidth = 160.0;

typedef NS_ENUM(NSInteger, OTDashcamReasonFilter) {
    OTDashcamReasonFilterAll = 0,
    OTDashcamReasonFilterSentry,
    OTDashcamReasonFilterSaved,
};

@interface OTDashcamGridCell : UICollectionViewCell
@property (nonatomic, strong) UIImageView *thumbView;
@property (nonatomic, strong) UIImageView *deviceAvatarView;
@property (nonatomic, strong) UILabel *deviceLabel;
@property (nonatomic, strong) UILabel *timeLabel;
@property (nonatomic, strong) UILabel *reasonChipLabel;
@property (nonatomic, strong) UILabel *placeLabel;
@property (nonatomic, copy, nullable) NSString *currentClipId;
@end

@implementation OTDashcamGridCell

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.contentView.backgroundColor = [UIColor secondarySystemBackgroundColor];
        self.contentView.layer.cornerRadius = 12.0;
        self.contentView.layer.masksToBounds = YES;

        _thumbView = [[UIImageView alloc] init];
        _thumbView.translatesAutoresizingMaskIntoConstraints = NO;
        _thumbView.contentMode = UIViewContentModeScaleAspectFill;
        _thumbView.clipsToBounds = YES;
        _thumbView.backgroundColor = [UIColor systemGray5Color];
        _thumbView.image = [UIImage systemImageNamed:@"video"];
        _thumbView.tintColor = [UIColor tertiaryLabelColor];
        [self.contentView addSubview:_thumbView];

        _reasonChipLabel = [[UILabel alloc] init];
        _reasonChipLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _reasonChipLabel.font = [UIFont systemFontOfSize:11 weight:UIFontWeightSemibold];
        _reasonChipLabel.textColor = [UIColor whiteColor];
        _reasonChipLabel.backgroundColor = [UIColor.blackColor colorWithAlphaComponent:0.55];
        _reasonChipLabel.textAlignment = NSTextAlignmentCenter;
        _reasonChipLabel.layer.cornerRadius = 8.0;
        _reasonChipLabel.layer.masksToBounds = YES;
        [self.contentView addSubview:_reasonChipLabel];

        _deviceAvatarView = [[UIImageView alloc] init];
        _deviceAvatarView.translatesAutoresizingMaskIntoConstraints = NO;
        _deviceAvatarView.contentMode = UIViewContentModeScaleAspectFill;
        _deviceAvatarView.clipsToBounds = YES;
        _deviceAvatarView.layer.cornerRadius = 12.0;
        _deviceAvatarView.backgroundColor = [UIColor systemGray4Color];
        _deviceAvatarView.image = [UIImage systemImageNamed:@"car.fill"];
        _deviceAvatarView.tintColor = [UIColor secondaryLabelColor];
        [self.contentView addSubview:_deviceAvatarView];

        _deviceLabel = [[UILabel alloc] init];
        _deviceLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _deviceLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
        _deviceLabel.numberOfLines = 1;
        [self.contentView addSubview:_deviceLabel];

        _timeLabel = [[UILabel alloc] init];
        _timeLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _timeLabel.font = [UIFont systemFontOfSize:11 weight:UIFontWeightRegular];
        _timeLabel.textColor = [UIColor secondaryLabelColor];
        _timeLabel.numberOfLines = 1;
        [self.contentView addSubview:_timeLabel];

        _placeLabel = [[UILabel alloc] init];
        _placeLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _placeLabel.font = [UIFont systemFontOfSize:11 weight:UIFontWeightRegular];
        _placeLabel.textColor = [UIColor tertiaryLabelColor];
        _placeLabel.numberOfLines = 1;
        [self.contentView addSubview:_placeLabel];

        UIView *content = self.contentView;
        [NSLayoutConstraint activateConstraints:@[
            [_thumbView.leadingAnchor constraintEqualToAnchor:content.leadingAnchor],
            [_thumbView.trailingAnchor constraintEqualToAnchor:content.trailingAnchor],
            [_thumbView.topAnchor constraintEqualToAnchor:content.topAnchor],
            [_thumbView.heightAnchor constraintEqualToAnchor:_thumbView.widthAnchor multiplier:9.0/16.0],

            [_reasonChipLabel.trailingAnchor constraintEqualToAnchor:_thumbView.trailingAnchor constant:-8],
            [_reasonChipLabel.topAnchor constraintEqualToAnchor:_thumbView.topAnchor constant:8],
            [_reasonChipLabel.heightAnchor constraintEqualToConstant:18],

            [_deviceAvatarView.leadingAnchor constraintEqualToAnchor:content.leadingAnchor constant:8],
            [_deviceAvatarView.topAnchor constraintEqualToAnchor:_thumbView.bottomAnchor constant:8],
            [_deviceAvatarView.widthAnchor constraintEqualToConstant:24],
            [_deviceAvatarView.heightAnchor constraintEqualToConstant:24],

            [_deviceLabel.leadingAnchor constraintEqualToAnchor:_deviceAvatarView.trailingAnchor constant:6],
            [_deviceLabel.trailingAnchor constraintEqualToAnchor:content.trailingAnchor constant:-8],
            [_deviceLabel.topAnchor constraintEqualToAnchor:_deviceAvatarView.topAnchor],

            [_timeLabel.leadingAnchor constraintEqualToAnchor:_deviceLabel.leadingAnchor],
            [_timeLabel.trailingAnchor constraintEqualToAnchor:_deviceLabel.trailingAnchor],
            [_timeLabel.topAnchor constraintEqualToAnchor:_deviceLabel.bottomAnchor constant:2],

            [_placeLabel.leadingAnchor constraintEqualToAnchor:content.leadingAnchor constant:8],
            [_placeLabel.trailingAnchor constraintEqualToAnchor:content.trailingAnchor constant:-8],
            [_placeLabel.topAnchor constraintEqualToAnchor:_timeLabel.bottomAnchor constant:4],
            [_placeLabel.bottomAnchor constraintLessThanOrEqualToAnchor:content.bottomAnchor constant:-8],
        ]];

    }
    return self;
}

- (void)prepareForReuse {
    [super prepareForReuse];
    self.currentClipId = nil;
    self.thumbView.image = [UIImage systemImageNamed:@"video"];
    self.deviceAvatarView.image = [UIImage systemImageNamed:@"car.fill"];
}

@end

@interface DashcamGridViewController () <UICollectionViewDataSource, UICollectionViewDelegateFlowLayout>
@property (nonatomic, strong) UICollectionView *collectionView;
@property (nonatomic, strong) UIRefreshControl *refreshControl;
@property (nonatomic, strong) UILabel *emptyLabel;
@property (nonatomic, strong) UIActivityIndicatorView *loadingIndicator;

@property (nonatomic, strong) UIScrollView *filterScroll;
@property (nonatomic, strong) UIStackView *filterStack;

@property (nonatomic, strong) NSArray<OTWebDeviceItem *> *devices;
@property (nonatomic, strong) NSArray<OTDashcamClipItem *> *allClips;
@property (nonatomic, strong) NSArray<OTDashcamClipItem *> *visibleClips;

@property (nonatomic) OTDashcamReasonFilter reasonFilter;
/// nil = all devices, otherwise restrict to the deviceId.
@property (nonatomic, strong, nullable) NSNumber *deviceFilterId;

@property (nonatomic) NSTimeInterval windowSeconds;

@property (nonatomic, strong) NSCache<NSString *, UIImage *> *thumbCache;
@property (nonatomic, strong) NSCache<NSString *, UIImage *> *deviceImageCache;
@end

@implementation DashcamGridViewController

- (instancetype)init {
    self = [super init];
    if (self) {
        _devices = @[];
        _allClips = @[];
        _visibleClips = @[];
        _reasonFilter = OTDashcamReasonFilterAll;
        _windowSeconds = kDashcamDefaultWindowSeconds;
        _thumbCache = [[NSCache alloc] init];
        _thumbCache.countLimit = 200;
        _deviceImageCache = [[NSCache alloc] init];
        _deviceImageCache.countLimit = 64;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Dash Cam";
    self.view.backgroundColor = [UIColor systemBackgroundColor];

    self.navigationItem.rightBarButtonItems = @[
        [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh
                                                      target:self
                                                      action:@selector(reloadAll)],
        [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"calendar"]
                                          style:UIBarButtonItemStylePlain
                                         target:self
                                         action:@selector(showWindowPicker)],
    ];

    [self installFilterBar];
    [self installCollectionView];
    [self installEmptyAndLoading];
    [self updateFilterChips];

    self.refreshControl = [[UIRefreshControl alloc] init];
    [self.refreshControl addTarget:self action:@selector(reloadAll) forControlEvents:UIControlEventValueChanged];
    self.collectionView.refreshControl = self.refreshControl;
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    if (self.allClips.count == 0 && !self.loadingIndicator.isAnimating) {
        [self reloadAll];
    }
}

#pragma mark - View setup

- (void)installFilterBar {
    UIScrollView *scroll = [[UIScrollView alloc] init];
    scroll.translatesAutoresizingMaskIntoConstraints = NO;
    scroll.showsHorizontalScrollIndicator = NO;
    scroll.alwaysBounceHorizontal = YES;
    [self.view addSubview:scroll];

    UIStackView *stack = [[UIStackView alloc] init];
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    stack.axis = UILayoutConstraintAxisHorizontal;
    stack.spacing = 8.0;
    [scroll addSubview:stack];

    UILayoutGuide *safe = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [scroll.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor],
        [scroll.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor],
        [scroll.topAnchor constraintEqualToAnchor:safe.topAnchor],
        [scroll.heightAnchor constraintEqualToConstant:44],

        [stack.leadingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.leadingAnchor constant:12],
        [stack.trailingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.trailingAnchor constant:-12],
        [stack.topAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.topAnchor constant:6],
        [stack.bottomAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.bottomAnchor constant:-6],
        [stack.heightAnchor constraintEqualToAnchor:scroll.frameLayoutGuide.heightAnchor constant:-12],
    ]];

    self.filterScroll = scroll;
    self.filterStack = stack;
}

- (void)installCollectionView {
    UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
    layout.minimumInteritemSpacing = 10.0;
    layout.minimumLineSpacing = 10.0;
    layout.sectionInset = UIEdgeInsetsMake(10, 10, 10, 10);
    layout.scrollDirection = UICollectionViewScrollDirectionVertical;

    UICollectionView *cv = [[UICollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:layout];
    cv.translatesAutoresizingMaskIntoConstraints = NO;
    cv.backgroundColor = [UIColor systemBackgroundColor];
    cv.alwaysBounceVertical = YES;
    cv.dataSource = self;
    cv.delegate = self;
    [cv registerClass:[OTDashcamGridCell class] forCellWithReuseIdentifier:@"OTDashcamGridCell"];
    [self.view addSubview:cv];

    UILayoutGuide *safe = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [cv.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor],
        [cv.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor],
        [cv.topAnchor constraintEqualToAnchor:self.filterScroll.bottomAnchor],
        [cv.bottomAnchor constraintEqualToAnchor:safe.bottomAnchor],
    ]];
    self.collectionView = cv;
}

- (void)installEmptyAndLoading {
    UILabel *empty = [[UILabel alloc] init];
    empty.translatesAutoresizingMaskIntoConstraints = NO;
    empty.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
    empty.textColor = [UIColor secondaryLabelColor];
    empty.textAlignment = NSTextAlignmentCenter;
    empty.numberOfLines = 0;
    empty.hidden = YES;
    [self.view addSubview:empty];
    self.emptyLabel = empty;

    UIActivityIndicatorView *spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    spinner.translatesAutoresizingMaskIntoConstraints = NO;
    spinner.hidesWhenStopped = YES;
    [self.view addSubview:spinner];
    self.loadingIndicator = spinner;

    [NSLayoutConstraint activateConstraints:@[
        [empty.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [empty.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor],
        [empty.leadingAnchor constraintGreaterThanOrEqualToAnchor:self.view.leadingAnchor constant:24],
        [empty.trailingAnchor constraintLessThanOrEqualToAnchor:self.view.trailingAnchor constant:-24],

        [spinner.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [spinner.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor],
    ]];
}

#pragma mark - Filter chips

- (NSString *)windowTitleForSeconds:(NSTimeInterval)seconds {
    NSInteger days = (NSInteger)round(seconds / (60.0 * 60.0 * 24.0));
    if (days <= 1) {
        return @"24h";
    }
    return [NSString stringWithFormat:@"%ldd", (long)days];
}

- (UIButton *)makeChipButtonWithTitle:(NSString *)title selected:(BOOL)selected action:(SEL)action {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    button.titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
    button.contentEdgeInsets = UIEdgeInsetsMake(6, 12, 6, 12);
    [button setTitle:title forState:UIControlStateNormal];
    button.layer.cornerRadius = 14.0;
    if (selected) {
        button.backgroundColor = [UIColor systemBlueColor];
        [button setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    } else {
        button.backgroundColor = [UIColor secondarySystemBackgroundColor];
        [button setTitleColor:[UIColor labelColor] forState:UIControlStateNormal];
    }
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    return button;
}

- (void)updateFilterChips {
    for (UIView *v in [self.filterStack.arrangedSubviews copy]) {
        [self.filterStack removeArrangedSubview:v];
        [v removeFromSuperview];
    }

    NSArray<NSDictionary *> *reasonRows = @[
        @{@"title": @"All", @"value": @(OTDashcamReasonFilterAll)},
        @{@"title": @"Sentry", @"value": @(OTDashcamReasonFilterSentry)},
        @{@"title": @"Saved", @"value": @(OTDashcamReasonFilterSaved)},
    ];
    for (NSDictionary *row in reasonRows) {
        OTDashcamReasonFilter filter = (OTDashcamReasonFilter)[row[@"value"] integerValue];
        UIButton *button = [self makeChipButtonWithTitle:row[@"title"]
                                                 selected:filter == self.reasonFilter
                                                   action:@selector(reasonChipTapped:)];
        button.tag = filter;
        [self.filterStack addArrangedSubview:button];
    }

    UIView *separator = [[UIView alloc] init];
    separator.translatesAutoresizingMaskIntoConstraints = NO;
    separator.backgroundColor = [UIColor separatorColor];
    [self.filterStack addArrangedSubview:separator];
    [NSLayoutConstraint activateConstraints:@[
        [separator.widthAnchor constraintEqualToConstant:1],
    ]];

    UIButton *allDevices = [self makeChipButtonWithTitle:@"All Devices"
                                                 selected:self.deviceFilterId == nil
                                                   action:@selector(deviceChipAllTapped)];
    [self.filterStack addArrangedSubview:allDevices];

    NSArray<OTWebDeviceItem *> *sortedDevices = [self.devices sortedArrayUsingComparator:^NSComparisonResult(OTWebDeviceItem *a, OTWebDeviceItem *b) {
        NSString *aName = a.deviceName ?: a.topicId ?: @"";
        NSString *bName = b.deviceName ?: b.topicId ?: @"";
        return [aName localizedCaseInsensitiveCompare:bName];
    }];
    for (OTWebDeviceItem *device in sortedDevices) {
        NSString *name = device.deviceName.length > 0 ? device.deviceName : (device.topicId ?: @"?");
        BOOL selected = self.deviceFilterId && self.deviceFilterId.integerValue == device.deviceId;
        UIButton *chip = [self makeChipButtonWithTitle:name
                                              selected:selected
                                                action:@selector(deviceChipTapped:)];
        chip.tag = device.deviceId;
        [self.filterStack addArrangedSubview:chip];
    }
}

- (void)reasonChipTapped:(UIButton *)sender {
    self.reasonFilter = (OTDashcamReasonFilter)sender.tag;
    [self applyFilters];
    [self updateFilterChips];
}

- (void)deviceChipAllTapped {
    self.deviceFilterId = nil;
    [self applyFilters];
    [self updateFilterChips];
}

- (void)deviceChipTapped:(UIButton *)sender {
    self.deviceFilterId = @(sender.tag);
    [self applyFilters];
    [self updateFilterChips];
}

#pragma mark - Window picker

- (void)showWindowPicker {
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:@"Time Window"
                                                                   message:@"Show dashcam events from the last…"
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    NSArray<NSNumber *> *days = @[@1, @3, @7, @14, @30];
    for (NSNumber *d in days) {
        NSString *title = [NSString stringWithFormat:@"%ld day%@", d.longValue, d.intValue == 1 ? @"" : @"s"];
        [sheet addAction:[UIAlertAction actionWithTitle:title
                                                  style:UIAlertActionStyleDefault
                                                handler:^(UIAlertAction * _Nonnull action) {
            self.windowSeconds = d.doubleValue * 24.0 * 60.0 * 60.0;
            [self reloadAll];
        }]];
    }
    [sheet addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    if (sheet.popoverPresentationController) {
        sheet.popoverPresentationController.barButtonItem = self.navigationItem.rightBarButtonItems.lastObject;
    }
    [self presentViewController:sheet animated:YES completion:nil];
}

#pragma mark - Data loading

- (NSArray<OTWebDeviceItem *> *)devicesFromClips:(NSArray<OTDashcamClipItem *> *)clips {
    NSMutableDictionary<NSNumber *, OTWebDeviceItem *> *byId = [NSMutableDictionary dictionary];
    for (OTDashcamClipItem *clip in clips) {
        if (clip.deviceId <= 0) {
            continue;
        }
        NSNumber *key = @(clip.deviceId);
        if (byId[key]) {
            continue;
        }
        OTWebDeviceItem *item = [[OTWebDeviceItem alloc] init];
        item.deviceId = clip.deviceId;
        item.ownerName = clip.owner;
        item.deviceName = clip.device;
        if (clip.owner.length > 0 && clip.device.length > 0) {
            item.topicId = [NSString stringWithFormat:@"%@/%@", clip.owner, clip.device];
        }
        byId[key] = item;
    }
    return [byId.allValues sortedArrayUsingComparator:^NSComparisonResult(OTWebDeviceItem *a, OTWebDeviceItem *b) {
        NSString *aName = a.deviceName ?: a.topicId ?: @"";
        NSString *bName = b.deviceName ?: b.topicId ?: @"";
        return [aName localizedCaseInsensitiveCompare:bName];
    }];
}

- (void)reloadAll {
    [self.refreshControl beginRefreshing];
    self.emptyLabel.hidden = YES;
    if (self.allClips.count == 0) {
        [self.loadingIndicator startAnimating];
    }
    NSTimeInterval now = [NSDate date].timeIntervalSince1970;
    NSInteger to = (NSInteger)now;
    NSInteger from = (NSInteger)(now - self.windowSeconds);
    __weak typeof(self) wself = self;
    [[LocationAPISyncService sharedInstance] fetchDashcamClipsFromUnix:from
                                                                toUnix:to
                                                            completion:^(NSArray<OTDashcamClipItem *> * _Nullable clips, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(wself) sself = wself;
            if (!sself) {
                return;
            }
            [sself.refreshControl endRefreshing];
            [sself.loadingIndicator stopAnimating];
            if (error || !clips) {
                DDLogWarn(@"[Dashcam] clips fetch failed: %@", error.localizedDescription);
                sself.allClips = @[];
                sself.devices = @[];
                sself.deviceFilterId = nil;
                [sself updateFilterChips];
                [sself applyFilters];
                sself.emptyLabel.text = @"Could not load dashcam events.";
                sself.emptyLabel.hidden = NO;
                return;
            }
            sself.allClips = clips;
            sself.devices = [sself devicesFromClips:clips];
            if (sself.deviceFilterId) {
                BOOL stillPresent = NO;
                for (OTWebDeviceItem *device in sself.devices) {
                    if (device.deviceId == sself.deviceFilterId.integerValue) {
                        stillPresent = YES;
                        break;
                    }
                }
                if (!stillPresent) {
                    sself.deviceFilterId = nil;
                }
            }
            [sself updateFilterChips];
            [sself applyFilters];
        });
    }];
}

- (void)applyFilters {
    NSMutableArray<OTDashcamClipItem *> *out = [NSMutableArray arrayWithCapacity:self.allClips.count];
    for (OTDashcamClipItem *clip in self.allClips) {
        if (self.deviceFilterId && clip.deviceId != self.deviceFilterId.integerValue) {
            continue;
        }
        if (self.reasonFilter == OTDashcamReasonFilterSentry) {
            if (![DashcamGridViewController OT_isSentryReason:clip.reason]) {
                continue;
            }
        } else if (self.reasonFilter == OTDashcamReasonFilterSaved) {
            if ([DashcamGridViewController OT_isSentryReason:clip.reason]) {
                continue;
            }
        }
        [out addObject:clip];
    }
    self.visibleClips = [out copy];
    if (self.visibleClips.count == 0) {
        self.emptyLabel.text = self.allClips.count == 0
            ? @"No dashcam events in this window."
            : @"No events match the current filters.";
        self.emptyLabel.hidden = NO;
    } else {
        self.emptyLabel.hidden = YES;
    }
    [self.collectionView reloadData];
}

+ (BOOL)OT_isSentryReason:(NSString *)reason {
    if (reason.length == 0) {
        return NO;
    }
    NSString *lower = reason.lowercaseString;
    if ([lower containsString:@"sentry"]) {
        return YES;
    }
    if ([lower isEqualToString:@"sentry_aware_object_detection"]) {
        return YES;
    }
    return NO;
}

#pragma mark - Collection view data source / delegate

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return (NSInteger)self.visibleClips.count;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    OTDashcamGridCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"OTDashcamGridCell" forIndexPath:indexPath];
    OTDashcamClipItem *clip = self.visibleClips[(NSUInteger)indexPath.item];
    cell.currentClipId = clip.clipId;

    NSString *deviceName = clip.device.length > 0 ? clip.device : @"";
    OTWebDeviceItem *deviceMatch = [self deviceMatchingClip:clip];
    if (deviceMatch.deviceName.length > 0) {
        deviceName = deviceMatch.deviceName;
    }
    if (clip.owner.length > 0 && deviceName.length > 0) {
        cell.deviceLabel.text = [NSString stringWithFormat:@"%@ · %@", clip.owner, deviceName];
    } else if (deviceName.length > 0) {
        cell.deviceLabel.text = deviceName;
    } else if (clip.owner.length > 0) {
        cell.deviceLabel.text = clip.owner;
    } else {
        cell.deviceLabel.text = @"Device";
    }

    static NSDateFormatter *fmt;
    static dispatch_once_t fmtOnce;
    dispatch_once(&fmtOnce, ^{
        fmt = [[NSDateFormatter alloc] init];
        fmt.dateStyle = NSDateFormatterMediumStyle;
        fmt.timeStyle = NSDateFormatterShortStyle;
        fmt.locale = NSLocale.currentLocale;
    });
    NSDate *date = clip.eventDate;
    cell.timeLabel.text = date ? [fmt stringFromDate:date] : (clip.eventFolderName ?: @"");

    NSMutableArray<NSString *> *parts = [NSMutableArray array];
    if (clip.street.length > 0) {
        [parts addObject:clip.street];
    }
    if (clip.city.length > 0) {
        [parts addObject:clip.city];
    }
    cell.placeLabel.text = parts.count > 0 ? [parts componentsJoinedByString:@", "] : @"";

    NSString *chip = [self chipTitleForClip:clip];
    cell.reasonChipLabel.text = chip.length > 0 ? [NSString stringWithFormat:@" %@ ", chip] : nil;
    cell.reasonChipLabel.hidden = chip.length == 0;
    cell.reasonChipLabel.backgroundColor = [DashcamGridViewController OT_isSentryReason:clip.reason]
        ? [UIColor.systemRedColor colorWithAlphaComponent:0.85]
        : [UIColor.systemBlueColor colorWithAlphaComponent:0.85];

    [self applyDeviceAvatarForClip:clip toCell:cell];
    [self loadThumbnailForClip:clip intoCell:cell];

    return cell;
}

- (NSString *)chipTitleForClip:(OTDashcamClipItem *)clip {
    if ([DashcamGridViewController OT_isSentryReason:clip.reason]) {
        return @"Sentry";
    }
    if (clip.reason.length > 0) {
        return @"Saved";
    }
    return @"";
}

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath {
    UICollectionViewFlowLayout *flow = (UICollectionViewFlowLayout *)collectionViewLayout;
    UIEdgeInsets insets = flow.sectionInset;
    CGFloat available = CGRectGetWidth(collectionView.bounds) - insets.left - insets.right;
    NSInteger columns = MAX(1, (NSInteger)floor((available + flow.minimumInteritemSpacing) / (kDashcamGridMinCellWidth + flow.minimumInteritemSpacing)));
    CGFloat spacing = flow.minimumInteritemSpacing * (columns - 1);
    CGFloat width = floor((available - spacing) / (CGFloat)columns);
    CGFloat thumbHeight = width * (9.0 / 16.0);
    CGFloat metaHeight = 70.0;
    return CGSizeMake(width, thumbHeight + metaHeight);
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    [collectionView deselectItemAtIndexPath:indexPath animated:YES];
    OTDashcamClipItem *clip = self.visibleClips[(NSUInteger)indexPath.item];
    DashcamPlayerViewController *player = [[DashcamPlayerViewController alloc] initWithClip:clip];
    [self.navigationController pushViewController:player animated:YES];
}

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator {
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
    [coordinator animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext>  _Nonnull context) {
        [self.collectionView.collectionViewLayout invalidateLayout];
    } completion:nil];
}

#pragma mark - Device matching / avatars

- (OTWebDeviceItem *)deviceMatchingClip:(OTDashcamClipItem *)clip {
    for (OTWebDeviceItem *device in self.devices) {
        if (device.deviceId == clip.deviceId) {
            return device;
        }
    }
    return nil;
}

- (NSString *)cardImageCacheKeyForClip:(OTDashcamClipItem *)clip {
    OTWebDeviceItem *device = [self deviceMatchingClip:clip];
    NSString *topicId = device.topicId;
    if (topicId.length == 0) {
        topicId = [NSString stringWithFormat:@"%@/%@", clip.owner ?: @"", clip.device ?: @""];
    }
    return topicId;
}

- (void)applyDeviceAvatarForClip:(OTDashcamClipItem *)clip toCell:(OTDashcamGridCell *)cell {
    cell.deviceAvatarView.image = [UIImage systemImageNamed:@"car.fill"];
    NSString *cacheKey = [self cardImageCacheKeyForClip:clip];
    if (cacheKey.length == 0) {
        return;
    }
    UIImage *cached = [self.deviceImageCache objectForKey:cacheKey];
    if (cached) {
        cell.deviceAvatarView.image = cached;
        return;
    }
    NSString *targetClipId = clip.clipId;
    NSManagedObjectContext *queuedMOC = CoreData.sharedInstance.queuedMOC;
    [queuedMOC performBlock:^{
        Friend *friend = nil;
        NSString *topicKey = cacheKey;
        if ([topicKey containsString:@"/"]) {
            NSArray<Friend *> *all = [Friend allFriendsInManagedObjectContext:queuedMOC];
            for (Friend *f in all) {
                NSString *topic = f.topic ?: @"";
                if ([topic hasSuffix:topicKey] || [topic isEqualToString:topicKey]) {
                    friend = f;
                    break;
                }
            }
        }
        NSData *imageData = friend.cardImage;
        if (imageData.length == 0) {
            return;
        }
        UIImage *image = [UIImage imageWithData:imageData];
        if (!image) {
            return;
        }
        [self.deviceImageCache setObject:image forKey:cacheKey];
        dispatch_async(dispatch_get_main_queue(), ^{
            if ([cell.currentClipId isEqualToString:targetClipId]) {
                cell.deviceAvatarView.image = image;
            }
        });
    }];
}

#pragma mark - Thumbnails

- (void)loadThumbnailForClip:(OTDashcamClipItem *)clip intoCell:(OTDashcamGridCell *)cell {
    cell.thumbView.image = [UIImage systemImageNamed:@"video"];
    if (!clip.hasThumb) {
        return;
    }
    UIImage *cached = [self.thumbCache objectForKey:clip.clipId];
    if (cached) {
        cell.thumbView.image = cached;
        return;
    }
    NSString *targetClipId = clip.clipId;
    __weak typeof(self) wself = self;
    NSManagedObjectContext *mainMOC = CoreData.sharedInstance.mainMOC;
    __block NSURL *url = nil;
    [mainMOC performBlockAndWait:^{
        url = [WebAppURLResolver dashcamThumbAPIURLFromPreferenceInMOC:mainMOC
                                                                 clipId:clip.clipId
                                                            accessToken:nil];
    }];
    if (!url) {
        return;
    }
    [[LocationAPISyncService sharedInstance] performAuthenticatedGET:url completion:^(NSData * _Nullable data, NSError * _Nullable getErr) {
            if (!data.length) {
                return;
            }
            UIImage *image = [UIImage imageWithData:data];
            if (!image) {
                return;
            }
            __strong typeof(wself) sself = wself;
            if (!sself) {
                return;
            }
            [sself.thumbCache setObject:image forKey:targetClipId];
            dispatch_async(dispatch_get_main_queue(), ^{
                if ([cell.currentClipId isEqualToString:targetClipId]) {
                    cell.thumbView.image = image;
                }
            });
        }];
}

@end
