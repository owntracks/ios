//
//  LocationAPISyncService.m
//  OwnTracks
//
//  GET /api/location updates Core Data (Friend/Waypoint) via OwnTracking — same store as MQTT.
//  Recorder route history (GET .../history/.../route) is ViewController liveTrackPoints only, not persisted here.
//

#import "LocationAPISyncService.h"
#import <CoreLocation/CoreLocation.h>
#import "WebAppURLResolver.h"
#import "WebAppAuthHelper.h"
#import "Settings.h"
#import "CoreData.h"
#import "OwnTracking.h"
#import "OwnTracksAppDelegate.h"
#import "Friend+CoreDataClass.h"
#import <UIKit/UIKit.h>
#import <AuthenticationServices/AuthenticationServices.h>
#import <sys/utsname.h>
#import <CocoaLumberjack/CocoaLumberjack.h>

static const DDLogLevel ddLogLevel = DDLogLevelInfo;

static NSURLSession *LocationAPISyncURLSession(void) {
    static NSURLSession *session;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSURLSessionConfiguration *cfg = [NSURLSessionConfiguration defaultSessionConfiguration];
        cfg.timeoutIntervalForRequest = 30.0;
        cfg.timeoutIntervalForResource = 90.0;
        cfg.waitsForConnectivity = YES;
        session = [NSURLSession sessionWithConfiguration:cfg];
    });
    return session;
}

/// Server allows `^[a-zA-Z0-9 ]+$` for POST /api/config/provision `deviceName`.
static NSString *OTProvisionSanitizedDeviceName(void) {
    NSString *raw = [UIDevice currentDevice].name ?: @"";
    NSMutableString *out = [NSMutableString stringWithCapacity:raw.length];
    for (NSUInteger i = 0; i < raw.length; i++) {
        unichar c = [raw characterAtIndex:i];
        if ((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9') || c == ' ') {
            [out appendFormat:@"%C", c];
        }
    }
    NSString *collapsed = [out stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    while ([collapsed rangeOfString:@"  "].location != NSNotFound) {
        collapsed = [collapsed stringByReplacingOccurrencesOfString:@"  " withString:@" "];
    }
    if (collapsed.length == 0) {
        return @"Device";
    }
    return collapsed;
}

static NSString *OTProvisionHardwareMachine(void) {
    static NSString *cached;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        struct utsname u;
        if (uname(&u) == 0) {
            cached = [[NSString stringWithUTF8String:u.machine] copy] ?: @"unknown";
        } else {
            cached = @"unknown";
        }
    });
    return cached ?: @"unknown";
}

/// Non-authoritative hints for `POST /api/config/provision` (see `OwnTracks/docs/PROVISION_API_CONTRACT.md`).
static NSDictionary *OTProvisionRequestBodyWithHints(NSManagedObjectContext *moc) {
    NSMutableDictionary *d = [NSMutableDictionary dictionary];
    d[@"deviceName"] = OTProvisionSanitizedDeviceName();
    NSUUID *idfv = [UIDevice currentDevice].identifierForVendor;
    if (idfv) {
        d[@"identifierForVendor"] = idfv.UUIDString;
    }
    d[@"hardwareMachine"] = OTProvisionHardwareMachine();
    d[@"bundleIdentifier"] = NSBundle.mainBundle.bundleIdentifier ?: @"";
    id ver = NSBundle.mainBundle.infoDictionary[@"CFBundleShortVersionString"];
    d[@"appVersionShort"] = [ver isKindOfClass:[NSString class]] ? ver : @"";
    id build = NSBundle.mainBundle.infoDictionary[@"CFBundleVersion"];
    d[@"appBuild"] = [build isKindOfClass:[NSString class]] ? build : @"";

    NSString *exDev = [Settings stringForKey:@"deviceid_preference" inMOC:moc];
    if (exDev.length) {
        d[@"existingDeviceId"] = exDev;
    }
    NSString *exTid = [Settings stringForKey:@"trackerid_preference" inMOC:moc];
    if (exTid.length) {
        d[@"existingTrackerId"] = exTid;
    }
    return [d copy];
}

static NSNumber *_Nullable OTProvisionTrackedDeviceIdNumberFromJSON(id obj) {
    if ([obj isKindOfClass:[NSNumber class]]) {
        return (NSNumber *)obj;
    }
    if ([obj isKindOfClass:[NSString class]]) {
        NSString *s = [(NSString *)obj stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (!s.length) {
            return nil;
        }
        return @(s.longLongValue);
    }
    return nil;
}

static NSDate *_Nullable OTProvisionDateFromLastSeenJSON(id value) {
    if ([value isKindOfClass:[NSDate class]]) {
        return (NSDate *)value;
    }
    if (![value isKindOfClass:[NSString class]]) {
        return nil;
    }
    NSString *s = (NSString *)value;
    NSISO8601DateFormatter *iso = [[NSISO8601DateFormatter alloc] init];
    iso.formatOptions = NSISO8601DateFormatWithInternetDateTime | NSISO8601DateFormatWithFractionalSeconds;
    NSDate *d = [iso dateFromString:s];
    if (!d) {
        iso.formatOptions = NSISO8601DateFormatWithInternetDateTime;
        d = [iso dateFromString:s];
    }
    return d;
}

static NSString *OTProvisionFormatLastSeenForUI(id lastSeenAt) {
    NSDate *d = OTProvisionDateFromLastSeenJSON(lastSeenAt);
    if (!d) {
        if ([lastSeenAt isKindOfClass:[NSString class]] && [(NSString *)lastSeenAt length] > 0) {
            return (NSString *)lastSeenAt;
        }
        return @"—";
    }
    NSDateFormatter *fmt = [[NSDateFormatter alloc] init];
    fmt.dateStyle = NSDateFormatterShortStyle;
    fmt.timeStyle = NSDateFormatterShortStyle;
    fmt.locale = NSLocale.currentLocale;
    NSString *ds = [fmt stringFromDate:d];
    return [NSString stringWithFormat:NSLocalizedString(@"ProvisionLastSeenPrefix", @"e.g. Last seen: 5/14/26, 4:40 PM"), ds];
}

/// Multi-line description for one row in the provision device picker (tap row to select).
static NSString *OTProvisionDeviceRowDetailText(NSDictionary *dev) {
    if (![dev isKindOfClass:[NSDictionary class]]) {
        return @"";
    }
    NSString *nm = @"";
    if ([dev[@"displayName"] isKindOfClass:[NSString class]]) {
        nm = [(NSString *)dev[@"displayName"] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    }
    NSString *topic = @"";
    if ([dev[@"pubTopicBase"] isKindOfClass:[NSString class]] && [(NSString *)dev[@"pubTopicBase"] length]) {
        topic = dev[@"pubTopicBase"];
    } else if ([dev[@"deviceId"] isKindOfClass:[NSString class]]) {
        topic = [(NSString *)dev[@"deviceId"] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    }
    NSString *seen = OTProvisionFormatLastSeenForUI(dev[@"lastSeenAt"]);
    NSNumber *tracked = OTProvisionTrackedDeviceIdNumberFromJSON(dev[@"trackedDeviceId"]);
    NSMutableArray<NSString *> *lines = [NSMutableArray array];
    if (nm.length) {
        [lines addObject:nm];
    }
    if (topic.length) {
        [lines addObject:topic];
    }
    if (tracked) {
        [lines addObject:[NSString stringWithFormat:NSLocalizedString(@"ProvisionTrackedDeviceIdLine", nil), tracked]];
    }
    if ([dev[@"lastTrackerId"] isKindOfClass:[NSString class]]) {
        NSString *lt = [(NSString *)dev[@"lastTrackerId"] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (lt.length) {
            [lines addObject:[NSString stringWithFormat:NSLocalizedString(@"ProvisionLastTrackerLine", nil), lt]];
        }
    }
    if (seen.length) {
        [lines addObject:seen];
    }
    if (!lines.count) {
        return @"—";
    }
    return [lines componentsJoinedByString:@"\n"];
}

static BOOL OTJSONBoolish(id _Nullable value, BOOL defaultValue) {
    if (value == nil || value == [NSNull null]) {
        return defaultValue;
    }
    if ([value isKindOfClass:[NSNumber class]]) {
        return [(NSNumber *)value boolValue];
    }
    if ([value isKindOfClass:[NSString class]]) {
        NSString *s = [(NSString *)value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if ([s caseInsensitiveCompare:@"true"] == NSOrderedSame || [s caseInsensitiveCompare:@"yes"] == NSOrderedSame || [s isEqualToString:@"1"]) {
            return YES;
        }
        if ([s caseInsensitiveCompare:@"false"] == NSOrderedSame || [s isEqualToString:@"0"]) {
            return NO;
        }
    }
    return defaultValue;
}

static NSNumber *_Nullable OTNullableIntNumberFromJSON(id _Nullable value) {
    if (value == nil || value == [NSNull null]) {
        return nil;
    }
    if ([value isKindOfClass:[NSNumber class]]) {
        return (NSNumber *)value;
    }
    if ([value isKindOfClass:[NSString class]]) {
        NSString *s = [(NSString *)value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (!s.length) {
            return nil;
        }
        return @([s integerValue]);
    }
    return nil;
}

static NSString * const kOTProvisionAPIDomain = @"OTProvisionAPI";
/// Returned when `provisionRemoteDeviceConfigurationIfNeededWithCompletion:` is invoked while a provision POST is already in flight.
static const NSInteger kOTProvisionAPICodeBusy = 998;

NSNotificationName const OwnTracksOAuthAccessTokenBecameAvailableNotification = @"OwnTracksOAuthAccessTokenBecameAvailable";
NSNotificationName const OwnTracksGeolocationCacheDidUpdateNotification = @"OwnTracksGeolocationCacheDidUpdate";
NSNotificationName const OwnTracksCurrentUserProfileDidUpdateNotification = @"OwnTracksCurrentUserProfileDidUpdate";
NSNotificationName const OwnTracksLocationMQTTAllowlistDidUpdateNotification = @"OwnTracksLocationMQTTAllowlistDidUpdate";
NSString * const OTLocationDeleteErrorCodeKey = @"OTLocationDeleteErrorCode";
NSString * const OTLocationDeleteErrorReferenceCountKey = @"OTLocationDeleteErrorReferenceCount";
NSString * const OTLocationDeleteErrorMessageKey = @"OTLocationDeleteErrorMessage";

/// One interactive OAuth prompt per app process when the location API has no refresh token (same idea as WebAppViewController `startFullNativeAuth`).
static BOOL gLocationAPIOAuthPromptScheduledThisSession;

static UIViewController *LocationAPISyncTopMostViewController(void) {
    UIWindow *keyWindow = nil;
    for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
        if (![scene isKindOfClass:[UIWindowScene class]]) {
            continue;
        }
        for (UIWindow *w in ((UIWindowScene *)scene).windows) {
            if (w.isKeyWindow) {
                keyWindow = w;
                break;
            }
        }
        if (keyWindow) {
            break;
        }
    }
    if (!keyWindow) {
        UIWindowScene *scene = (UIWindowScene *)[UIApplication sharedApplication].connectedScenes.anyObject;
        keyWindow = scene.windows.firstObject;
    }
    UIViewController *root = keyWindow.rootViewController;
    while (root.presentedViewController) {
        root = root.presentedViewController;
    }
    return root;
}

/// Poll interval while app is active (no Settings UI).
static const NSTimeInterval kLocationAPIPollIntervalSeconds = 60.0;
/// Minimum seconds between debounced refreshes (Friends tab, etc.) and the last successful GET /api/location apply.
static const NSTimeInterval kLocationAPIDebouncedRefreshMinIntervalSeconds = 25.0;
/// Default radius (m) for geolocation cache items when API omits `radius` — matches `OTLocationDetailsViewController`.
static const CLLocationDistance kOTGeolocationCacheDefaultRadiusMeters = 35.0;
/// Minimum interval between automatic geolocationcache GETs (prefetch).
static const NSTimeInterval kOTGeolocationCachePrefetchMinIntervalSeconds = 25.0;

static BOOL OTWebLocationItemHasFollowStyleName(OTWebLocationItem *item) {
    static NSString * const kPrefix = @"+follow";
    NSArray<NSString *> *candidates = @[item.displayName ?: @"", item.originalDisplayName ?: @""];
    for (NSString *name in candidates) {
        if (name.length == 0) {
            continue;
        }
        if ([name.lowercaseString hasPrefix:kPrefix]) {
            return YES;
        }
    }
    return NO;
}

@implementation OTWebLocationItem
@end

@implementation OTWebNotificationItem
@end

@implementation OTWebNotificationsPage
@end

@implementation OTWebDeviceItem
@end

@implementation OTDashcamClipCamera
@end

@implementation OTDashcamClipItem
@end

NSTimeInterval OTRouteHistoryPointUnixTime(id pt) {
    if (![pt isKindOfClass:[NSDictionary class]]) {
        return NAN;
    }
    NSDictionary *dict = (NSDictionary *)pt;
    NSArray<NSString *> *keys = @[ @"tst", @"timestamp", @"time", @"createdAt", @"created_at" ];
    for (NSString *key in keys) {
        id v = dict[key];
        if ([v isKindOfClass:[NSNumber class]]) {
            double t = [(NSNumber *)v doubleValue];
            if (t > 1e12) {
                t /= 1000.0;
            }
            if (t > 946684800 && t < 4102444800) {
                return t;
            }
        } else if ([v isKindOfClass:[NSString class]]) {
            NSString *s = (NSString *)v;
            double t = [s doubleValue];
            if (t > 1e12) {
                t /= 1000.0;
            }
            if (t > 946684800 && t < 4102444800) {
                return t;
            }
            static NSISO8601DateFormatter *isoFmt;
            static dispatch_once_t onceToken;
            dispatch_once(&onceToken, ^{
                isoFmt = [[NSISO8601DateFormatter alloc] init];
            });
            NSDate *d = [isoFmt dateFromString:s];
            if (d) {
                return [d timeIntervalSince1970];
            }
        }
    }
    return NAN;
}

static NSArray<NSDictionary *> *OTExtractRouteHistoryPointsFromJSONData(NSData *data, NSError **outError) {
    NSError *jsonError = nil;
    id obj = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
    if (jsonError) {
        if (outError) {
            *outError = jsonError;
        }
        return nil;
    }
    NSArray *points = nil;
    if ([obj isKindOfClass:[NSDictionary class]]) {
        id p = ((NSDictionary *)obj)[@"points"];
        if ([p isKindOfClass:[NSArray class]]) {
            points = (NSArray *)p;
        }
    }
    if (![points isKindOfClass:[NSArray class]]) {
        return @[];
    }
    NSMutableArray<NSDictionary *> *out = [NSMutableArray arrayWithCapacity:points.count];
    for (id item in points) {
        if ([item isKindOfClass:[NSDictionary class]]) {
            [out addObject:[(NSDictionary *)item copy]];
        }
    }
    return [out copy];
}

@interface LocationAPISyncService ()
@property (nonatomic, strong, nullable) NSTimer *pollTimer;
@property (nonatomic) BOOL fetchInFlight;
@property (nonatomic) BOOL provisionInFlight;
@property (nonatomic, strong, nullable) NSDate *lastSuccessfulLocationAPIFetchDate;
/// Filled from `/.well-known/owntracks-app-auth` when Settings OAuth Client ID is empty; needed so Keychain lookup uses the same client_id the token was stored with.
@property (nonatomic, copy, nullable) NSString *cachedOAuthClientIdFromDiscovery;
/// Most recent access token used for GET /api/location; reused for device image fetches.
@property (nonatomic, copy, nullable) NSString *cachedAccessToken;
/// Unix timestamp (exp claim) of cachedAccessToken. Zero means unknown/uncached.
@property (nonatomic) NSTimeInterval cachedAccessTokenExpiry;
/// Last successful `GET /api/geolocationcache` payload (main thread only).
@property (nonatomic, copy, nullable) NSArray<OTWebLocationItem *> *lastGeolocationCacheItems;
@property (nonatomic, strong, nullable) NSDate *lastSuccessfulGeolocationCacheFetchDate;
@property (nonatomic) BOOL geolocationCacheFetchInFlight;
/// Last successful bulk `GET /api/dashcam/clips?from=&to=` (main thread only).
@property (nonatomic, copy, nullable) NSArray<OTDashcamClipItem *> *lastDashcamClips;
@property (nonatomic) NSInteger lastDashcamFromUnix;
@property (nonatomic) NSInteger lastDashcamToUnix;
@property (nonatomic) BOOL dashcamClipsFetchInFlight;
/// From `GET /api/authorization/user` (main thread only).
@property (nonatomic) BOOL authorizationUserProfileLoaded;
@property (nonatomic) BOOL authorizationUserIsAdmin;
@property (nonatomic) BOOL authorizationUserCanViewRouteHistory;
@property (nonatomic, strong, nullable) NSNumber *authAPIHomeZoneId;
@property (nonatomic, strong, nullable) NSNumber *authAPIWorkZoneId;
@property (nonatomic, strong) NSCache<NSString *, NSArray<NSDictionary *> *> *routeHistoryPointsCache;
/// Device-level MQTT topic prefixes from the last successful `GET /api/location` (excludes own device). Thread: reads/writes under `@synchronized(self)`.
@property (nonatomic, copy) NSSet<NSString *> *mqttAllowedFriendDeviceTopics;
@property (nonatomic) BOOL mqttFriendAllowlistLoadedFromLocationAPI;
- (void)scheduleInteractiveOAuthIfNoTokenAfterFailure;
/// OAuth stores refresh tokens under `keychainAccountForWebAppURL` using discovery `client_id` from `/.well-known/owntracks-app-auth`, not necessarily Settings `oauth_client_id_preference`. Try discovery id first, then settings, then nil lookup.
- (void)trySilentRefreshWithCandidates:(NSArray<NSURL *> *)candidates
                    clientIdsOrdered:(NSArray *)discoveryThenPrefsThenNil
                            idsIndex:(NSUInteger)idsIdx
                            completion:(void (^)(NSString * _Nullable token))completion;
- (void)performGET:(NSURL *)apiURL
      accessToken:(NSString *)accessToken
 allowRetryOn401:(BOOL)allowRetryOn401
 transientAttempt:(NSUInteger)transientAttempt;
- (BOOL)isTransientLocationAPIURLSessionError:(NSError *)error;
- (BOOL)isTransientLocationAPIHTTPStatus:(NSInteger)status;
- (void)scheduleLocationAPIGETRetry:(NSURL *)apiURL
                      accessToken:(NSString *)accessToken
                  allowRetryOn401:(BOOL)allowRetryOn401
                 transientAttempt:(NSUInteger)nextAttempt;
- (void)oauthAccessTokenBecameAvailable:(NSNotification *)notification;
- (void)attemptNativeProvisionAfterOAuthOrForegroundIfNeeded;
- (void)OT_applyLocationMQTTAllowlistFromSortedDeviceTopics:(NSArray<NSString *> *)sortedDeviceTopics;
- (void)performAuthenticatedRequestWithURL:(NSURL *)url
                                    method:(NSString *)method
                                  jsonBody:(nullable NSDictionary *)jsonBody
                                completion:(void (^)(NSData * _Nullable data,
                                                     NSInteger statusCode,
                                                     NSError * _Nullable error))completion;
- (nullable OTWebLocationItem *)locationItemFromDictionary:(NSDictionary *)dict;
- (nullable OTWebNotificationItem *)notificationItemFromDictionary:(NSDictionary *)dict;
- (NSError *)errorForStatus:(NSInteger)status fallbackDomain:(NSString *)domain;
- (NSError *)locationDeleteErrorFromData:(NSData * _Nullable)data statusCode:(NSInteger)statusCode;

- (void)OT_applyProvisionConfigurationPayload:(NSDictionary *)payload
              allowLocalIdentityRepairIfInvalid:(BOOL)allowRepair
                                     completion:(void (^)(BOOL applied, NSError * _Nullable error))completion;

- (void)OT_postProvisionHTTPWithURL:(NSURL *)provisionURL
                             bodyData:(NSData *)bodyData
                          accessToken:(NSString *)token
                       allowRetry401:(BOOL)allowRetry401
        allowLocalIdentityRepairIfInvalid:(BOOL)allowRepair
                           completion:(void (^)(BOOL applied, NSError * _Nullable error))completion;

- (void)OT_runLegacySingleStepProvisionWithURL:(NSURL *)provisionURL
                                           moc:(NSManagedObjectContext *)moc
                                   accessToken:(NSString *)token
                                    completion:(void (^)(BOOL applied, NSError * _Nullable error))completion;

- (void)OT_runGuidedProvisionPOSTWithURL:(NSURL *)provisionURL
                                     moc:(NSManagedObjectContext *)moc
                             accessToken:(NSString *)token
                                    mode:(NSString *)mode
                       trackedDeviceId:(NSNumber * _Nullable)trackedDeviceId
                              completion:(void (^)(BOOL applied, NSError * _Nullable error))completion;

- (void)OT_presentProvisionDeviceChooserWithUser:(NSDictionary * _Nullable)userDict
                                 existingDevices:(NSArray<NSDictionary *> *)devicesSlice
                                      totalCount:(NSUInteger)totalCount
                                       truncated:(BOOL)truncated
                                    provisionURL:(NSURL *)provisionURL
                                             moc:(NSManagedObjectContext *)moc
                                     accessToken:(NSString *)token
                                      completion:(void (^)(BOOL applied, NSError * _Nullable error))completion;
@end

@interface OTProvisionDevicePickerTVC : UITableViewController
@property (nonatomic, copy) NSArray<NSDictionary *> *devices;
@property (nonatomic, copy, nullable) NSString *accountHeaderPlain;
@property (nonatomic) BOOL truncatedFooter;
@property (nonatomic, copy) void (^onPickExisting)(NSNumber *trackedDeviceId);
@property (nonatomic, copy) void (^onPickNew)(void);
@property (nonatomic, copy) void (^onCancel)(void);
@end

@implementation OTProvisionDevicePickerTVC

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = NSLocalizedString(@"ProvisionExistingDeviceTitle", nil);
    self.navigationItem.leftBarButtonItem =
        [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
                                                    target:self
                                                    action:@selector(OT_cancelPressed)];
    self.tableView.estimatedRowHeight = 120.0;
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.cellLayoutMarginsFollowReadableWidth = YES;
}

- (void)OT_cancelPressed {
    [self dismissViewControllerAnimated:YES completion:^{
        if (self.onCancel) {
            self.onCancel();
        }
    }];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0) {
        return (NSInteger)self.devices.count;
    }
    return 1;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (section == 0 && self.accountHeaderPlain.length) {
        return self.accountHeaderPlain;
    }
    return nil;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if (section == 0 && self.truncatedFooter) {
        return NSLocalizedString(@"ProvisionExistingDeviceTruncated", nil);
    }
    return nil;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *const kCell = @"OTProvisionDevicePickerCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:kCell];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:kCell];
        cell.textLabel.numberOfLines = 0;
        cell.textLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }
    if (indexPath.section == 0) {
        NSDictionary *dev = self.devices[(NSUInteger)indexPath.row];
        cell.textLabel.text = OTProvisionDeviceRowDetailText(dev);
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        cell.textLabel.textColor = UIColor.labelColor;
    } else {
        cell.textLabel.text = NSLocalizedString(@"ProvisionNewDeviceAction", nil);
        cell.textLabel.textColor = UIColor.labelColor;
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.section == 0) {
        NSDictionary *dev = self.devices[(NSUInteger)indexPath.row];
        NSNumber *tid = OTProvisionTrackedDeviceIdNumberFromJSON(dev[@"trackedDeviceId"]);
        if (!tid) {
            return;
        }
        __weak typeof(self) wself = self;
        [self dismissViewControllerAnimated:YES completion:^{
            __strong typeof(wself) sself = wself;
            if (sself.onPickExisting) {
                sself.onPickExisting(tid);
            }
        }];
    } else {
        __weak typeof(self) wself = self;
        [self dismissViewControllerAnimated:YES completion:^{
            __strong typeof(wself) sself = wself;
            if (sself.onPickNew) {
                sself.onPickNew();
            }
        }];
    }
}

@end

@implementation LocationAPISyncService

+ (instancetype)sharedInstance {
    static LocationAPISyncService *instance;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        instance = [[self alloc] initPrivate];
    });
    return instance;
}

- (instancetype)initPrivate {
    self = [super init];
    if (self) {
        _authorizationUserCanViewRouteHistory = YES;
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(applicationDidBecomeActive:)
                                                     name:UIApplicationDidBecomeActiveNotification
                                                   object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(applicationDidEnterBackground:)
                                                     name:UIApplicationDidEnterBackgroundNotification
                                                   object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(oauthAccessTokenBecameAvailable:)
                                                     name:OwnTracksOAuthAccessTokenBecameAvailableNotification
                                                     object:nil];
        _routeHistoryPointsCache = [[NSCache alloc] init];
        _routeHistoryPointsCache.countLimit = 40;
        _mqttAllowedFriendDeviceTopics = [NSSet set];
        _mqttFriendAllowlistLoadedFromLocationAPI = NO;
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (instancetype)init {
    return [self initPrivate];
}

- (void)start {
    DDLogInfo(@"[LocationAPISyncService] start");
}

- (BOOL)isLocationMQTTAllowlistFeatureAvailableForMOC:(NSManagedObjectContext *)moc {
    NSURL *apiURL = [WebAppURLResolver locationAPIRequestURLFromPreferenceInMOC:moc];
    NSArray *candidates = [WebAppURLResolver webAppKeychainURLCandidatesFromPreferenceInMOC:moc];
    return apiURL != nil && candidates.count > 0;
}

- (BOOL)mqttFriendAllowlistHasLoadedFromLocationAPI {
    @synchronized (self) {
        return self.mqttFriendAllowlistLoadedFromLocationAPI;
    }
}

- (NSArray<NSString *> *)mqttAllowedFriendDeviceTopicPrefixes {
    @synchronized (self) {
        NSArray *arr = [self.mqttAllowedFriendDeviceTopics.allObjects sortedArrayUsingSelector:@selector(compare:)];
        return arr ?: @[];
    }
}

- (NSArray<NSString *> *)mqttSubscriptionFiltersOwnDeviceOnlyForMOC:(NSManagedObjectContext *)moc {
    NSString *base = [Settings theGeneralTopicInMOC:moc];
    if (!base.length) {
        return @[];
    }
    return @[
        base,
        [base stringByAppendingString:@"/event"],
        [base stringByAppendingString:@"/info"],
        [base stringByAppendingString:@"/cmd"],
    ];
}

- (NSArray<NSString *> *)mqttSubscriptionFiltersForAllowlistConnectWithMOC:(NSManagedObjectContext *)moc {
    NSMutableOrderedSet *topics = [NSMutableOrderedSet orderedSet];
    for (NSString *t in [self mqttSubscriptionFiltersOwnDeviceOnlyForMOC:moc]) {
        if (t.length) {
            [topics addObject:t];
        }
    }
    NSString *own = [Settings theGeneralTopicInMOC:moc];
    NSSet *friendsCopy = nil;
    @synchronized (self) {
        friendsCopy = [self.mqttAllowedFriendDeviceTopics copy];
    }
    for (NSString *friendRoot in friendsCopy) {
        if (!friendRoot.length) {
            continue;
        }
        if (own.length && [friendRoot isEqualToString:own]) {
            continue;
        }
        [topics addObject:friendRoot];
        [topics addObject:[friendRoot stringByAppendingString:@"/event"]];
        [topics addObject:[friendRoot stringByAppendingString:@"/info"]];
    }
    return topics.array;
}

- (BOOL)friendMqttDeviceTopicPrefixAllowed:(NSString *)deviceTopicPrefix managedObjectContext:(NSManagedObjectContext *)moc {
    if (!deviceTopicPrefix.length) {
        return NO;
    }
    NSString *own = [Settings theGeneralTopicInMOC:moc];
    if (own.length && [deviceTopicPrefix isEqualToString:own]) {
        return YES;
    }
    if (![self isLocationMQTTAllowlistFeatureAvailableForMOC:moc]) {
        return YES;
    }
    @synchronized (self) {
        if (!self.mqttFriendAllowlistLoadedFromLocationAPI) {
            return NO;
        }
        return [self.mqttAllowedFriendDeviceTopics containsObject:deviceTopicPrefix];
    }
}

- (void)OT_applyLocationMQTTAllowlistFromSortedDeviceTopics:(NSArray<NSString *> *)sortedDeviceTopics {
    NSSet *newSet = [NSSet setWithArray:sortedDeviceTopics ?: @[]];
    BOOL shouldNotify = NO;
    @synchronized (self) {
        BOOL wasLoaded = self.mqttFriendAllowlistLoadedFromLocationAPI;
        NSSet *old = self.mqttAllowedFriendDeviceTopics ?: [NSSet set];
        BOOL same = (old.count == newSet.count);
        if (same) {
            for (NSString *x in newSet) {
                if (![old containsObject:x]) {
                    same = NO;
                    break;
                }
            }
        }
        self.mqttAllowedFriendDeviceTopics = newSet;
        self.mqttFriendAllowlistLoadedFromLocationAPI = YES;
        shouldNotify = !wasLoaded || !same;
    }
    if (shouldNotify) {
        DDLogInfo(@"[LocationAPISyncService] MQTT friend allowlist updated (%lu devices) — posting OwnTracksLocationMQTTAllowlistDidUpdate",
                  (unsigned long)newSet.count);
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:OwnTracksLocationMQTTAllowlistDidUpdateNotification
                                                                  object:self];
        });
    }
}

- (void)applicationDidBecomeActive:(NSNotification *)notification {
    [self fetchAndApply];
    [self requestGeolocationCachePrefetchIfAppropriate];
    [self startPollTimer];
    // Native-only UI never loads WebAppViewController; deferred provision covers cold start once LAS token path is warm.
    __weak typeof(self) wself = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        __strong typeof(wself) sself = wself;
        if (!sself) {
            return;
        }
        DDLogVerbose(@"[ProvisionAPI] deferred foreground attempt (native provision if needed)");
        [sself attemptNativeProvisionAfterOAuthOrForegroundIfNeeded];
    });
}

- (void)oauthAccessTokenBecameAvailable:(NSNotification *)notification {
    DDLogVerbose(@"[ProvisionAPI] OAuth access token available — attempting native provision if needed");
    [self attemptNativeProvisionAfterOAuthOrForegroundIfNeeded];
}

- (void)attemptNativeProvisionAfterOAuthOrForegroundIfNeeded {
    [self provisionRemoteDeviceConfigurationIfNeededWithCompletion:^(BOOL applied, NSError *err) {
        if (applied) {
            DDLogInfo(@"[ProvisionAPI] configuration applied (native trigger)");
        } else if (err && [err.domain isEqualToString:kOTProvisionAPIDomain] && err.code == kOTProvisionAPICodeBusy) {
            DDLogVerbose(@"[ProvisionAPI] native trigger skipped (provision already in flight)");
        } else if (err) {
            DDLogVerbose(@"[ProvisionAPI] native trigger: %@", err.localizedDescription);
        }
    }];
}

- (void)applicationDidEnterBackground:(NSNotification *)notification {
    [self stopPollTimer];
}

- (void)startPollTimer {
    [self stopPollTimer];
    __weak typeof(self) wself = self;
    self.pollTimer = [NSTimer timerWithTimeInterval:kLocationAPIPollIntervalSeconds
                                            repeats:YES
                                              block:^(NSTimer * _Nonnull timer) {
        __strong typeof(wself) sself = wself;
        if (!sself) {
            return;
        }
        [sself fetchAndApply];
    }];
    [[NSRunLoop mainRunLoop] addTimer:self.pollTimer forMode:NSRunLoopCommonModes];
}

- (void)stopPollTimer {
    [self.pollTimer invalidate];
    self.pollTimer = nil;
}

- (void)requestLocationRefreshIfAppropriate {
    if (self.fetchInFlight) {
        DDLogVerbose(@"[LocationAPISyncService] debounced refresh skipped (fetch in flight)");
        return;
    }
    NSDate *last = self.lastSuccessfulLocationAPIFetchDate;
    if (last && [[NSDate date] timeIntervalSinceDate:last] < kLocationAPIDebouncedRefreshMinIntervalSeconds) {
        DDLogVerbose(@"[LocationAPISyncService] debounced refresh skipped (last fetch %.1fs ago)",
                      [[NSDate date] timeIntervalSinceDate:last]);
        return;
    }
    [self fetchAndApply];
}

- (void)fetchAndApply {
    if (self.fetchInFlight) {
        DDLogVerbose(@"[LocationAPISyncService] fetch skipped (already in flight)");
        return;
    }

    NSManagedObjectContext *mainMOC = CoreData.sharedInstance.mainMOC;
    NSURL *apiURL = [WebAppURLResolver locationAPIRequestURLFromPreferenceInMOC:mainMOC];
    NSArray<NSURL *> *candidates = [WebAppURLResolver webAppKeychainURLCandidatesFromPreferenceInMOC:mainMOC];
    if (!apiURL || candidates.count == 0) {
        return;
    }

    self.fetchInFlight = YES;
    __weak typeof(self) wself = self;

    // Use the cached access token if it still has >60 seconds of life remaining.
    // This avoids a refresh-grant POST to Authentik on every 60-second poll — with
    // token rotation enabled (Authentik threshold=seconds=0), unnecessary calls rotate
    // the refresh token each time, creating race conditions between concurrent callers
    // (WebApp tab, background wakeup processes) that share the same Keychain entry.
    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
    NSString *preCachedToken = nil;
    if (self.cachedAccessToken.length > 0 && self.cachedAccessTokenExpiry > now + 60.0) {
        preCachedToken = self.cachedAccessToken;
        DDLogVerbose(@"[LocationAPISyncService] Reusing cached access token (exp in %.0fs)", self.cachedAccessTokenExpiry - now);
    }

    void (^withToken)(NSString *) = ^(NSString *accessToken) {
        __strong typeof(wself) sself = wself;
        if (!sself) return;
        if (!accessToken.length) {
            DDLogInfo(@"[LocationAPISyncService] Skipping GET /api/location — no access token. "
                      @"Sign in once via a Web tab (embedded map/friends) so a refresh token is stored, "
                      @"or set OAuth Client ID in Settings. MQTT errors do not provide this token.");
            sself.fetchInFlight = NO;
            [sself scheduleInteractiveOAuthIfNoTokenAfterFailure];
            return;
        }
        [sself performGET:apiURL accessToken:accessToken allowRetryOn401:YES];
    };

    if (preCachedToken) {
        withToken(preCachedToken);
    } else {
        [self obtainAccessTokenForLocationAPIWithCompletion:^(NSString * _Nullable accessToken) {
            withToken(accessToken);
        }];
    }
}

/// Presents the same PKCE flow as the Web tab when there is no Keychain refresh token, so GET /api/location can run. At most once per cold start.
- (void)scheduleInteractiveOAuthIfNoTokenAfterFailure {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (gLocationAPIOAuthPromptScheduledThisSession) {
            return;
        }
        // Only present interactive auth when the app is truly foreground-active.
        // Background wakeups (SLC, geofence) are too short-lived to host an
        // ASWebAuthenticationSession — presenting causes applicationWillTerminate
        // within milliseconds, killing the auth flow before a token is stored.
        // Do NOT set the flag so the prompt can retry on the next poll when active.
        UIApplicationState appState = [UIApplication sharedApplication].applicationState;
        if (appState != UIApplicationStateActive) {
            DDLogInfo(@"[LocationAPISyncService] Skipping OAuth prompt — app not active (state=%ld); will retry when foregrounded", (long)appState);
            return;
        }
        // Set flag immediately to prevent concurrent re-entrant calls during the async pre-check.
        // Will be reset to NO only if the prompt itself fails with a transient error.
        gLocationAPIOAuthPromptScheduledThisSession = YES;
        NSManagedObjectContext *moc = CoreData.sharedInstance.mainMOC;
        NSString *webPref = [Settings stringForKey:@"webappurl_preference" inMOC:moc];
        if (webPref.length == 0) {
            return;
        }
        NSURL *webAppURL = [WebAppURLResolver webAppKeychainURLFromPreferenceInMOC:moc];
        if (!webAppURL) {
            return;
        }
        UIViewController *presenter = LocationAPISyncTopMostViewController();
        if (!presenter) {
            DDLogWarn(@"[LocationAPISyncService] Cannot present OAuth — no key window");
            return;
        }
        NSString *oidcURLString = [Settings stringForKey:@"oidc_discovery_url_preference" inMOC:moc];
        NSURL *oidcURL = oidcURLString.length > 0 ? [NSURL URLWithString:oidcURLString] : nil;
        NSString *clientId = [Settings stringForKey:@"oauth_client_id_preference" inMOC:moc];
        if (!clientId.length) {
            clientId = nil;
        }

        // Re-check for a token before showing the prompt. The web app tab may have completed
        // its own OIDC passthrough and stored a refresh token in Keychain between the first
        // failed poll and now — in that case we can use it directly and skip the prompt.
        __weak typeof(self) wself = self;
        [self obtainAccessTokenForLocationAPIWithCompletion:^(NSString * _Nullable preCheckToken) {
            dispatch_async(dispatch_get_main_queue(), ^{
                __strong typeof(wself) sself = wself;
                if (!sself) return;

                if (preCheckToken.length > 0) {
                    DDLogInfo(@"[LocationAPISyncService] Token found on pre-prompt re-check — skipping OAuth prompt");
                    NSManagedObjectContext *fetchMOC = CoreData.sharedInstance.mainMOC;
                    NSURL *apiURL = [WebAppURLResolver locationAPIRequestURLFromPreferenceInMOC:fetchMOC];
                    if (apiURL && !sself.fetchInFlight) {
                        sself.fetchInFlight = YES;
                        [sself performGET:apiURL accessToken:preCheckToken allowRetryOn401:YES];
                    }
                    return;
                }

                // Still no token — present the interactive sign-in prompt.
                DDLogInfo(@"[LocationAPISyncService] No refresh token — presenting sign-in (once per app launch)");
                [[WebAppAuthHelper sharedInstance] startAuthWithWebAppOrigin:webAppURL
                                                          oidcDiscoveryURL:oidcURL
                                                                  clientId:clientId
                                                    presentingViewController:presenter
                                                                 completion:^(NSString * _Nullable accessToken, NSError * _Nullable error) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        __strong typeof(wself) sself2 = wself;
                        if (!sself2) return;
                        if (accessToken.length > 0) {
                            DDLogInfo(@"[LocationAPISyncService] Interactive OAuth succeeded; performing location API fetch");
                            NSManagedObjectContext *fetchMOC = CoreData.sharedInstance.mainMOC;
                            NSURL *apiURL = [WebAppURLResolver locationAPIRequestURLFromPreferenceInMOC:fetchMOC];
                            if (apiURL) {
                                sself2.fetchInFlight = YES;
                                [sself2 performGET:apiURL accessToken:accessToken allowRetryOn401:YES];
                            }
                        } else {
                            BOOL userCancelled = (error.domain == ASWebAuthenticationSessionErrorDomain &&
                                                 error.code == ASWebAuthenticationSessionErrorCodeCanceledLogin);
                            if (userCancelled) {
                                DDLogInfo(@"[LocationAPISyncService] Interactive OAuth cancelled by user");
                                // flag stays YES — user chose to skip, respect it for this session
                            } else {
                                gLocationAPIOAuthPromptScheduledThisSession = NO; // transient failure — allow retry next poll
                                DDLogVerbose(@"[LocationAPISyncService] Interactive OAuth failed: %@", error.localizedDescription);
                            }
                        }
                    });
                }];
            });
        }];
    });
}

/// Resolves an access token: tries multiple Keychain base URLs (/, /map, preference path), and discovery `client_id` for Keychain lookup (must match WebAppAuthHelper storage after OAuth).
- (void)obtainAccessTokenForLocationAPIWithCompletion:(void (^)(NSString * _Nullable token))completion {
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self obtainAccessTokenForLocationAPIWithCompletion:completion];
        });
        return;
    }
    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
    if (self.cachedAccessToken.length > 0 && self.cachedAccessTokenExpiry > now + 60.0) {
        DDLogVerbose(@"[LocationAPISyncService] obtainAccessToken: reusing cached access token (exp in %.0fs)",
                     self.cachedAccessTokenExpiry - now);
        if (completion) {
            completion(self.cachedAccessToken);
        }
        return;
    }

    NSManagedObjectContext *mainMOC = CoreData.sharedInstance.mainMOC;
    NSArray<NSURL *> *candidates = [WebAppURLResolver webAppKeychainURLCandidatesFromPreferenceInMOC:mainMOC];
    if (candidates.count == 0) {
        if (completion) {
            completion(nil);
        }
        return;
    }

    void (^wrapped)(NSString *) = ^(NSString *tok) {
        if (tok.length > 0) {
            self.cachedAccessToken = tok;
            NSDictionary *claims = [WebAppAuthHelper jwtPayloadClaimsFromToken:tok];
            self.cachedAccessTokenExpiry = [claims[@"exp"] doubleValue];
        }
        if (completion) {
            completion(tok);
        }
    };

    NSString *clientPref = [Settings stringForKey:@"oauth_client_id_preference" inMOC:mainMOC];
    if (clientPref.length == 0) {
        clientPref = nil;
    }

    // Fast path: already cached discovery client_id — build chain without network.
    if (self.cachedOAuthClientIdFromDiscovery.length > 0) {
        NSArray *chain = [self.class orderedKeychainClientIdChainDiscovery:self.cachedOAuthClientIdFromDiscovery settings:clientPref];
        [self trySilentRefreshWithCandidates:candidates clientIdsOrdered:chain idsIndex:0 completion:wrapped];
        return;
    }

    NSURL *origin = [WebAppURLResolver webAppOriginURLFromPreferenceInMOC:mainMOC];
    if (!origin) {
        NSArray *chain = [self.class orderedKeychainClientIdChainDiscovery:nil settings:clientPref];
        [self trySilentRefreshWithCandidates:candidates clientIdsOrdered:chain idsIndex:0 completion:wrapped];
        return;
    }

    __weak typeof(self) wself = self;
    [[WebAppAuthHelper sharedInstance] fetchDiscoveryFromOrigin:origin completion:^(NSDictionary * _Nullable config, NSError * _Nullable error) {
        __strong typeof(wself) sself = wself;
        if (!sself) {
            wrapped(nil);
            return;
        }
        NSString *cid = nil;
        if ([config[@"client_id"] isKindOfClass:[NSString class]] && [(NSString *)config[@"client_id"] length] > 0) {
            cid = config[@"client_id"];
            sself.cachedOAuthClientIdFromDiscovery = cid;
            DDLogInfo(@"[LocationAPISyncService] Cached client_id from owntracks-app-auth for Keychain lookup (may differ from Settings)");
        } else if (error) {
            DDLogVerbose(@"[LocationAPISyncService] Discovery fetch failed: %@ — trying Keychain lookup with Settings client_id only", error.localizedDescription);
        }
        NSArray *chain = [LocationAPISyncService orderedKeychainClientIdChainDiscovery:cid settings:clientPref];
        [sself trySilentRefreshWithCandidates:candidates clientIdsOrdered:chain idsIndex:0 completion:wrapped];
    }];
}

- (void)invalidateOAuthCredentialCache {
    self.cachedAccessToken = nil;
    self.cachedAccessTokenExpiry = 0;
    self.cachedOAuthClientIdFromDiscovery = nil;
    self.fetchInFlight = NO;
    self.provisionInFlight = NO;
    [self.routeHistoryPointsCache removeAllObjects];
    DDLogInfo(@"[LocationAPISyncService] invalidateOAuthCredentialCache");
    @synchronized (self) {
        self.mqttFriendAllowlistLoadedFromLocationAPI = NO;
        self.mqttAllowedFriendDeviceTopics = [NSSet set];
    }
    __weak typeof(self) wself = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        __strong typeof(wself) sself = wself;
        if (!sself) {
            return;
        }
        sself.authorizationUserProfileLoaded = NO;
        sself.authorizationUserIsAdmin = NO;
        sself.authorizationUserCanViewRouteHistory = YES;
        sself.authAPIHomeZoneId = nil;
        sself.authAPIWorkZoneId = nil;
        sself.lastDashcamClips = nil;
        sself.lastDashcamFromUnix = 0;
        sself.lastDashcamToUnix = 0;
        sself.dashcamClipsFetchInFlight = NO;
        [[NSNotificationCenter defaultCenter] postNotificationName:OwnTracksCurrentUserProfileDidUpdateNotification
                                                              object:sself];
        [[NSNotificationCenter defaultCenter] postNotificationName:OwnTracksLocationMQTTAllowlistDidUpdateNotification
                                                              object:sself];
    });
}

- (void)updateFromAuthorizationUserAPIPayload:(NSDictionary *)json {
    if (![json isKindOfClass:[NSDictionary class]] || json.count == 0) {
        return;
    }
    __weak typeof(self) wself = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        __strong typeof(wself) sself = wself;
        if (!sself) {
            return;
        }
        sself.authorizationUserProfileLoaded = YES;
        sself.authorizationUserIsAdmin = OTJSONBoolish(json[@"isAdmin"], NO);
        sself.authorizationUserCanViewRouteHistory = OTJSONBoolish(json[@"canViewRouteHistory"], YES);
        sself.authAPIHomeZoneId = OTNullableIntNumberFromJSON(json[@"homeZoneId"]);
        sself.authAPIWorkZoneId = OTNullableIntNumberFromJSON(json[@"workZoneId"]);
        [[NSNotificationCenter defaultCenter] postNotificationName:OwnTracksCurrentUserProfileDidUpdateNotification
                                                              object:sself];
    });
}

- (BOOL)hasAuthorizationUserProfilePayload {
    return self.authorizationUserProfileLoaded;
}

- (BOOL)currentUserIsAdminFromAuthorizationAPI {
    return self.authorizationUserIsAdmin;
}

- (BOOL)currentUserMayViewRouteHistory {
    if (!self.authorizationUserProfileLoaded) {
        return YES;
    }
    return self.authorizationUserCanViewRouteHistory;
}

- (nullable NSNumber *)authorizationUserHomeZoneId {
    return self.authAPIHomeZoneId;
}

- (nullable NSNumber *)authorizationUserWorkZoneId {
    return self.authAPIWorkZoneId;
}

- (BOOL)currentUserMayViewSensitiveLocationDeviceFields {
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"OTForceLocationAdminForDeviceDetail"]) {
        return YES;
    }
    if (self.authorizationUserProfileLoaded) {
        return self.authorizationUserIsAdmin;
    }
    NSString *tok = self.cachedAccessToken;
    if (!tok.length) {
        return NO;
    }
    NSDictionary *claims = [WebAppAuthHelper jwtPayloadClaimsFromToken:tok];
    return [WebAppAuthHelper claimsIndicateLocationAdmin:claims];
}

- (nullable NSString *)peekCachedDiscoveryOAuthClientId {
    return self.cachedOAuthClientIdFromDiscovery;
}

/// Ordered list: discovery `client_id` (if any), settings id if different, then [NSNull null] to try WebAppAuthHelper lookup with nil (|path|_ + legacy origin).
+ (NSArray *)orderedKeychainClientIdChainDiscovery:(NSString *)discoveryClientId settings:(NSString *)clientPref {
    NSMutableOrderedSet *seen = [NSMutableOrderedSet orderedSet];
    if (discoveryClientId.length > 0) {
        [seen addObject:discoveryClientId];
    }
    if (clientPref.length > 0) {
        [seen addObject:clientPref];
    }
    NSMutableArray *chain = [NSMutableArray array];
    for (NSString *s in seen) {
        [chain addObject:s];
    }
    [chain addObject:[NSNull null]];
    return chain;
}

- (void)trySilentRefreshWithCandidates:(NSArray<NSURL *> *)candidates
                    clientIdsOrdered:(NSArray *)discoveryThenPrefsThenNil
                            idsIndex:(NSUInteger)idsIdx
                            completion:(void (^)(NSString * _Nullable token))completion {
    if (idsIdx >= discoveryThenPrefsThenNil.count) {
        completion(nil);
        return;
    }
    id raw = discoveryThenPrefsThenNil[idsIdx];
    NSString *cid = (raw == [NSNull null]) ? nil : (NSString *)raw;
    __weak typeof(self) wself = self;
    [self trySilentRefreshWithCandidates:candidates clientId:cid index:0 completion:^(NSString * _Nullable accessToken) {
        __strong typeof(wself) sself = wself;
        if (!sself) {
            completion(nil);
            return;
        }
        if (accessToken.length > 0) {
            completion(accessToken);
            return;
        }
        [sself trySilentRefreshWithCandidates:candidates clientIdsOrdered:discoveryThenPrefsThenNil idsIndex:idsIdx + 1 completion:completion];
    }];
}

- (void)trySilentRefreshWithCandidates:(NSArray<NSURL *> *)candidates
                              clientId:(NSString *)clientId
                                 index:(NSUInteger)idx
                            completion:(void (^)(NSString * _Nullable token))completion {
    if (idx >= candidates.count) {
        DDLogInfo(@"[LocationAPISyncService] No OAuth refresh token matched after trying %lu Keychain base URL(s). "
                  @"The location API requires a prior web sign-in (Web tab) or a stored refresh token.",
                  (unsigned long)candidates.count);
        completion(nil);
        return;
    }
    NSURL *u = candidates[idx];
    __weak typeof(self) wself = self;
    [[WebAppAuthHelper sharedInstance] attemptSilentRefreshForWebAppURL:u clientId:clientId completion:^(NSString * _Nullable accessToken, NSError * _Nullable error) {
        __strong typeof(wself) sself = wself;
        if (!sself) {
            completion(nil);
            return;
        }
        if (accessToken.length > 0) {
            DDLogVerbose(@"[LocationAPISyncService] Silent refresh OK for base URL %@", u.absoluteString);
            completion(accessToken);
            return;
        }
        [sself trySilentRefreshWithCandidates:candidates clientId:clientId index:idx + 1 completion:completion];
    }];
}

- (void)performGET:(NSURL *)apiURL accessToken:(NSString *)accessToken allowRetryOn401:(BOOL)allowRetryOn401 {
    [self performGET:apiURL accessToken:accessToken allowRetryOn401:allowRetryOn401 transientAttempt:0];
}

- (BOOL)isTransientLocationAPIURLSessionError:(NSError *)error {
    if (!error) {
        return NO;
    }
    if (![error.domain isEqualToString:NSURLErrorDomain]) {
        return NO;
    }
    switch (error.code) {
        case NSURLErrorTimedOut:
        case NSURLErrorCannotFindHost:
        case NSURLErrorCannotConnectToHost:
        case NSURLErrorNetworkConnectionLost:
        case NSURLErrorNotConnectedToInternet:
        case NSURLErrorDNSLookupFailed:
        case NSURLErrorInternationalRoamingOff:
        case NSURLErrorCallIsActive:
        case NSURLErrorDataNotAllowed:
            return YES;
        default:
            return NO;
    }
}

- (BOOL)isTransientLocationAPIHTTPStatus:(NSInteger)status {
    return status == 408 || status == 429 || status == 502 || status == 503 || status == 504;
}

- (void)scheduleLocationAPIGETRetry:(NSURL *)apiURL
                      accessToken:(NSString *)accessToken
                  allowRetryOn401:(BOOL)allowRetryOn401
                   transientAttempt:(NSUInteger)nextAttempt {
    NSTimeInterval delay = MIN(pow(2.0, (double)nextAttempt), 32.0);
    DDLogInfo(@"[LocationAPISyncService] GET retry in %.0fs (attempt %lu)", delay, (unsigned long)nextAttempt);
    __weak typeof(self) wself = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        __strong typeof(wself) sself = wself;
        if (!sself) {
            return;
        }
        [sself performGET:apiURL accessToken:accessToken allowRetryOn401:allowRetryOn401 transientAttempt:nextAttempt];
    });
}

- (void)performGET:(NSURL *)apiURL
      accessToken:(NSString *)accessToken
 allowRetryOn401:(BOOL)allowRetryOn401
 transientAttempt:(NSUInteger)transientAttempt {
    self.cachedAccessToken = accessToken;
    NSDictionary *atClaims = [WebAppAuthHelper jwtPayloadClaimsFromToken:accessToken];
    self.cachedAccessTokenExpiry = [atClaims[@"exp"] doubleValue]; // 0 if opaque/missing
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:apiURL];
    request.HTTPMethod = @"GET";
    request.timeoutInterval = 30.0;
    [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    [request setValue:[NSString stringWithFormat:@"Bearer %@", accessToken] forHTTPHeaderField:@"Authorization"];

    __weak typeof(self) wself = self;
    NSURLSessionDataTask *task = [LocationAPISyncURLSession() dataTaskWithRequest:request
                                                                 completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        __strong typeof(wself) sself = wself;
        if (!sself) {
            return;
        }
        if (error) {
            DDLogWarn(@"[LocationAPISyncService] GET failed: %@", error.localizedDescription);
            if (transientAttempt < 3 && [sself isTransientLocationAPIURLSessionError:error]) {
                [sself scheduleLocationAPIGETRetry:apiURL accessToken:accessToken allowRetryOn401:allowRetryOn401 transientAttempt:transientAttempt + 1];
            } else {
                sself.fetchInFlight = NO;
            }
            return;
        }
        NSInteger status = [response isKindOfClass:[NSHTTPURLResponse class]] ? [(NSHTTPURLResponse *)response statusCode] : 0;
        if (status == 401 && allowRetryOn401) {
            // Invalidate the cached token so the retry path always gets a fresh one.
            sself.cachedAccessToken = nil;
            sself.cachedAccessTokenExpiry = 0;
            [sself obtainAccessTokenForLocationAPIWithCompletion:^(NSString * _Nullable newToken) {
                __strong typeof(wself) sself2 = wself;
                if (!sself2) {
                    return;
                }
                if (!newToken.length) {
                    DDLogWarn(@"[LocationAPISyncService] 401 and could not obtain a new access token");
                    sself2.fetchInFlight = NO;
                    return;
                }
                [sself2 performGET:apiURL accessToken:newToken allowRetryOn401:NO transientAttempt:0];
            }];
            return;
        }
        if (status != 200) {
            DDLogWarn(@"[LocationAPISyncService] GET status %ld", (long)status);
            if (transientAttempt < 3 && [sself isTransientLocationAPIHTTPStatus:status]) {
                [sself scheduleLocationAPIGETRetry:apiURL accessToken:accessToken allowRetryOn401:allowRetryOn401 transientAttempt:transientAttempt + 1];
            } else {
                sself.fetchInFlight = NO;
            }
            return;
        }
        [sself applyLocationJSONData:data];
        sself.lastSuccessfulLocationAPIFetchDate = [NSDate date];
        sself.fetchInFlight = NO;
    }];
    [task resume];
}

- (void)applyLocationJSONData:(NSData *)data {
    if (!data.length) {
        return;
    }
    NSError *jsonError = nil;
    id obj = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
    if (jsonError || ![obj isKindOfClass:[NSDictionary class]]) {
        DDLogWarn(@"[LocationAPISyncService] JSON parse error: %@", jsonError.localizedDescription);
        return;
    }
    NSDictionary *root = (NSDictionary *)obj;

    NSString *accessTokenSnapshot = self.cachedAccessToken;
    NSManagedObjectContext *mainMOC2 = CoreData.sharedInstance.mainMOC;
    NSURL *originSnapshot = [WebAppURLResolver webAppOriginURLFromPreferenceInMOC:mainMOC2];
    NSManagedObjectContext *queuedMOC = CoreData.sharedInstance.queuedMOC;
    [queuedMOC performBlock:^{
        NSMutableSet<NSString *> *allowedTopics = [NSMutableSet set];
        for (NSString *userKey in root) {
            id entry = root[userKey];
            if (![entry isKindOfClass:[NSDictionary class]]) {
                continue;
            }
            NSDictionary *userDict = (NSDictionary *)entry;
            id devices = userDict[@"devices"];
            if (![devices isKindOfClass:[NSArray class]]) {
                continue;
            }
            for (id dev in (NSArray *)devices) {
                if (![dev isKindOfClass:[NSDictionary class]]) {
                    continue;
                }
                NSDictionary *device = (NSDictionary *)dev;
                NSString *topic = [LocationAPISyncService mqttTopicForLocationAPIDevice:device userKey:userKey];
                if (topic.length) {
                    [allowedTopics addObject:topic];
                }

                NSDictionary *payload = [self.class ownTracksLocationDictionaryFromAPIDevice:device];
                if (!payload) {
                    continue;
                }
                if (!topic.length) {
                    DDLogWarn(@"[LocationAPISyncService] location payload without resolvable MQTT topic, skipping apply");
                    continue;
                }
                if ([topic hasPrefix:@"api/"]) {
                    DDLogInfo(@"[LocationAPISyncService] REST-only device, using synthetic topic %@", topic);
                }

                [[OwnTracking sharedInstance] applyAPILocationPayloadForMqttTopic:topic
                                                                       dictionary:payload
                                                                          context:queuedMOC];

                // Store user name for route API URL construction, and deviceName as the
                // display name if the Friend has no card name yet.
                Friend *syncFriend = [Friend friendWithTopic:topic inManagedObjectContext:queuedMOC];
                if (syncFriend) {
                    syncFriend.routeAPIUser = userKey;
                    id deviceNameObj = device[@"deviceName"];
                    if ([deviceNameObj isKindOfClass:[NSString class]] && [(NSString *)deviceNameObj length] > 0
                            && syncFriend.cardName == nil) {
                        syncFriend.cardName = (NSString *)deviceNameObj;
                    }
                }

                // Fetch device image if not yet stored.
                id imagePathObj = device[@"deviceImage"];
                if ([imagePathObj isKindOfClass:[NSString class]] && [(NSString *)imagePathObj length] > 0) {
                    NSString *imagePath = (NSString *)imagePathObj;
                    Friend *friend = [Friend friendWithTopic:topic inManagedObjectContext:queuedMOC];
                    if (friend && friend.cardImage == nil) {
                        [self fetchDeviceImageAtPath:imagePath accessToken:accessTokenSnapshot forTopic:topic originURL:originSnapshot];
                    }
                }
            }
        }

        NSString *ownTopic = [Settings theGeneralTopicInMOC:queuedMOC];
        NSUInteger pruned = 0;
        NSArray *friendsSnapshot = [Friend allFriendsInManagedObjectContext:queuedMOC];
        for (Friend *friend in friendsSnapshot) {
            NSString *t = friend.topic;
            if (!t.length) {
                continue;
            }
            if (ownTopic.length && [t isEqualToString:ownTopic]) {
                continue;
            }
            if ([allowedTopics containsObject:t]) {
                continue;
            }
            [queuedMOC deleteObject:friend];
            pruned++;
        }

        [CoreData.sharedInstance sync:queuedMOC];
        DDLogInfo(@"[LocationAPISyncService] applied location API payload (allowedTopics=%lu prunedFriends=%lu)",
                  (unsigned long)allowedTopics.count, (unsigned long)pruned);

        NSArray<NSString *> *sortedAllowed = [[allowedTopics allObjects] sortedArrayUsingSelector:@selector(compare:)];
        LocationAPISyncService *las = self;
        dispatch_async(dispatch_get_main_queue(), ^{
            [las OT_applyLocationMQTTAllowlistFromSortedDeviceTopics:sortedAllowed];
        });
    }];
}

+ (nullable NSString *)mqttTopicForLocationAPIDevice:(NSDictionary *)device userKey:(NSString *)userKey {
    id topicObj = device[@"mqttTopic"];
    if ([topicObj isKindOfClass:[NSString class]] && [(NSString *)topicObj length] > 0) {
        return (NSString *)topicObj;
    }
    id trackerIdObj = device[@"trackerId"];
    if (![trackerIdObj isKindOfClass:[NSString class]] || [(NSString *)trackerIdObj length] == 0) {
        DDLogVerbose(@"[LocationAPISyncService] device missing mqttTopic and trackerId, skipping");
        return nil;
    }
    if (!userKey.length) {
        return nil;
    }
    return [NSString stringWithFormat:@"api/%@/%@", userKey, (NSString *)trackerIdObj];
}

+ (nullable NSDictionary *)ownTracksLocationDictionaryFromAPIDevice:(NSDictionary *)device {
    NSNumber *tst = nil;
    id ts = device[@"timestamp"];
    if ([ts isKindOfClass:[NSNumber class]]) {
        tst = (NSNumber *)ts;
    }
    if (!tst) {
        return nil;
    }

    id latObj = device[@"latitude"];
    id lonObj = device[@"longitude"];
    if (![latObj isKindOfClass:[NSNumber class]] || ![lonObj isKindOfClass:[NSNumber class]]) {
        return nil;
    }
    NSNumber *lat = (NSNumber *)latObj;
    NSNumber *lon = (NSNumber *)lonObj;
    if (lat.doubleValue == 0.0 && lon.doubleValue == 0.0) {
        return nil;
    }

    NSMutableDictionary *d = [NSMutableDictionary dictionary];
    d[@"tst"] = tst;
    d[@"lat"] = lat;
    d[@"lon"] = lon;

    id acc = device[@"accuracy"];
    if ([acc isKindOfClass:[NSNumber class]]) {
        d[@"acc"] = acc;
    }
    id alt = device[@"altitude"];
    if ([alt isKindOfClass:[NSNumber class]]) {
        d[@"alt"] = alt;
    }
    id batt = device[@"battery"];
    if ([batt isKindOfClass:[NSNumber class]]) {
        d[@"batt"] = batt;
    }
    id cog = device[@"courseOverGround"];
    if ([cog isKindOfClass:[NSNumber class]]) {
        d[@"cog"] = cog;
    }
    id vel = device[@"velocity"];
    if ([vel isKindOfClass:[NSNumber class]]) {
        d[@"vel"] = vel;
    }
    id trig = device[@"trigger"];
    if ([trig isKindOfClass:[NSString class]]) {
        d[@"t"] = trig;
    }
    id tid = device[@"trackerId"];
    if ([tid isKindOfClass:[NSString class]]) {
        d[@"tid"] = tid;
    }
    id pressure = device[@"pressure"];
    if ([pressure isKindOfClass:[NSNumber class]]) {
        d[@"p"] = pressure;
    }
    id conn = device[@"connection"];
    if ([conn isKindOfClass:[NSString class]] && [(NSString *)conn length] > 0) {
        d[@"conn"] = conn;
    }

    id hr = device[@"hr"];
    if (![hr isKindOfClass:[NSNumber class]]) {
        hr = device[@"heartRate"];
    }
    if ([hr isKindOfClass:[NSNumber class]]) {
        d[@"hr"] = hr;
    }

    id zoneName = device[@"zoneName"];
    if ([zoneName isKindOfClass:[NSString class]] && [(NSString *)zoneName length] > 0) {
        d[@"zonename"] = zoneName;
    }

    return [d copy];
}

- (void)fetchRouteHistoryPointsForRouteUser:(NSString *)routeUser
                              routeDevice:(NSString *)routeDevice
                               startUnix:(NSInteger)startUnix
                                 endUnix:(NSInteger)endUnix
                    managedObjectContext:(NSManagedObjectContext *)moc
                              completion:(void (^)(NSArray<NSDictionary *> * _Nullable points,
                                                   NSError * _Nullable error))completion {
    if (!completion) {
        return;
    }
    void (^deliver)(NSArray<NSDictionary *> *, NSError *) = ^(NSArray<NSDictionary *> *pts, NSError *err) {
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(pts, err);
        });
    };
    if (!routeUser.length || !routeDevice.length) {
        deliver(@[], [NSError errorWithDomain:@"LocationAPISyncService"
                                          code:2
                                      userInfo:@{NSLocalizedDescriptionKey: @"Missing route user or device"}]);
        return;
    }
    NSString *cacheKey = [NSString stringWithFormat:@"%@|%@|%ld|%ld",
                          routeUser, routeDevice, (long)startUnix, (long)endUnix];
    NSArray<NSDictionary *> *cached = [self.routeHistoryPointsCache objectForKey:cacheKey];
    if (cached) {
        DDLogInfo(@"[LocationAPISyncService] route history cache hit %@", cacheKey);
        deliver(cached, nil);
        return;
    }

    NSURL *origin = [WebAppURLResolver webAppOriginURLFromPreferenceInMOC:moc];
    if (!origin) {
        deliver(nil, [NSError errorWithDomain:@"LocationAPISyncService"
                                           code:3
                                       userInfo:@{NSLocalizedDescriptionKey: @"No web app origin URL"}]);
        return;
    }

    NSString *path = [NSString stringWithFormat:@"/api/location/history/%@/%@/route", routeUser, routeDevice];
    NSURLComponents *components = [NSURLComponents componentsWithURL:origin resolvingAgainstBaseURL:NO];
    components.path = path;
    components.queryItems = @[
        [NSURLQueryItem queryItemWithName:@"start" value:@(startUnix).stringValue],
        [NSURLQueryItem queryItemWithName:@"end" value:@(endUnix).stringValue],
    ];
    NSURL *routeURL = components.URL;
    if (!routeURL) {
        deliver(nil, [NSError errorWithDomain:@"LocationAPISyncService"
                                           code:4
                                       userInfo:@{NSLocalizedDescriptionKey: @"Could not build route URL"}]);
        return;
    }

    DDLogInfo(@"[LocationAPISyncService] route history GET %@ (start=%ld end=%ld)", routeURL, (long)startUnix, (long)endUnix);
    __weak typeof(self) wself = self;
    [self performAuthenticatedGET:routeURL
                         completion:^(NSData * _Nullable data, NSError * _Nullable error) {
        __strong typeof(wself) sself = wself;
        if (!sself) {
            deliver(nil, [NSError errorWithDomain:@"LocationAPISyncService" code:0 userInfo:nil]);
            return;
        }
        if (error || !data.length) {
            deliver(nil, error ?: [NSError errorWithDomain:@"LocationAPISyncService"
                                                      code:5
                                                  userInfo:@{NSLocalizedDescriptionKey: @"Empty route response"}]);
            return;
        }
        NSError *parseErr = nil;
        NSArray<NSDictionary *> *points = OTExtractRouteHistoryPointsFromJSONData(data, &parseErr);
        if (parseErr) {
            DDLogWarn(@"[LocationAPISyncService] route history JSON error: %@", parseErr.localizedDescription);
        }
        if (!points) {
            deliver(nil, parseErr);
            return;
        }
        NSTimeInterval minTs = 0;
        NSTimeInterval maxTs = 0;
        BOOL haveTs = NO;
        for (NSDictionary *d in points) {
            NSTimeInterval u = OTRouteHistoryPointUnixTime(d);
            if (!isnan(u)) {
                if (!haveTs) {
                    minTs = maxTs = u;
                    haveTs = YES;
                } else {
                    minTs = MIN(minTs, u);
                    maxTs = MAX(maxTs, u);
                }
            }
        }
        if (haveTs) {
            DDLogInfo(@"[LocationAPISyncService] route history parsed %lu points tst span=%.0fs (%.2fh) min=%.0f max=%.0f",
                      (unsigned long)points.count, maxTs - minTs, (maxTs - minTs) / 3600.0, minTs, maxTs);
        } else {
            DDLogWarn(@"[LocationAPISyncService] route history parsed %lu points but none had parsable tst — check API field names",
                      (unsigned long)points.count);
        }
        if (points.count > 0) {
            [sself.routeHistoryPointsCache setObject:points forKey:cacheKey];
        }
        deliver(points, nil);
    }];
}

- (void)performAuthenticatedGET:(NSURL *)url completion:(void (^)(NSData * _Nullable, NSError * _Nullable))completion {
    DDLogInfo(@"[LocationAPISyncService] performAuthenticatedGET: obtaining token for %@", url);
    __weak typeof(self) wself = self;
    [self obtainAccessTokenForLocationAPIWithCompletion:^(NSString * _Nullable accessToken) {
        __strong typeof(wself) sself = wself;
        if (!sself) {
            completion(nil, [NSError errorWithDomain:@"LocationAPISyncService" code:0 userInfo:nil]);
            return;
        }
        if (!accessToken.length) {
            DDLogWarn(@"[LocationAPISyncService] performAuthenticatedGET: no access token for %@", url);
            completion(nil, [NSError errorWithDomain:@"LocationAPISyncService" code:401 userInfo:nil]);
            return;
        }
        DDLogInfo(@"[LocationAPISyncService] performAuthenticatedGET: token OK, sending GET %@", url);

        __block void (^runGET)(NSString *token, NSUInteger transientAttempt);
        runGET = ^(NSString *token, NSUInteger transientAttempt) {
            __strong typeof(wself) sselfInner = wself;
            if (!sselfInner) {
                completion(nil, [NSError errorWithDomain:@"LocationAPISyncService" code:0 userInfo:nil]);
                return;
            }
            NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
            request.HTTPMethod = @"GET";
            request.timeoutInterval = 30.0;
            [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
            [request setValue:[NSString stringWithFormat:@"Bearer %@", token] forHTTPHeaderField:@"Authorization"];

            [[LocationAPISyncURLSession() dataTaskWithRequest:request
                                            completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
                __strong typeof(wself) sself2 = wself;
                if (!sself2) {
                    completion(nil, [NSError errorWithDomain:@"LocationAPISyncService" code:0 userInfo:nil]);
                    return;
                }
                if (error) {
                    DDLogWarn(@"[LocationAPISyncService] performAuthenticatedGET network error: %@", error.localizedDescription);
                    if (transientAttempt < 3 && [sself2 isTransientLocationAPIURLSessionError:error]) {
                        NSTimeInterval delay = MIN(pow(2.0, (double)(transientAttempt + 1)), 32.0);
                        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                            runGET(token, transientAttempt + 1);
                        });
                    } else {
                        completion(nil, error);
                    }
                    return;
                }
                NSInteger status = [response isKindOfClass:[NSHTTPURLResponse class]] ? [(NSHTTPURLResponse *)response statusCode] : 0;
                DDLogInfo(@"[LocationAPISyncService] performAuthenticatedGET: HTTP %ld (%lu bytes) for %@",
                          (long)status, (unsigned long)data.length, url);
                if (status == 401) {
                    DDLogInfo(@"[LocationAPISyncService] performAuthenticatedGET: 401 — refreshing token and retrying %@", url);
                    [sself2 obtainAccessTokenForLocationAPIWithCompletion:^(NSString * _Nullable newToken) {
                        if (!newToken.length) {
                            DDLogWarn(@"[LocationAPISyncService] performAuthenticatedGET: 401 retry — could not refresh token for %@", url);
                            completion(nil, [NSError errorWithDomain:@"LocationAPISyncService" code:401 userInfo:nil]);
                            return;
                        }
                        runGET(newToken, 0);
                    }];
                    return;
                }
                if (status != 200) {
                    DDLogWarn(@"[LocationAPISyncService] performAuthenticatedGET HTTP %ld for %@", (long)status, url);
                    if (transientAttempt < 3 && [sself2 isTransientLocationAPIHTTPStatus:status]) {
                        NSTimeInterval delay = MIN(pow(2.0, (double)(transientAttempt + 1)), 32.0);
                        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                            runGET(token, transientAttempt + 1);
                        });
                    } else {
                        completion(nil, [NSError errorWithDomain:@"LocationAPISyncService" code:status userInfo:nil]);
                    }
                    return;
                }
                completion(data, nil);
            }] resume];
        };
        runGET(accessToken, 0);
    }];
}

- (void)performAuthenticatedRequestWithURL:(NSURL *)url
                                    method:(NSString *)method
                                  jsonBody:(NSDictionary *)jsonBody
                                completion:(void (^)(NSData * _Nullable, NSInteger, NSError * _Nullable))completion {
    if (!url) {
        completion(nil, 0, [NSError errorWithDomain:@"LocationAPISyncService"
                                                code:1
                                            userInfo:@{NSLocalizedDescriptionKey: @"Missing API URL"}]);
        return;
    }
    __weak typeof(self) wself = self;
    [self obtainAccessTokenForLocationAPIWithCompletion:^(NSString * _Nullable accessToken) {
        __strong typeof(wself) sself = wself;
        if (!sself) {
            completion(nil, 0, [NSError errorWithDomain:@"LocationAPISyncService" code:0 userInfo:nil]);
            return;
        }
        if (!accessToken.length) {
            completion(nil, 401, [NSError errorWithDomain:@"LocationAPISyncService"
                                                      code:401
                                                  userInfo:@{NSLocalizedDescriptionKey: @"No access token"}]);
            return;
        }

        __block void (^runRequest)(NSString *token, BOOL allowRetryOn401, NSUInteger transientAttempt);
        runRequest = ^(NSString *token, BOOL allowRetryOn401, NSUInteger transientAttempt) {
            NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
            request.HTTPMethod = method;
            request.timeoutInterval = 30.0;
            [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
            [request setValue:[NSString stringWithFormat:@"Bearer %@", token] forHTTPHeaderField:@"Authorization"];
            if (jsonBody) {
                NSError *jsonErr = nil;
                NSData *bodyData = [NSJSONSerialization dataWithJSONObject:jsonBody options:0 error:&jsonErr];
                if (!bodyData || jsonErr) {
                    completion(nil, 0, jsonErr ?: [NSError errorWithDomain:@"LocationAPISyncService" code:2 userInfo:nil]);
                    return;
                }
                [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
                request.HTTPBody = bodyData;
            }

            [[LocationAPISyncURLSession() dataTaskWithRequest:request
                                            completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
                if (error) {
                    if (transientAttempt < 3 && [sself isTransientLocationAPIURLSessionError:error]) {
                        NSTimeInterval delay = MIN(pow(2.0, (double)(transientAttempt + 1)), 32.0);
                        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                            runRequest(token, allowRetryOn401, transientAttempt + 1);
                        });
                        return;
                    }
                    completion(nil, 0, error);
                    return;
                }
                NSInteger status = [response isKindOfClass:[NSHTTPURLResponse class]]
                    ? [(NSHTTPURLResponse *)response statusCode]
                    : 0;
                if (status == 401 && allowRetryOn401) {
                    [sself obtainAccessTokenForLocationAPIWithCompletion:^(NSString * _Nullable newToken) {
                        if (!newToken.length) {
                            completion(data, status, [NSError errorWithDomain:@"LocationAPISyncService"
                                                                          code:401
                                                                      userInfo:@{NSLocalizedDescriptionKey: @"Unauthorized"}]);
                            return;
                        }
                        runRequest(newToken, NO, 0);
                    }];
                    return;
                }
                if ([sself isTransientLocationAPIHTTPStatus:status] && transientAttempt < 3) {
                    NSTimeInterval delay = MIN(pow(2.0, (double)(transientAttempt + 1)), 32.0);
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                        runRequest(token, allowRetryOn401, transientAttempt + 1);
                    });
                    return;
                }
                completion(data, status, nil);
            }] resume];
        };
        runRequest(accessToken, YES, 0);
    }];
}

- (NSError *)errorForStatus:(NSInteger)status fallbackDomain:(NSString *)domain {
    NSString *message = status > 0 ? [NSString stringWithFormat:@"HTTP %ld", (long)status] : @"Request failed";
    return [NSError errorWithDomain:domain
                               code:(status > 0 ? status : 1)
                           userInfo:@{NSLocalizedDescriptionKey: message}];
}

- (OTWebLocationItem *)locationItemFromDictionary:(NSDictionary *)dict {
    NSNumber *locationId = [dict[@"id"] isKindOfClass:[NSNumber class]] ? dict[@"id"] : nil;
    if (!locationId && [dict[@"id"] isKindOfClass:[NSString class]]) {
        locationId = @([(NSString *)dict[@"id"] integerValue]);
    }
    NSNumber *lat = [dict[@"latitude"] isKindOfClass:[NSNumber class]] ? dict[@"latitude"] : nil;
    if (!lat && [dict[@"latitude"] isKindOfClass:[NSString class]]) {
        lat = @([(NSString *)dict[@"latitude"] doubleValue]);
    }
    NSNumber *lon = [dict[@"longitude"] isKindOfClass:[NSNumber class]] ? dict[@"longitude"] : nil;
    if (!lon && [dict[@"longitude"] isKindOfClass:[NSString class]]) {
        lon = @([(NSString *)dict[@"longitude"] doubleValue]);
    }
    NSString *displayName = [dict[@"displayName"] isKindOfClass:[NSString class]] ? dict[@"displayName"] : nil;
    NSString *originalDisplayName = [dict[@"originalDisplayName"] isKindOfClass:[NSString class]] ? dict[@"originalDisplayName"] : nil;
    NSString *createdAt = [dict[@"createdAt"] isKindOfClass:[NSString class]] ? dict[@"createdAt"] : nil;
    NSString *lastAccessed = [dict[@"lastAccessed"] isKindOfClass:[NSString class]] ? dict[@"lastAccessed"] : nil;
    if (!locationId || !lat || !lon) {
        return nil;
    }

    NSISO8601DateFormatter *iso = [[NSISO8601DateFormatter alloc] init];
    iso.formatOptions = NSISO8601DateFormatWithInternetDateTime | NSISO8601DateFormatWithFractionalSeconds;
    NSDate *createdDate = createdAt.length > 0 ? [iso dateFromString:createdAt] : nil;
    NSDate *lastAccessedDate = lastAccessed.length > 0 ? [iso dateFromString:lastAccessed] : nil;
    if (!createdDate) {
        NSISO8601DateFormatter *fallbackISO = [[NSISO8601DateFormatter alloc] init];
        createdDate = createdAt.length > 0 ? [fallbackISO dateFromString:createdAt] : nil;
    }
    if (!lastAccessedDate) {
        NSISO8601DateFormatter *fallbackISO = [[NSISO8601DateFormatter alloc] init];
        lastAccessedDate = lastAccessed.length > 0 ? [fallbackISO dateFromString:lastAccessed] : nil;
    }
    if (!createdDate) {
        createdDate = [NSDate date];
    }
    if (!lastAccessedDate) {
        lastAccessedDate = createdDate;
    }
    if (displayName.length == 0) {
        displayName = originalDisplayName.length > 0 ? originalDisplayName : [NSString stringWithFormat:@"Location %ld", (long)locationId.integerValue];
    }

    OTWebLocationItem *item = [[OTWebLocationItem alloc] init];
    item.locationId = locationId.integerValue;
    item.latitude = lat.doubleValue;
    item.longitude = lon.doubleValue;
    item.displayName = displayName;
    item.originalDisplayName = originalDisplayName;
    item.mapsUrl = [dict[@"mapsUrl"] isKindOfClass:[NSString class]] ? dict[@"mapsUrl"] : nil;
    item.createdAt = createdDate;
    item.lastAccessed = lastAccessedDate;
    item.sourceType = [dict[@"sourceType"] isKindOfClass:[NSString class]] ? dict[@"sourceType"] : nil;
    item.radius = [dict[@"radius"] isKindOfClass:[NSNumber class]] ? dict[@"radius"] : nil;
    item.sourceDeviceName = [dict[@"sourceDeviceName"] isKindOfClass:[NSString class]] ? dict[@"sourceDeviceName"] : nil;
    return item;
}

- (OTWebNotificationItem *)notificationItemFromDictionary:(NSDictionary *)dict {
    NSNumber *nid = [dict[@"id"] isKindOfClass:[NSNumber class]] ? dict[@"id"] : nil;
    if (!nid && [dict[@"id"] isKindOfClass:[NSString class]]) {
        nid = @([(NSString *)dict[@"id"] integerValue]);
    }
    NSNumber *userId = [dict[@"userId"] isKindOfClass:[NSNumber class]] ? dict[@"userId"] : nil;
    if (!userId && [dict[@"userId"] isKindOfClass:[NSString class]]) {
        userId = @([(NSString *)dict[@"userId"] integerValue]);
    }
    NSString *type = [dict[@"type"] isKindOfClass:[NSString class]] ? dict[@"type"] : nil;
    NSString *title = [dict[@"title"] isKindOfClass:[NSString class]] ? dict[@"title"] : @"";
    NSString *summary = [dict[@"summary"] isKindOfClass:[NSString class]] ? dict[@"summary"] : @"";
    NSString *notificationId = [dict[@"notificationId"] isKindOfClass:[NSString class]] ? dict[@"notificationId"] : @"";
    NSNumber *isRead = [dict[@"isRead"] isKindOfClass:[NSNumber class]] ? dict[@"isRead"] : nil;
    if (!isRead && [dict[@"isRead"] isKindOfClass:[NSString class]]) {
        NSString *rawRead = [(NSString *)dict[@"isRead"] lowercaseString];
        isRead = @([rawRead isEqualToString:@"true"] || [rawRead isEqualToString:@"1"]);
    }
    NSString *createdAt = [dict[@"createdAt"] isKindOfClass:[NSString class]] ? dict[@"createdAt"] : nil;
    if (!nid || !isRead) {
        return nil;
    }

    NSISO8601DateFormatter *iso = [[NSISO8601DateFormatter alloc] init];
    iso.formatOptions = NSISO8601DateFormatWithInternetDateTime | NSISO8601DateFormatWithFractionalSeconds;
    NSDate *createdDate = createdAt.length > 0 ? [iso dateFromString:createdAt] : nil;
    if (!createdDate && createdAt.length > 0) {
        NSISO8601DateFormatter *fallbackISO = [[NSISO8601DateFormatter alloc] init];
        createdDate = [fallbackISO dateFromString:createdAt];
    }
    if (!createdDate) {
        createdDate = [NSDate date];
    }
    if (type.length == 0) {
        type = @"Unknown";
    }

    OTWebNotificationItem *item = [[OTWebNotificationItem alloc] init];
    item.notificationIdValue = nid.integerValue;
    item.userId = userId.integerValue;
    item.type = type;
    item.title = title;
    item.summary = summary;
    item.dataString = [dict[@"data"] isKindOfClass:[NSString class]] ? dict[@"data"] : nil;
    if (item.dataString.length > 0) {
        NSData *data = [item.dataString dataUsingEncoding:NSUTF8StringEncoding];
        if (data) {
            id parsed = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            if ([parsed isKindOfClass:[NSDictionary class]]) {
                item.dataDictionary = parsed;
            }
        }
    }
    item.notificationId = notificationId.length > 0 ? notificationId : [NSString stringWithFormat:@"%ld", (long)item.notificationIdValue];
    item.isRead = isRead.boolValue;
    item.createdAt = createdDate;
    NSString *readAt = [dict[@"readAt"] isKindOfClass:[NSString class]] ? dict[@"readAt"] : nil;
    item.readAt = readAt.length > 0 ? [iso dateFromString:readAt] : nil;
    return item;
}

- (void)requestGeolocationCachePrefetchIfAppropriate {
    if (self.geolocationCacheFetchInFlight) {
        DDLogVerbose(@"[LocationAPISyncService] geolocationcache prefetch skipped (fetch in flight)");
        return;
    }
    NSManagedObjectContext *moc = CoreData.sharedInstance.mainMOC;
    NSURL *url = [WebAppURLResolver geolocationCacheAPIRequestURLFromPreferenceInMOC:moc];
    if (!url) {
        return;
    }
    NSDate *last = self.lastSuccessfulGeolocationCacheFetchDate;
    NSTimeInterval sinceLastSuccess = last ? [[NSDate date] timeIntervalSinceDate:last] : DBL_MAX;
    BOOL hasCachedItems = (self.lastGeolocationCacheItems.count > 0);
    // When we already have zones, keep the 25s debounce. When the cache is still empty (cold start, transient
    // failure, or first paint before GET completed), allow retries sooner so Friends list can resolve names.
    static const NSTimeInterval kOTGeolocationCacheEmptyRetryMinIntervalSeconds = 5.0;
    if (sinceLastSuccess < kOTGeolocationCachePrefetchMinIntervalSeconds) {
        if (hasCachedItems) {
            DDLogVerbose(@"[LocationAPISyncService] geolocationcache prefetch skipped (last fetch %.1fs ago, cache populated)",
                         sinceLastSuccess);
            return;
        }
        if (sinceLastSuccess < kOTGeolocationCacheEmptyRetryMinIntervalSeconds) {
            DDLogVerbose(@"[LocationAPISyncService] geolocationcache prefetch skipped (empty cache, last attempt %.1fs ago)",
                         sinceLastSuccess);
            return;
        }
    }
    self.geolocationCacheFetchInFlight = YES;
    __weak typeof(self) wself = self;
    [self fetchGeolocationCacheWithCompletion:^(NSArray<OTWebLocationItem *> * _Nullable locations, NSError * _Nullable error) {
        if (error) {
            DDLogVerbose(@"[LocationAPISyncService] geolocationcache prefetch: %@", error.localizedDescription);
        }
        (void)wself;
    }];
}

- (nullable OTWebLocationItem *)geolocationItemContainingCoordinate:(CLLocationCoordinate2D)coordinate {
    if (!CLLocationCoordinate2DIsValid(coordinate)) {
        return nil;
    }
    NSArray<OTWebLocationItem *> *items = self.lastGeolocationCacheItems;
    if (items.count == 0) {
        return nil;
    }
    CLLocation *point = [[CLLocation alloc] initWithLatitude:coordinate.latitude longitude:coordinate.longitude];
    OTWebLocationItem *best = nil;
    CLLocationDistance bestDistance = DBL_MAX;
    NSInteger bestLocationId = NSIntegerMax;

    for (OTWebLocationItem *item in items) {
        if ([item.sourceType isEqualToString:@"Destination"]) {
            continue;
        }
        if (OTWebLocationItemHasFollowStyleName(item)) {
            continue;
        }
        CLLocationDistance radiusM = kOTGeolocationCacheDefaultRadiusMeters;
        if (item.radius != nil) {
            double r = item.radius.doubleValue;
            if (r > 0 && isfinite(r)) {
                radiusM = r;
            }
        }
        CLLocation *center = [[CLLocation alloc] initWithLatitude:item.latitude longitude:item.longitude];
        CLLocationDistance d = fabs([point distanceFromLocation:center]);
        if (d <= radiusM) {
            if (d < bestDistance - 1e-6 || (fabs(d - bestDistance) < 1e-6 && item.locationId < bestLocationId)) {
                best = item;
                bestDistance = d;
                bestLocationId = item.locationId;
            }
        }
    }
    return best;
}

- (void)fetchGeolocationCacheWithCompletion:(void (^)(NSArray<OTWebLocationItem *> * _Nullable, NSError * _Nullable))completion {
    NSURL *url = [WebAppURLResolver geolocationCacheAPIRequestURLFromPreferenceInMOC:CoreData.sharedInstance.mainMOC];
    if (!url) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.geolocationCacheFetchInFlight = NO;
        });
        if (completion) {
            completion(nil, [NSError errorWithDomain:@"LocationAPISyncService" code:1 userInfo:@{NSLocalizedDescriptionKey: @"No geolocation cache URL"}]);
        }
        return;
    }
    __weak typeof(self) wself = self;
    [self performAuthenticatedRequestWithURL:url method:@"GET" jsonBody:nil completion:^(NSData *data, NSInteger statusCode, NSError *error) {
        void (^finishFailure)(NSError *) = ^(NSError *err) {
            dispatch_async(dispatch_get_main_queue(), ^{
                __strong typeof(wself) sself = wself;
                if (sself) {
                    sself.geolocationCacheFetchInFlight = NO;
                }
            });
            if (completion) {
                completion(nil, err);
            }
        };

        if (error) {
            finishFailure(error);
            return;
        }
        if (statusCode != 200) {
            finishFailure([self errorForStatus:statusCode fallbackDomain:@"LocationAPISyncService"]);
            return;
        }
        NSError *jsonErr = nil;
        id obj = [NSJSONSerialization JSONObjectWithData:data ?: [NSData data] options:0 error:&jsonErr];
        if (jsonErr || (![obj isKindOfClass:[NSArray class]] && ![obj isKindOfClass:[NSDictionary class]])) {
            finishFailure(jsonErr ?: [NSError errorWithDomain:@"LocationAPISyncService" code:2 userInfo:nil]);
            return;
        }
        NSArray *rawList = nil;
        if ([obj isKindOfClass:[NSArray class]]) {
            rawList = (NSArray *)obj;
        } else {
            NSDictionary *root = (NSDictionary *)obj;
            if ([root[@"locations"] isKindOfClass:[NSArray class]]) {
                rawList = root[@"locations"];
            } else if ([root[@"geolocationcache"] isKindOfClass:[NSArray class]]) {
                rawList = root[@"geolocationcache"];
            }
        }
        if (!rawList) {
            finishFailure([NSError errorWithDomain:@"LocationAPISyncService" code:2 userInfo:@{NSLocalizedDescriptionKey: @"Invalid geolocationcache payload"}]);
            return;
        }
        NSMutableArray<OTWebLocationItem *> *out = [NSMutableArray array];
        for (id entry in rawList) {
            if (![entry isKindOfClass:[NSDictionary class]]) {
                continue;
            }
            OTWebLocationItem *item = [self locationItemFromDictionary:entry];
            if (item) {
                [out addObject:item];
            }
        }
        DDLogInfo(@"[LocationAPISyncService] geolocationcache parsed=%lu", (unsigned long)out.count);
        NSArray<OTWebLocationItem *> *result = [out copy];
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(wself) sself = wself;
            if (!sself) {
                if (completion) {
                    completion(result, nil);
                }
                return;
            }
            sself.lastGeolocationCacheItems = result;
            sself.lastSuccessfulGeolocationCacheFetchDate = [NSDate date];
            sself.geolocationCacheFetchInFlight = NO;
            [[NSNotificationCenter defaultCenter] postNotificationName:OwnTracksGeolocationCacheDidUpdateNotification object:sself];
            if (completion) {
                completion(result, nil);
            }
        });
    }];
}

- (NSError *)locationDeleteErrorFromData:(NSData *)data statusCode:(NSInteger)statusCode {
    NSString *message = [NSString stringWithFormat:@"HTTP %ld", (long)statusCode];
    NSString *errorCode = nil;
    NSNumber *referenceCount = nil;
    if (data.length > 0) {
        id obj = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        if ([obj isKindOfClass:[NSDictionary class]]) {
            NSDictionary *dict = (NSDictionary *)obj;
            if ([dict[@"message"] isKindOfClass:[NSString class]] && [(NSString *)dict[@"message"] length] > 0) {
                message = (NSString *)dict[@"message"];
            } else if ([dict[@"error"] isKindOfClass:[NSString class]] && [(NSString *)dict[@"error"] length] > 0) {
                message = (NSString *)dict[@"error"];
            }
            if ([dict[@"error"] isKindOfClass:[NSString class]]) {
                errorCode = (NSString *)dict[@"error"];
            }
            if ([dict[@"referenceCount"] isKindOfClass:[NSNumber class]]) {
                referenceCount = (NSNumber *)dict[@"referenceCount"];
            }
        }
    }
    NSMutableDictionary *userInfo = [@{NSLocalizedDescriptionKey: message,
                                       OTLocationDeleteErrorMessageKey: message} mutableCopy];
    if (errorCode.length > 0) {
        userInfo[OTLocationDeleteErrorCodeKey] = errorCode;
    }
    if (referenceCount) {
        userInfo[OTLocationDeleteErrorReferenceCountKey] = referenceCount;
    }
    return [NSError errorWithDomain:@"LocationAPISyncService"
                               code:statusCode > 0 ? statusCode : 1
                           userInfo:userInfo];
}

- (void)deleteGeolocationCacheLocationId:(NSInteger)locationId
                       replacementZoneId:(NSNumber *)replacementZoneId
                              completion:(void (^)(NSInteger, NSNumber * _Nullable, NSError * _Nullable))completion {
    NSMutableArray<NSURLQueryItem *> *queryItems = [NSMutableArray array];
    if (replacementZoneId) {
        [queryItems addObject:[NSURLQueryItem queryItemWithName:@"replacementZoneId"
                                                          value:[replacementZoneId stringValue]]];
    }
    NSString *path = [NSString stringWithFormat:@"/api/geolocationcache/%ld", (long)locationId];
    NSURL *url = [WebAppURLResolver geolocationCacheAPIURLFromPreferenceInMOC:CoreData.sharedInstance.mainMOC
                                                                  relativePath:path
                                                                    queryItems:queryItems.count > 0 ? queryItems : nil];
    [self performAuthenticatedRequestWithURL:url method:@"DELETE" jsonBody:nil completion:^(NSData *data, NSInteger statusCode, NSError *error) {
        if (error) {
            completion(0, nil, error);
            return;
        }
        if (statusCode < 200 || statusCode >= 300) {
            completion(0, nil, [self locationDeleteErrorFromData:data statusCode:statusCode]);
            return;
        }
        NSInteger updatedRefs = 0;
        NSNumber *echoedReplacement = nil;
        if (data.length > 0) {
            id obj = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            if ([obj isKindOfClass:[NSDictionary class]]) {
                NSDictionary *dict = (NSDictionary *)obj;
                if ([dict[@"updatedReferences"] isKindOfClass:[NSNumber class]]) {
                    updatedRefs = [dict[@"updatedReferences"] integerValue];
                }
                if ([dict[@"replacementZoneId"] isKindOfClass:[NSNumber class]]) {
                    echoedReplacement = (NSNumber *)dict[@"replacementZoneId"];
                }
            }
        }
        completion(updatedRefs, echoedReplacement, nil);
    }];
}

- (void)fetchNotificationsWithSkip:(NSInteger)skip
                              take:(NSInteger)take
                       includeRead:(BOOL)includeRead
                              type:(NSString *)type
                        completion:(void (^)(OTWebNotificationsPage * _Nullable, NSError * _Nullable))completion {
    NSString *apiType = type;
    if ([apiType isEqualToString:@"ZoneTransition"]) {
        apiType = @"ZoneChanged";
    }
    NSURL *url = [WebAppURLResolver notificationsAPIRequestURLFromPreferenceInMOC:CoreData.sharedInstance.mainMOC
                                                                              skip:MAX(skip, 0)
                                                                              take:MAX(take, 1)
                                                                       includeRead:includeRead
                                                                              type:apiType];
    if (!url) {
        completion(nil, [NSError errorWithDomain:@"LocationAPISyncService" code:1 userInfo:@{NSLocalizedDescriptionKey: @"No notifications URL"}]);
        return;
    }
    [self performAuthenticatedRequestWithURL:url method:@"GET" jsonBody:nil completion:^(NSData *data, NSInteger statusCode, NSError *error) {
        if (error) {
            completion(nil, error);
            return;
        }
        if (statusCode != 200) {
            completion(nil, [self errorForStatus:statusCode fallbackDomain:@"LocationAPISyncService"]);
            return;
        }
        NSError *jsonErr = nil;
        id obj = [NSJSONSerialization JSONObjectWithData:data ?: [NSData data] options:0 error:&jsonErr];
        if (jsonErr || (![obj isKindOfClass:[NSDictionary class]] && ![obj isKindOfClass:[NSArray class]])) {
            completion(nil, jsonErr ?: [NSError errorWithDomain:@"LocationAPISyncService" code:2 userInfo:nil]);
            return;
        }
        NSDictionary *root = nil;
        NSArray *list = nil;
        if ([obj isKindOfClass:[NSDictionary class]]) {
            root = (NSDictionary *)obj;
            list = [root[@"notifications"] isKindOfClass:[NSArray class]] ? root[@"notifications"] : nil;
        } else if ([obj isKindOfClass:[NSArray class]]) {
            // Be tolerant in case backend returns a bare array.
            list = (NSArray *)obj;
            root = @{};
        }
        if (!list) {
            completion(nil, [NSError errorWithDomain:@"LocationAPISyncService" code:2 userInfo:@{NSLocalizedDescriptionKey: @"Invalid notifications payload"}]);
            return;
        }
        NSMutableArray<OTWebNotificationItem *> *items = [NSMutableArray array];
        for (id entry in list) {
            if (![entry isKindOfClass:[NSDictionary class]]) {
                continue;
            }
            OTWebNotificationItem *item = [self notificationItemFromDictionary:entry];
            if (item) {
                [items addObject:item];
            }
        }
        OTWebNotificationsPage *page = [[OTWebNotificationsPage alloc] init];
        page.notifications = [items copy];
        page.totalCount = [root[@"totalCount"] isKindOfClass:[NSNumber class]] ? [root[@"totalCount"] integerValue] : items.count;
        page.skip = [root[@"skip"] isKindOfClass:[NSNumber class]] ? [root[@"skip"] integerValue] : MAX(skip, 0);
        page.take = [root[@"take"] isKindOfClass:[NSNumber class]] ? [root[@"take"] integerValue] : MAX(take, 1);
        DDLogInfo(@"[LocationAPISyncService] notifications parsed=%lu total=%ld skip=%ld take=%ld",
                  (unsigned long)items.count, (long)page.totalCount, (long)page.skip, (long)page.take);
        completion(page, nil);
    }];
}

- (void)fetchUnreadNotificationCountWithCompletion:(void (^)(NSInteger, NSError * _Nullable))completion {
    NSURL *url = [WebAppURLResolver notificationsUnreadCountAPIRequestURLFromPreferenceInMOC:CoreData.sharedInstance.mainMOC];
    if (!url) {
        completion(0, [NSError errorWithDomain:@"LocationAPISyncService" code:1 userInfo:@{NSLocalizedDescriptionKey: @"No unread-count URL"}]);
        return;
    }
    [self performAuthenticatedRequestWithURL:url method:@"GET" jsonBody:nil completion:^(NSData *data, NSInteger statusCode, NSError *error) {
        if (error) {
            completion(0, error);
            return;
        }
        if (statusCode != 200) {
            completion(0, [self errorForStatus:statusCode fallbackDomain:@"LocationAPISyncService"]);
            return;
        }
        id obj = [NSJSONSerialization JSONObjectWithData:data ?: [NSData data] options:0 error:nil];
        if (![obj isKindOfClass:[NSDictionary class]] || ![obj[@"count"] isKindOfClass:[NSNumber class]]) {
            completion(0, [NSError errorWithDomain:@"LocationAPISyncService" code:2 userInfo:nil]);
            return;
        }
        completion([obj[@"count"] integerValue], nil);
    }];
}

- (void)markNotificationRead:(NSInteger)notificationId completion:(void (^)(NSError * _Nullable))completion {
    NSString *path = [NSString stringWithFormat:@"/api/notifications/%ld/read", (long)notificationId];
    NSURL *url = [WebAppURLResolver notificationsAPIURLFromPreferenceInMOC:CoreData.sharedInstance.mainMOC relativePath:path];
    [self performAuthenticatedRequestWithURL:url method:@"PUT" jsonBody:nil completion:^(NSData *data, NSInteger statusCode, NSError *error) {
        completion(error ?: ((statusCode >= 200 && statusCode < 300) ? nil : [self errorForStatus:statusCode fallbackDomain:@"LocationAPISyncService"]));
    }];
}

- (void)markAllNotificationsReadWithCompletion:(void (^)(NSError * _Nullable))completion {
    NSURL *url = [WebAppURLResolver notificationsAPIURLFromPreferenceInMOC:CoreData.sharedInstance.mainMOC relativePath:@"/api/notifications/read-all"];
    [self performAuthenticatedRequestWithURL:url method:@"PUT" jsonBody:nil completion:^(NSData *data, NSInteger statusCode, NSError *error) {
        completion(error ?: ((statusCode >= 200 && statusCode < 300) ? nil : [self errorForStatus:statusCode fallbackDomain:@"LocationAPISyncService"]));
    }];
}

- (void)bulkMarkNotificationsRead:(NSArray<NSNumber *> *)notificationIds completion:(void (^)(NSError * _Nullable))completion {
    NSURL *url = [WebAppURLResolver notificationsAPIURLFromPreferenceInMOC:CoreData.sharedInstance.mainMOC relativePath:@"/api/notifications/bulk-read"];
    NSDictionary *body = @{@"notificationIds": notificationIds ?: @[]};
    [self performAuthenticatedRequestWithURL:url method:@"PUT" jsonBody:body completion:^(NSData *data, NSInteger statusCode, NSError *error) {
        completion(error ?: ((statusCode >= 200 && statusCode < 300) ? nil : [self errorForStatus:statusCode fallbackDomain:@"LocationAPISyncService"]));
    }];
}

- (void)markNotificationUnread:(NSInteger)notificationId completion:(void (^)(NSError * _Nullable))completion {
    NSString *path = [NSString stringWithFormat:@"/api/notifications/%ld/unread", (long)notificationId];
    NSURL *url = [WebAppURLResolver notificationsAPIURLFromPreferenceInMOC:CoreData.sharedInstance.mainMOC relativePath:path];
    [self performAuthenticatedRequestWithURL:url method:@"PUT" jsonBody:nil completion:^(NSData *data, NSInteger statusCode, NSError *error) {
        completion(error ?: ((statusCode >= 200 && statusCode < 300) ? nil : [self errorForStatus:statusCode fallbackDomain:@"LocationAPISyncService"]));
    }];
}

- (void)bulkMarkNotificationsUnread:(NSArray<NSNumber *> *)notificationIds completion:(void (^)(NSError * _Nullable))completion {
    NSURL *url = [WebAppURLResolver notificationsAPIURLFromPreferenceInMOC:CoreData.sharedInstance.mainMOC relativePath:@"/api/notifications/bulk-unread"];
    NSDictionary *body = @{@"notificationIds": notificationIds ?: @[]};
    [self performAuthenticatedRequestWithURL:url method:@"PUT" jsonBody:body completion:^(NSData *data, NSInteger statusCode, NSError *error) {
        completion(error ?: ((statusCode >= 200 && statusCode < 300) ? nil : [self errorForStatus:statusCode fallbackDomain:@"LocationAPISyncService"]));
    }];
}

- (void)deleteNotification:(NSInteger)notificationId completion:(void (^)(NSError * _Nullable))completion {
    NSString *path = [NSString stringWithFormat:@"/api/notifications/%ld", (long)notificationId];
    NSURL *url = [WebAppURLResolver notificationsAPIURLFromPreferenceInMOC:CoreData.sharedInstance.mainMOC relativePath:path];
    [self performAuthenticatedRequestWithURL:url method:@"DELETE" jsonBody:nil completion:^(NSData *data, NSInteger statusCode, NSError *error) {
        completion(error ?: ((statusCode >= 200 && statusCode < 300) ? nil : [self errorForStatus:statusCode fallbackDomain:@"LocationAPISyncService"]));
    }];
}

- (void)bulkDeleteNotifications:(NSArray<NSNumber *> *)notificationIds completion:(void (^)(NSError * _Nullable))completion {
    NSURL *url = [WebAppURLResolver notificationsAPIURLFromPreferenceInMOC:CoreData.sharedInstance.mainMOC relativePath:@"/api/notifications/bulk"];
    NSDictionary *body = @{@"notificationIds": notificationIds ?: @[]};
    [self performAuthenticatedRequestWithURL:url method:@"DELETE" jsonBody:body completion:^(NSData *data, NSInteger statusCode, NSError *error) {
        completion(error ?: ((statusCode >= 200 && statusCode < 300) ? nil : [self errorForStatus:statusCode fallbackDomain:@"LocationAPISyncService"]));
    }];
}

- (void)provisionRemoteDeviceConfigurationIfNeededWithCompletion:(void (^)(BOOL applied, NSError * _Nullable error))completion {
    if (!completion) {
        return;
    }
    if (self.provisionInFlight) {
        DDLogVerbose(@"[ProvisionAPI] provision skipped (already in flight)");
        completion(NO, [NSError errorWithDomain:kOTProvisionAPIDomain
                                            code:kOTProvisionAPICodeBusy
                                        userInfo:@{NSLocalizedDescriptionKey: @"Provision request already in progress"}]);
        return;
    }
    NSManagedObjectContext *moc = CoreData.sharedInstance.mainMOC;
    if (![Settings appEmbeddedWebShouldRequestProvisioningInMOC:moc]) {
        DDLogVerbose(@"[ProvisionAPI] provision skipped (app does not need provisioning)");
        completion(NO, nil);
        return;
    }
    NSURL *provisionURL = [WebAppURLResolver configProvisionAPIRequestURLFromPreferenceInMOC:moc];
    NSURL *optionsURL = [WebAppURLResolver configProvisionOptionsAPIRequestURLFromPreferenceInMOC:moc];
    if (!provisionURL) {
        DDLogWarn(@"[ProvisionAPI] provision skipped (no web app origin / provision URL)");
        completion(NO, nil);
        return;
    }

    self.provisionInFlight = YES;
    __weak typeof(self) wself = self;
    [self obtainAccessTokenForLocationAPIWithCompletion:^(NSString * _Nullable accessToken) {
        __strong typeof(wself) sself = wself;
        if (!sself) {
            completion(NO, [NSError errorWithDomain:kOTProvisionAPIDomain code:0 userInfo:nil]);
            return;
        }
        if (!accessToken.length) {
            DDLogWarn(@"[ProvisionAPI] no access token — cannot POST provision");
            sself.provisionInFlight = NO;
            completion(NO, [NSError errorWithDomain:kOTProvisionAPIDomain
                                                code:401
                                            userInfo:@{NSLocalizedDescriptionKey: @"No access token"}]);
            return;
        }

        if (!optionsURL) {
            DDLogWarn(@"[ProvisionAPI] options URL nil — legacy single-step provision");
            [sself OT_runLegacySingleStepProvisionWithURL:provisionURL moc:moc accessToken:accessToken completion:completion];
            return;
        }

        NSDictionary *optionsBody = @{ @"deviceName": OTProvisionSanitizedDeviceName() };
        [sself performAuthenticatedRequestWithURL:optionsURL
                                           method:@"POST"
                                         jsonBody:optionsBody
                                       completion:^(NSData *data, NSInteger status, NSError *error) {
            __strong typeof(wself) sself2 = wself;
            if (!sself2) {
                completion(NO, [NSError errorWithDomain:kOTProvisionAPIDomain code:0 userInfo:nil]);
                return;
            }
            if (error) {
                DDLogWarn(@"[ProvisionAPI] POST /options network error: %@", error.localizedDescription);
                sself2.provisionInFlight = NO;
                completion(NO, error);
                return;
            }
            DDLogInfo(@"[ProvisionAPI] POST %@ → HTTP %ld (%lu bytes)",
                      optionsURL.absoluteString, (long)status, (unsigned long)data.length);

            if (status == 404) {
                DDLogInfo(@"[ProvisionAPI] POST /api/config/provision/options → 404 — legacy single-step provision");
                [sself2 OT_runLegacySingleStepProvisionWithURL:provisionURL moc:moc accessToken:accessToken completion:completion];
                return;
            }
            if (status != 200) {
                sself2.provisionInFlight = NO;
                completion(NO, [sself2 errorForStatus:status fallbackDomain:kOTProvisionAPIDomain]);
                return;
            }

            NSError *parseErr = nil;
            id obj = data.length ? [NSJSONSerialization JSONObjectWithData:data options:0 error:&parseErr] : nil;
            if (parseErr || ![obj isKindOfClass:[NSDictionary class]]) {
                DDLogWarn(@"[ProvisionAPI] options 200 but JSON parse failed: %@", parseErr.localizedDescription);
                sself2.provisionInFlight = NO;
                completion(NO, parseErr ?: [NSError errorWithDomain:kOTProvisionAPIDomain
                                                               code:2
                                                           userInfo:@{NSLocalizedDescriptionKey: @"Invalid JSON"}]);
                return;
            }
            NSDictionary *optionsPayload = (NSDictionary *)obj;
            id rawExisting = optionsPayload[@"existingDevices"];
            NSArray *existing = [rawExisting isKindOfClass:[NSArray class]] ? rawExisting : nil;
            NSUInteger n = existing.count;
            if (n == 0) {
                DDLogInfo(@"[ProvisionAPI] guided provision: empty existingDevices — POST mode=new");
                [sself2 OT_runGuidedProvisionPOSTWithURL:provisionURL
                                                     moc:moc
                                             accessToken:accessToken
                                                    mode:@"new"
                                       trackedDeviceId:nil
                                              completion:completion];
                return;
            }

            static const NSUInteger kMaxProvisionDeviceChoices = 10;
            BOOL truncated = n > kMaxProvisionDeviceChoices;
            NSArray *slice = truncated ? [existing subarrayWithRange:NSMakeRange(0, kMaxProvisionDeviceChoices)] : existing;
            NSMutableArray<NSDictionary *> *typed = [NSMutableArray array];
            for (id item in slice) {
                if (![item isKindOfClass:[NSDictionary class]]) {
                    continue;
                }
                NSDictionary *d = (NSDictionary *)item;
                if (OTProvisionTrackedDeviceIdNumberFromJSON(d[@"trackedDeviceId"])) {
                    [typed addObject:d];
                }
            }
            if (typed.count == 0 && n > 0) {
                DDLogWarn(@"[ProvisionAPI] existingDevices had no valid trackedDeviceId — POST mode=new");
                [sself2 OT_runGuidedProvisionPOSTWithURL:provisionURL
                                                     moc:moc
                                             accessToken:accessToken
                                                    mode:@"new"
                                       trackedDeviceId:nil
                                              completion:completion];
                return;
            }
            NSDictionary *userDict = [optionsPayload[@"user"] isKindOfClass:[NSDictionary class]] ? optionsPayload[@"user"] : nil;

            dispatch_async(dispatch_get_main_queue(), ^{
                __strong typeof(wself) sself3 = wself;
                if (!sself3) {
                    completion(NO, [NSError errorWithDomain:kOTProvisionAPIDomain code:0 userInfo:nil]);
                    return;
                }
                [sself3 OT_presentProvisionDeviceChooserWithUser:userDict
                                               existingDevices:typed
                                                    totalCount:n
                                                     truncated:truncated
                                                  provisionURL:provisionURL
                                                           moc:moc
                                                   accessToken:accessToken
                                                    completion:completion];
            });
        }];
    }];
}

- (void)OT_applyProvisionConfigurationPayload:(NSDictionary *)payload
              allowLocalIdentityRepairIfInvalid:(BOOL)allowRepair
                                     completion:(void (^)(BOOL applied, NSError * _Nullable error))completion {
    NSAssert([NSThread isMainThread], @"OT_applyProvisionConfigurationPayload must run on main");
    OwnTracksAppDelegate *ad = (OwnTracksAppDelegate *)[UIApplication sharedApplication].delegate;
    if (![ad isKindOfClass:[OwnTracksAppDelegate class]]) {
        self.provisionInFlight = NO;
        completion(NO, [NSError errorWithDomain:kOTProvisionAPIDomain code:3 userInfo:nil]);
        return;
    }
    NSError *jsonLogErr = nil;
    NSData *prettyLog = [NSJSONSerialization dataWithJSONObject:payload
                                                         options:(NSJSONWritingPrettyPrinted | NSJSONWritingSortedKeys)
                                                           error:&jsonLogErr];
    if (prettyLog && !jsonLogErr) {
        NSString *jsonStr = [[NSString alloc] initWithData:prettyLog encoding:NSUTF8StringEncoding];
        DDLogInfo(@"[ProvisionAPI] server configuration (full JSON from POST /api/config/provision):\n%@", jsonStr);
    } else {
        DDLogWarn(@"[ProvisionAPI] server configuration could not be serialized for logging (%@); description: %@",
                  jsonLogErr.localizedDescription ?: @"unknown",
                  payload);
    }
    NSMutableDictionary *cfg = [NSMutableDictionary dictionaryWithDictionary:payload];
    [Settings applyCanonicalDeviceIdFromPubTopicTailIfDeviceIdSuspectToMutableConfiguration:cfg];
    NSError *validationError =
        [Settings validationErrorForRemoteProvisionConfiguration:cfg
                                                             inMOC:CoreData.sharedInstance.mainMOC];
    if (validationError && allowRepair) {
        [Settings applyLocalProvisionIdentityRepairToMutableConfiguration:cfg
                                                                     inMOC:CoreData.sharedInstance.mainMOC];
        validationError =
            [Settings validationErrorForRemoteProvisionConfiguration:cfg
                                                             inMOC:CoreData.sharedInstance.mainMOC];
    }
    if (validationError) {
        DDLogWarn(@"[ProvisionAPI] configuration rejected by client validation: %@",
                  validationError.localizedDescription);
        self.provisionInFlight = NO;
        completion(NO, validationError);
        return;
    }
    [ad terminateSession];
    [ad configFromDictionary:cfg];
    ad.configLoad = [NSDate date];
    [ad reconnect];
    self.provisionInFlight = NO;
    DDLogInfo(@"[ProvisionAPI] configuration applied from POST /api/config/provision");
    completion(YES, nil);
}

- (void)OT_postProvisionHTTPWithURL:(NSURL *)provisionURL
                             bodyData:(NSData *)bodyData
                          accessToken:(NSString *)token
                       allowRetry401:(BOOL)allowRetry401
        allowLocalIdentityRepairIfInvalid:(BOOL)allowRepair
                           completion:(void (^)(BOOL applied, NSError * _Nullable error))completion {
    __weak typeof(self) wself = self;
    __block void (^runPOST)(NSString *tok, BOOL allow401);
    runPOST = ^(NSString *tok, BOOL allow401) {
        __strong typeof(wself) sselfInner = wself;
        if (!sselfInner) {
            completion(NO, [NSError errorWithDomain:kOTProvisionAPIDomain code:0 userInfo:nil]);
            return;
        }
        NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:provisionURL];
        req.HTTPMethod = @"POST";
        req.timeoutInterval = 30.0;
        [req setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
        [req setValue:@"application/json" forHTTPHeaderField:@"Accept"];
        [req setValue:[NSString stringWithFormat:@"Bearer %@", tok] forHTTPHeaderField:@"Authorization"];
        req.HTTPBody = bodyData;

        [[LocationAPISyncURLSession() dataTaskWithRequest:req
                                        completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
            __strong typeof(wself) sself2 = wself;
            if (!sself2) {
                completion(NO, nil);
                return;
            }
            if (error) {
                DDLogWarn(@"[ProvisionAPI] POST network error: %@", error.localizedDescription);
                sself2.provisionInFlight = NO;
                completion(NO, error);
                return;
            }
            NSInteger status = [response isKindOfClass:[NSHTTPURLResponse class]] ? [(NSHTTPURLResponse *)response statusCode] : 0;
            DDLogInfo(@"[ProvisionAPI] POST %@ → HTTP %ld (%lu bytes)",
                      provisionURL.absoluteString, (long)status, (unsigned long)data.length);

            if (status == 401 && allow401) {
                sself2.cachedAccessToken = nil;
                sself2.cachedAccessTokenExpiry = 0;
                [sself2 obtainAccessTokenForLocationAPIWithCompletion:^(NSString * _Nullable newToken) {
                    __strong typeof(wself) sself3 = wself;
                    if (!sself3) {
                        completion(NO, nil);
                        return;
                    }
                    if (!newToken.length) {
                        DDLogWarn(@"[ProvisionAPI] 401 retry — could not refresh token");
                        sself3.provisionInFlight = NO;
                        completion(NO, [NSError errorWithDomain:kOTProvisionAPIDomain
                                                            code:401
                                                        userInfo:@{NSLocalizedDescriptionKey: @"Unauthorized"}]);
                        return;
                    }
                    runPOST(newToken, NO);
                }];
                return;
            }

            if (status == 200) {
                NSError *parseErr = nil;
                id obj = data.length ? [NSJSONSerialization JSONObjectWithData:data options:0 error:&parseErr] : nil;
                if (parseErr || ![obj isKindOfClass:[NSDictionary class]]) {
                    DDLogWarn(@"[ProvisionAPI] 200 but JSON parse failed: %@", parseErr.localizedDescription);
                    sself2.provisionInFlight = NO;
                    completion(NO, parseErr ?: [NSError errorWithDomain:kOTProvisionAPIDomain
                                                                   code:2
                                                               userInfo:@{NSLocalizedDescriptionKey: @"Invalid JSON"}]);
                    return;
                }
                NSDictionary *payload = (NSDictionary *)obj;
                dispatch_async(dispatch_get_main_queue(), ^{
                    __strong typeof(wself) sself4 = wself;
                    if (!sself4) {
                        completion(NO, nil);
                        return;
                    }
                    [sself4 OT_applyProvisionConfigurationPayload:payload
                              allowLocalIdentityRepairIfInvalid:allowRepair
                                                     completion:completion];
                });
                return;
            }

            NSString *serverMsg = nil;
            if (data.length) {
                id errObj = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
                if ([errObj isKindOfClass:[NSDictionary class]]) {
                    id em = errObj[@"error"];
                    if ([em isKindOfClass:[NSString class]]) {
                        serverMsg = (NSString *)em;
                    }
                }
            }
            if (!serverMsg.length) {
                serverMsg = [NSString stringWithFormat:@"HTTP %ld", (long)status];
            }
            NSError *apiErr = [NSError errorWithDomain:kOTProvisionAPIDomain
                                                  code:status
                                              userInfo:@{NSLocalizedDescriptionKey: serverMsg}];
            DDLogWarn(@"[ProvisionAPI] provision failed: %@", serverMsg);
            sself2.provisionInFlight = NO;
            completion(NO, apiErr);
        }] resume];
    };

    runPOST(token, allowRetry401);
}

- (void)OT_runLegacySingleStepProvisionWithURL:(NSURL *)provisionURL
                                           moc:(NSManagedObjectContext *)moc
                                   accessToken:(NSString *)token
                                    completion:(void (^)(BOOL applied, NSError * _Nullable error))completion {
    NSError *jsonErr = nil;
    NSDictionary *bodyDict = OTProvisionRequestBodyWithHints(moc);
    NSData *bodyData = [NSJSONSerialization dataWithJSONObject:bodyDict options:0 error:&jsonErr];
    if (!bodyData) {
        DDLogError(@"[ProvisionAPI] could not encode provision body: %@", jsonErr);
        self.provisionInFlight = NO;
        completion(NO, jsonErr);
        return;
    }
    [self OT_postProvisionHTTPWithURL:provisionURL
                             bodyData:bodyData
                          accessToken:token
                       allowRetry401:YES
        allowLocalIdentityRepairIfInvalid:YES
                           completion:completion];
}

- (void)OT_runGuidedProvisionPOSTWithURL:(NSURL *)provisionURL
                                     moc:(NSManagedObjectContext *)moc
                             accessToken:(NSString *)token
                                    mode:(NSString *)mode
                       trackedDeviceId:(NSNumber * _Nullable)trackedDeviceId
                              completion:(void (^)(BOOL applied, NSError * _Nullable error))completion {
    NSDictionary *hints = OTProvisionRequestBodyWithHints(moc);
    NSMutableDictionary *body = hints ? [hints mutableCopy] : [NSMutableDictionary dictionary];
    body[@"mode"] = mode;
    if (trackedDeviceId) {
        body[@"trackedDeviceId"] = trackedDeviceId;
    }
    NSError *jsonErr = nil;
    NSData *bodyData = [NSJSONSerialization dataWithJSONObject:body options:0 error:&jsonErr];
    if (!bodyData) {
        DDLogError(@"[ProvisionAPI] could not encode guided provision body: %@", jsonErr);
        self.provisionInFlight = NO;
        completion(NO, jsonErr);
        return;
    }
    DDLogInfo(@"[ProvisionAPI] guided POST mode=%@ trackedDeviceId=%@", mode, trackedDeviceId ?: @"(nil)");
    [self OT_postProvisionHTTPWithURL:provisionURL
                             bodyData:bodyData
                          accessToken:token
                       allowRetry401:YES
        allowLocalIdentityRepairIfInvalid:NO
                           completion:completion];
}

- (void)OT_presentProvisionDeviceChooserWithUser:(NSDictionary *)userDict
                                 existingDevices:(NSArray<NSDictionary *> *)devicesSlice
                                      totalCount:(NSUInteger)totalCount
                                       truncated:(BOOL)truncated
                                    provisionURL:(NSURL *)provisionURL
                                             moc:(NSManagedObjectContext *)moc
                                     accessToken:(NSString *)token
                                      completion:(void (^)(BOOL applied, NSError * _Nullable error))completion {
    NSAssert([NSThread isMainThread], @"OT_presentProvisionDeviceChooser must run on main");
    (void)totalCount;
    UIViewController *top = LocationAPISyncTopMostViewController();
    if (!top) {
        DDLogWarn(@"[ProvisionAPI] no presenter for device chooser — aborting guided provision");
        self.provisionInFlight = NO;
        completion(NO, [NSError errorWithDomain:kOTProvisionAPIDomain
                                            code:4
                                        userInfo:@{NSLocalizedDescriptionKey: @"No view controller to present device chooser"}]);
        return;
    }

    NSString *acct = nil;
    if ([userDict[@"displayName"] isKindOfClass:[NSString class]]) {
        acct = [(NSString *)userDict[@"displayName"] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    }
    NSString *accountHeaderPlain = nil;
    if (acct.length) {
        accountHeaderPlain = [NSString stringWithFormat:NSLocalizedString(@"ProvisionExistingDeviceAccountLine", @"Signed in as: {name}"), acct];
    }

    OTProvisionDevicePickerTVC *picker = [[OTProvisionDevicePickerTVC alloc] initWithStyle:UITableViewStyleInsetGrouped];
    picker.devices = devicesSlice;
    picker.accountHeaderPlain = accountHeaderPlain;
    picker.truncatedFooter = truncated;

    __weak typeof(self) wself = self;
    picker.onPickExisting = ^(NSNumber *trackedTid) {
        __strong typeof(wself) sself = wself;
        if (!sself) {
            completion(NO, nil);
            return;
        }
        [sself OT_runGuidedProvisionPOSTWithURL:provisionURL
                                          moc:moc
                                  accessToken:token
                                         mode:@"existing"
                            trackedDeviceId:trackedTid
                                   completion:completion];
    };
    picker.onPickNew = ^{
        __strong typeof(wself) sself = wself;
        if (!sself) {
            completion(NO, nil);
            return;
        }
        [sself OT_runGuidedProvisionPOSTWithURL:provisionURL
                                          moc:moc
                                  accessToken:token
                                         mode:@"new"
                            trackedDeviceId:nil
                                   completion:completion];
    };
    picker.onCancel = ^{
        __strong typeof(wself) sself = wself;
        if (!sself) {
            completion(NO, nil);
            return;
        }
        sself.provisionInFlight = NO;
        completion(NO, nil);
    };

    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:picker];
    if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad) {
        nav.modalPresentationStyle = UIModalPresentationFormSheet;
    }
    [top presentViewController:nav animated:YES completion:nil];
}

- (void)fetchDeviceImageAtPath:(NSString *)relativePath
                   accessToken:(NSString *)accessToken
                      forTopic:(NSString *)topic
                    originURL:(NSURL *)origin {
    if (!origin || relativePath.length == 0 || accessToken.length == 0) {
        return;
    }
    NSURLComponents *c = [NSURLComponents componentsWithURL:origin resolvingAgainstBaseURL:NO];
    c.path = relativePath;
    c.query = nil;
    NSURL *imageURL = c.URL;
    if (!imageURL) {
        return;
    }
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:imageURL];
    req.HTTPMethod = @"GET";
    req.timeoutInterval = 30.0;
    [req setValue:[NSString stringWithFormat:@"Bearer %@", accessToken] forHTTPHeaderField:@"Authorization"];

    __weak typeof(self) wself = self;
    [[LocationAPISyncURLSession() dataTaskWithRequest:req
                                    completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (error || !data.length) {
            DDLogVerbose(@"[LocationAPISyncService] Device image fetch failed for %@: %@", topic, error.localizedDescription);
            return;
        }
        NSInteger status = [response isKindOfClass:[NSHTTPURLResponse class]] ? [(NSHTTPURLResponse *)response statusCode] : 0;
        if (status != 200) {
            DDLogVerbose(@"[LocationAPISyncService] Device image fetch HTTP %ld for %@", (long)status, topic);
            return;
        }
        // Validate it is a recognizable image.
        if (![UIImage imageWithData:data]) {
            DDLogVerbose(@"[LocationAPISyncService] Device image data not a valid image for %@", topic);
            return;
        }
        __strong typeof(wself) sself = wself;
        if (!sself) {
            return;
        }
        NSManagedObjectContext *queuedMOC = CoreData.sharedInstance.queuedMOC;
        [queuedMOC performBlock:^{
            Friend *friend = [Friend friendWithTopic:topic inManagedObjectContext:queuedMOC];
            if (friend && friend.cardImage == nil) {
                friend.cardImage = data;
                [CoreData.sharedInstance sync:queuedMOC];
                DDLogInfo(@"[LocationAPISyncService] Stored device image for %@", topic);
            }
        }];
    }] resume];
}

- (void)obtainOAuthAccessTokenForAPICallsWithCompletion:(void (^)(NSString * _Nullable token))completion {
    [self obtainAccessTokenForLocationAPIWithCompletion:completion];
}

#pragma mark - Dashcam

static NSDictionary *OTDashcamSafeDict(id obj) {
    return [obj isKindOfClass:[NSDictionary class]] ? (NSDictionary *)obj : nil;
}

static NSString *OTDashcamSafeString(id obj) {
    return [obj isKindOfClass:[NSString class]] ? (NSString *)obj : nil;
}

static NSNumber *OTDashcamSafeNumber(id obj) {
    if ([obj isKindOfClass:[NSNumber class]]) {
        return (NSNumber *)obj;
    }
    if ([obj isKindOfClass:[NSString class]]) {
        NSString *s = (NSString *)obj;
        if (s.length == 0) {
            return nil;
        }
        return @(s.doubleValue);
    }
    return nil;
}

static OTWebDeviceItem *OTDeviceItemFromDictionary(NSDictionary *dict) {
    if (!OTDashcamSafeDict(dict)) {
        return nil;
    }
    OTWebDeviceItem *item = [[OTWebDeviceItem alloc] init];
    NSNumber *idNum = OTDashcamSafeNumber(dict[@"id"]);
    item.deviceId = idNum.integerValue;
    item.topicId = OTDashcamSafeString(dict[@"topicId"]);
    item.deviceName = OTDashcamSafeString(dict[@"deviceName"]);
    item.ownerName = OTDashcamSafeString(dict[@"ownerName"]);
    id sharedVal = dict[@"isShared"];
    if ([sharedVal isKindOfClass:[NSNumber class]]) {
        item.isShared = [(NSNumber *)sharedVal boolValue];
    }
    return item;
}

static OTDashcamClipCamera *OTDashcamClipCameraFromDictionary(NSDictionary *dict) {
    if (!OTDashcamSafeDict(dict)) {
        return nil;
    }
    NSString *camera = OTDashcamSafeString(dict[@"camera"]);
    if (camera.length == 0) {
        return nil;
    }
    OTDashcamClipCamera *out = [[OTDashcamClipCamera alloc] init];
    out.camera = camera;
    out.fileName = OTDashcamSafeString(dict[@"fileName"]);
    return out;
}

static NSDate * _Nullable OTDashcamDateFromISOString(id value) {
    if (![value isKindOfClass:[NSString class]]) {
        return nil;
    }
    NSString *s = (NSString *)value;
    if (s.length == 0) {
        return nil;
    }
    static NSISO8601DateFormatter *withFrac;
    static NSISO8601DateFormatter *plain;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        withFrac = [[NSISO8601DateFormatter alloc] init];
        withFrac.formatOptions = NSISO8601DateFormatWithInternetDateTime | NSISO8601DateFormatWithFractionalSeconds;
        plain = [[NSISO8601DateFormatter alloc] init];
        plain.formatOptions = NSISO8601DateFormatWithInternetDateTime;
    });
    NSDate *d = [withFrac dateFromString:s];
    if (!d) {
        d = [plain dateFromString:s];
    }
    return d;
}

static OTDashcamClipItem *OTDashcamClipItemFromDictionary(NSDictionary *dict,
                                                          NSInteger envelopeDeviceId,
                                                          NSString *envelopeUser,
                                                          NSString *envelopeDevice) {
    if (!OTDashcamSafeDict(dict)) {
        return nil;
    }
    NSString *clipId = OTDashcamSafeString(dict[@"clipId"]);
    if (clipId.length == 0) {
        return nil;
    }
    OTDashcamClipItem *item = [[OTDashcamClipItem alloc] init];
    item.clipId = clipId;
    NSNumber *clipDeviceIdNum = OTDashcamSafeNumber(dict[@"deviceId"]);
    if (clipDeviceIdNum) {
        item.deviceId = clipDeviceIdNum.integerValue;
    } else if (envelopeDeviceId > 0) {
        item.deviceId = envelopeDeviceId;
    }
    NSString *clipUser = OTDashcamSafeString(dict[@"user"]);
    item.owner = clipUser.length > 0 ? clipUser : envelopeUser;
    NSString *clipDeviceName = OTDashcamSafeString(dict[@"device"]);
    item.device = clipDeviceName.length > 0 ? clipDeviceName : envelopeDevice;
    item.eventFolderName = OTDashcamSafeString(dict[@"eventFolderName"]);
    NSNumber *ts = OTDashcamSafeNumber(dict[@"eventUnixTimestamp"]);
    item.eventUnixTimestamp = ts ? ts.doubleValue : 0.0;
    NSDate *iso = OTDashcamDateFromISOString(dict[@"eventTimestampIso"]);
    if (iso) {
        item.eventDate = iso;
        if (item.eventUnixTimestamp <= 0) {
            item.eventUnixTimestamp = [iso timeIntervalSince1970];
        }
    } else if (item.eventUnixTimestamp > 0) {
        item.eventDate = [NSDate dateWithTimeIntervalSince1970:item.eventUnixTimestamp];
    }
    item.latitude = OTDashcamSafeNumber(dict[@"latitude"]);
    item.longitude = OTDashcamSafeNumber(dict[@"longitude"]);
    item.street = OTDashcamSafeString(dict[@"street"]);
    item.city = OTDashcamSafeString(dict[@"city"]);
    item.reason = OTDashcamSafeString(dict[@"reason"]);
    item.warning = OTDashcamSafeString(dict[@"warning"]);
    id hasThumb = dict[@"hasThumb"];
    item.hasThumb = [hasThumb isKindOfClass:[NSNumber class]] ? [(NSNumber *)hasThumb boolValue] : NO;
    id usedFallback = dict[@"usedRouteStartFallback"];
    item.usedRouteStartFallback = [usedFallback isKindOfClass:[NSNumber class]] ? [(NSNumber *)usedFallback boolValue] : NO;
    id fromJson = dict[@"positionFromEventJson"];
    item.positionFromEventJson = [fromJson isKindOfClass:[NSNumber class]] ? [(NSNumber *)fromJson boolValue] : NO;
    NSMutableArray<OTDashcamClipCamera *> *cams = [NSMutableArray array];
    id camerasRaw = dict[@"cameras"];
    if ([camerasRaw isKindOfClass:[NSArray class]]) {
        for (id camDict in (NSArray *)camerasRaw) {
            OTDashcamClipCamera *c = OTDashcamClipCameraFromDictionary(camDict);
            if (c) {
                [cams addObject:c];
            }
        }
    }
    item.cameras = [cams copy];
    return item;
}

static NSArray<OTDashcamClipItem *> *OTDashcamClipsSortedByEventDesc(NSArray<OTDashcamClipItem *> *clips) {
    return [clips sortedArrayUsingComparator:^NSComparisonResult(OTDashcamClipItem *a, OTDashcamClipItem *b) {
        if (a.eventUnixTimestamp == b.eventUnixTimestamp) {
            return NSOrderedSame;
        }
        return a.eventUnixTimestamp > b.eventUnixTimestamp ? NSOrderedAscending : NSOrderedDescending;
    }];
}

- (void)fetchDashcamClipsFromUnix:(NSInteger)fromUnix
                           toUnix:(NSInteger)toUnix
                       completion:(void (^)(NSArray<OTDashcamClipItem *> * _Nullable, NSError * _Nullable))completion {
    NSManagedObjectContext *mainMOC = CoreData.sharedInstance.mainMOC;
    __block NSURL *url = nil;
    [mainMOC performBlockAndWait:^{
        url = [WebAppURLResolver dashcamClipsAPIRequestURLFromPreferenceInMOC:mainMOC
                                                                     fromUnix:fromUnix
                                                                       toUnix:toUnix];
    }];
    if (!url) {
        completion(nil, [NSError errorWithDomain:@"LocationAPISyncService"
                                            code:1
                                        userInfo:@{NSLocalizedDescriptionKey: @"No web app origin"}]);
        return;
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        self.dashcamClipsFetchInFlight = YES;
    });
    __weak typeof(self) wself = self;
    [self performAuthenticatedGET:url completion:^(NSData * _Nullable data, NSError * _Nullable error) {
        void (^finish)(NSArray<OTDashcamClipItem *> * _Nullable, NSError * _Nullable) = ^(NSArray<OTDashcamClipItem *> *clips, NSError *err) {
            dispatch_async(dispatch_get_main_queue(), ^{
                __strong typeof(wself) sself = wself;
                if (sself) {
                    sself.dashcamClipsFetchInFlight = NO;
                }
            });
            if (completion) {
                completion(clips, err);
            }
        };
        if (error) {
            finish(nil, error);
            return;
        }
        if (!data.length) {
            NSArray<OTDashcamClipItem *> *empty = @[];
            dispatch_async(dispatch_get_main_queue(), ^{
                __strong typeof(wself) sself = wself;
                if (sself) {
                    sself.lastDashcamClips = empty;
                    sself.lastDashcamFromUnix = fromUnix;
                    sself.lastDashcamToUnix = toUnix;
                }
            });
            finish(empty, nil);
            return;
        }
        NSError *jsonErr = nil;
        id obj = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonErr];
        if (jsonErr || ![obj isKindOfClass:[NSDictionary class]]) {
            DDLogWarn(@"[Dashcam] bulk clips parse error: %@", jsonErr.localizedDescription);
            finish(nil, jsonErr ?: [NSError errorWithDomain:@"LocationAPISyncService"
                                                       code:2
                                                   userInfo:@{NSLocalizedDescriptionKey: @"Bad clip payload"}]);
            return;
        }
        NSDictionary *root = (NSDictionary *)obj;
        id clipsRaw = root[@"clips"];
        if (![clipsRaw isKindOfClass:[NSArray class]]) {
            NSArray<OTDashcamClipItem *> *empty = @[];
            dispatch_async(dispatch_get_main_queue(), ^{
                __strong typeof(wself) sself = wself;
                if (sself) {
                    sself.lastDashcamClips = empty;
                    sself.lastDashcamFromUnix = fromUnix;
                    sself.lastDashcamToUnix = toUnix;
                }
            });
            finish(empty, nil);
            return;
        }
        NSMutableArray<OTDashcamClipItem *> *out = [NSMutableArray array];
        for (id entry in (NSArray *)clipsRaw) {
            OTDashcamClipItem *clip = OTDashcamClipItemFromDictionary(entry, 0, nil, nil);
            if (clip) {
                [out addObject:clip];
            }
        }
        NSArray<OTDashcamClipItem *> *sorted = OTDashcamClipsSortedByEventDesc([out copy]);
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(wself) sself = wself;
            if (sself) {
                sself.lastDashcamClips = sorted;
                sself.lastDashcamFromUnix = fromUnix;
                sself.lastDashcamToUnix = toUnix;
            }
        });
        finish(sorted, nil);
    }];
}

- (void)fetchUsersDevicesIncludeAllForAdmin:(BOOL)includeAllForAdmin
                                 completion:(void (^)(NSArray<OTWebDeviceItem *> * _Nullable, NSError * _Nullable))completion {
    NSManagedObjectContext *mainMOC = CoreData.sharedInstance.mainMOC;
    __block NSURL *url = nil;
    [mainMOC performBlockAndWait:^{
        url = [WebAppURLResolver usersDevicesAPIRequestURLFromPreferenceInMOC:mainMOC
                                                            includeAllForAdmin:includeAllForAdmin];
    }];
    if (!url) {
        completion(nil, [NSError errorWithDomain:@"LocationAPISyncService"
                                            code:1
                                        userInfo:@{NSLocalizedDescriptionKey: @"No web app origin"}]);
        return;
    }
    [self performAuthenticatedGET:url completion:^(NSData * _Nullable data, NSError * _Nullable error) {
        if (error) {
            completion(nil, error);
            return;
        }
        if (!data.length) {
            completion(@[], nil);
            return;
        }
        NSError *jsonErr = nil;
        id obj = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonErr];
        if (jsonErr || ![obj isKindOfClass:[NSArray class]]) {
            DDLogWarn(@"[Dashcam] users/devices parse error: %@", jsonErr.localizedDescription);
            completion(nil, jsonErr ?: [NSError errorWithDomain:@"LocationAPISyncService"
                                                            code:2
                                                        userInfo:@{NSLocalizedDescriptionKey: @"Bad devices payload"}]);
            return;
        }
        NSMutableArray<OTWebDeviceItem *> *out = [NSMutableArray array];
        for (id entry in (NSArray *)obj) {
            OTWebDeviceItem *item = OTDeviceItemFromDictionary(entry);
            if (item && item.deviceId > 0) {
                [out addObject:item];
            }
        }
        completion([out copy], nil);
    }];
}

- (void)fetchDashcamClipsForDeviceId:(NSInteger)deviceId
                            fromUnix:(NSInteger)fromUnix
                              toUnix:(NSInteger)toUnix
                          completion:(void (^)(NSArray<OTDashcamClipItem *> * _Nullable, NSError * _Nullable))completion {
    NSManagedObjectContext *mainMOC = CoreData.sharedInstance.mainMOC;
    __block NSURL *url = nil;
    [mainMOC performBlockAndWait:^{
        url = [WebAppURLResolver dashcamClipsAPIRequestURLFromPreferenceInMOC:mainMOC
                                                                      deviceId:deviceId
                                                                      fromUnix:fromUnix
                                                                        toUnix:toUnix];
    }];
    if (!url) {
        completion(nil, [NSError errorWithDomain:@"LocationAPISyncService"
                                            code:1
                                        userInfo:@{NSLocalizedDescriptionKey: @"No web app origin"}]);
        return;
    }
    [self performAuthenticatedGET:url completion:^(NSData * _Nullable data, NSError * _Nullable error) {
        if (error) {
            completion(nil, error);
            return;
        }
        if (!data.length) {
            completion(@[], nil);
            return;
        }
        NSError *jsonErr = nil;
        id obj = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonErr];
        if (jsonErr || ![obj isKindOfClass:[NSDictionary class]]) {
            completion(nil, jsonErr ?: [NSError errorWithDomain:@"LocationAPISyncService"
                                                            code:2
                                                        userInfo:@{NSLocalizedDescriptionKey: @"Bad clip payload"}]);
            return;
        }
        NSDictionary *envelope = (NSDictionary *)obj;
        NSNumber *envDeviceId = OTDashcamSafeNumber(envelope[@"deviceId"]);
        NSString *envUser = OTDashcamSafeString(envelope[@"user"]);
        NSString *envDevice = OTDashcamSafeString(envelope[@"device"]);
        id clipsRaw = envelope[@"clips"];
        if (![clipsRaw isKindOfClass:[NSArray class]]) {
            completion(@[], nil);
            return;
        }
        NSMutableArray<OTDashcamClipItem *> *out = [NSMutableArray array];
        for (id entry in (NSArray *)clipsRaw) {
            OTDashcamClipItem *clip = OTDashcamClipItemFromDictionary(entry,
                                                                       envDeviceId ? envDeviceId.integerValue : deviceId,
                                                                       envUser,
                                                                       envDevice);
            if (clip) {
                [out addObject:clip];
            }
        }
        completion([out copy], nil);
    }];
}

- (void)resolveDashcamMediaURLForClipId:(NSString *)clipId
                                 camera:(NSString *)camera
                                   kind:(NSString *)kind
                             completion:(void (^)(NSURL * _Nullable, NSError * _Nullable))completion {
    if (clipId.length == 0 || kind.length == 0) {
        completion(nil, [NSError errorWithDomain:@"LocationAPISyncService"
                                            code:1
                                        userInfo:@{NSLocalizedDescriptionKey: @"Missing clip id or kind"}]);
        return;
    }
    [self obtainAccessTokenForLocationAPIWithCompletion:^(NSString * _Nullable token) {
        if (token.length == 0) {
            completion(nil, [NSError errorWithDomain:@"LocationAPISyncService"
                                                code:401
                                            userInfo:@{NSLocalizedDescriptionKey: @"No access token"}]);
            return;
        }
        NSManagedObjectContext *mainMOC = CoreData.sharedInstance.mainMOC;
        __block NSURL *url = nil;
        [mainMOC performBlockAndWait:^{
            if ([kind isEqualToString:@"thumb"]) {
                url = [WebAppURLResolver dashcamThumbAPIURLFromPreferenceInMOC:mainMOC
                                                                         clipId:clipId
                                                                    accessToken:token];
            } else if ([kind isEqualToString:@"stream"]) {
                url = [WebAppURLResolver dashcamStreamAPIURLFromPreferenceInMOC:mainMOC
                                                                          clipId:clipId
                                                                          camera:camera
                                                                     accessToken:token];
            } else if ([kind isEqualToString:@"telemetry"]) {
                url = [WebAppURLResolver dashcamTelemetryAPIURLFromPreferenceInMOC:mainMOC
                                                                             clipId:clipId
                                                                             camera:camera
                                                                        accessToken:token];
            }
        }];
        if (!url) {
            completion(nil, [NSError errorWithDomain:@"LocationAPISyncService"
                                                code:2
                                            userInfo:@{NSLocalizedDescriptionKey: @"Could not build dashcam media URL"}]);
            return;
        }
        completion(url, nil);
    }];
}

- (void)registerApnsDeviceTokenHex:(NSString *)hexString sandbox:(BOOL)sandbox completion:(void (^)(NSError * _Nullable error))completion {
    if (hexString.length == 0) {
        completion([NSError errorWithDomain:@"LocationAPISyncService"
                                        code:1
                                    userInfo:@{ NSLocalizedDescriptionKey: @"Empty APNs device token" }]);
        return;
    }
    NSURL *url = [WebAppURLResolver apnsDeviceRegistrationAPIURLFromPreferenceInMOC:CoreData.sharedInstance.mainMOC];
    if (!url) {
        completion([NSError errorWithDomain:@"LocationAPISyncService"
                                        code:2
                                    userInfo:@{ NSLocalizedDescriptionKey: @"No web app origin for API registration" }]);
        return;
    }
    NSDictionary *body = @{
        @"deviceToken": hexString,
        @"sandbox": @(sandbox)
    };
    [self performAuthenticatedRequestWithURL:url
                                        method:@"POST"
                                      jsonBody:body
                                    completion:^(NSData *data, NSInteger statusCode, NSError *error) {
        if (error) {
            DDLogWarn(@"[APNsReg] POST failed %@", error.localizedDescription);
            completion(error);
            return;
        }
        if (statusCode >= 200 && statusCode < 300) {
            DDLogInfo(@"[APNsReg] registered OK (HTTP %ld)", (long)statusCode);
            completion(nil);
            return;
        }
        DDLogWarn(@"[APNsReg] HTTP %ld", (long)statusCode);
        completion([self errorForStatus:(NSInteger)statusCode fallbackDomain:@"LocationAPISyncService"]);
    }];
}

@end
