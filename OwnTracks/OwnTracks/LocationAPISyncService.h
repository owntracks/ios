//
//  LocationAPISyncService.h
//  OwnTracks
//
//  Fetches GET {origin}/api/location with Web App OAuth and applies positions via OwnTracking (API-authoritative).
//

#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>

NS_ASSUME_NONNULL_BEGIN

/// Best-effort unix seconds from a Recorder `/api/location/history/.../route` point dictionary (shared with map + device metrics).
FOUNDATION_EXPORT NSTimeInterval OTRouteHistoryPointUnixTime(id _Nonnull pt);

/// Posted on the main queue after a new OAuth access token is obtained (PKCE exchange or silent refresh).
/// `LocationAPISyncService` observes this to run native `POST /api/config/provision` when needed, without the Web tab.
FOUNDATION_EXPORT NSNotificationName const OwnTracksOAuthAccessTokenBecameAvailableNotification;
FOUNDATION_EXPORT NSString * const OTLocationDeleteErrorCodeKey;
FOUNDATION_EXPORT NSString * const OTLocationDeleteErrorReferenceCountKey;
FOUNDATION_EXPORT NSString * const OTLocationDeleteErrorMessageKey;

/// Posted on the main queue when `GET /api/geolocationcache` succeeds and the in-memory cache is updated.
FOUNDATION_EXPORT NSNotificationName const OwnTracksGeolocationCacheDidUpdateNotification;

/// Posted on the main queue after `GET /api/authorization/user` payload is applied (or cleared on logout).
FOUNDATION_EXPORT NSNotificationName _Nonnull const OwnTracksCurrentUserProfileDidUpdateNotification;

/// Posted on the main queue when the MQTT friend-topic allowlist from `GET /api/location` changes or is cleared (OAuth invalidation).
FOUNDATION_EXPORT NSNotificationName _Nonnull const OwnTracksLocationMQTTAllowlistDidUpdateNotification;

@interface OTWebLocationItem : NSObject
@property (nonatomic) NSInteger locationId;
@property (nonatomic) double latitude;
@property (nonatomic) double longitude;
@property (nonatomic, copy) NSString *displayName;
@property (nonatomic, copy, nullable) NSString *originalDisplayName;
@property (nonatomic, copy, nullable) NSString *mapsUrl;
@property (nonatomic, strong) NSDate *createdAt;
@property (nonatomic, strong) NSDate *lastAccessed;
@property (nonatomic, copy, nullable) NSString *sourceType;
@property (nonatomic, strong, nullable) NSNumber *radius;
@property (nonatomic, copy, nullable) NSString *sourceDeviceName;
@end

@interface OTWebNotificationItem : NSObject
@property (nonatomic) NSInteger notificationIdValue;
@property (nonatomic) NSInteger userId;
@property (nonatomic, copy) NSString *type;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *summary;
@property (nonatomic, copy, nullable) NSString *dataString;
@property (nonatomic, strong, nullable) NSDictionary *dataDictionary;
@property (nonatomic, copy) NSString *notificationId;
@property (nonatomic) BOOL isRead;
@property (nonatomic, strong) NSDate *createdAt;
@property (nonatomic, strong, nullable) NSDate *readAt;
@end

@interface OTWebNotificationsPage : NSObject
@property (nonatomic, strong) NSArray<OTWebNotificationItem *> *notifications;
@property (nonatomic) NSInteger totalCount;
@property (nonatomic) NSInteger skip;
@property (nonatomic) NSInteger take;
@end

/// One device returned by `GET /api/users/devices`, or derived from dashcam clip payloads for filter chips.
@interface OTWebDeviceItem : NSObject
@property (nonatomic) NSInteger deviceId;
@property (nonatomic, copy, nullable) NSString *topicId;
@property (nonatomic, copy, nullable) NSString *deviceName;
@property (nonatomic, copy, nullable) NSString *ownerName;
@property (nonatomic) BOOL isShared;
@end

/// One camera entry inside an `OTDashcamClipItem`.
@interface OTDashcamClipCamera : NSObject
@property (nonatomic, copy) NSString *camera;
@property (nonatomic, copy, nullable) NSString *fileName;
@end

/// A single dashcam clip from `GET /api/dashcam/clips`. Includes `deviceId`, `owner` (`user`), and `device` on each clip.
@interface OTDashcamClipItem : NSObject
@property (nonatomic) NSInteger deviceId;
@property (nonatomic, copy, nullable) NSString *owner;
@property (nonatomic, copy, nullable) NSString *device;
@property (nonatomic, copy) NSString *clipId;
@property (nonatomic, copy, nullable) NSString *eventFolderName;
@property (nonatomic) NSTimeInterval eventUnixTimestamp;
@property (nonatomic, strong, nullable) NSDate *eventDate;
@property (nonatomic, strong, nullable) NSNumber *latitude;
@property (nonatomic, strong, nullable) NSNumber *longitude;
@property (nonatomic, copy, nullable) NSString *street;
@property (nonatomic, copy, nullable) NSString *city;
@property (nonatomic, copy, nullable) NSString *reason;
@property (nonatomic) BOOL hasThumb;
@property (nonatomic) BOOL usedRouteStartFallback;
@property (nonatomic) BOOL positionFromEventJson;
@property (nonatomic, copy, nullable) NSString *warning;
@property (nonatomic, strong) NSArray<OTDashcamClipCamera *> *cameras;
@end

@interface LocationAPISyncService : NSObject

+ (instancetype)sharedInstance;

/// Registers for foreground/background notifications. Safe to call once from application:didFinishLaunchingWithOptions:.
- (void)start;

/// YES when a web-app origin + Keychain URL candidates exist and `GET /api/location` URL resolves (same gate as `fetchAndApply`).
- (BOOL)isLocationMQTTAllowlistFeatureAvailableForMOC:(NSManagedObjectContext *)moc;

/// YES after a successful `GET /api/location` apply (even if the allowlist is empty). Cleared on `invalidateOAuthCredentialCache`.
- (BOOL)mqttFriendAllowlistHasLoadedFromLocationAPI;

/// Friend device MQTT prefixes from the last successful location API apply (e.g. `owntracks/user/device`). Excludes own device.
- (NSArray<NSString *> *)mqttAllowedFriendDeviceTopicPrefixes;

/// Own-device + per-friend `topic`, `topic/event`, `topic/info` filters for MQTT subscribe when allowlist mode is active. Uses comma-free array assembly so topics may contain spaces.
- (NSArray<NSString *> *)mqttSubscriptionFiltersForAllowlistConnectWithMOC:(NSManagedObjectContext *)moc;

/// Own device only: `base`, `base/event`, `base/info`, `base/cmd` — used before the allowlist has loaded when allowlist feature is enabled.
- (NSArray<NSString *> *)mqttSubscriptionFiltersOwnDeviceOnlyForMOC:(NSManagedObjectContext *)moc;

/// When the location allowlist feature is enabled: own device always allowed; other devices only if the allowlist has loaded and contains `deviceTopicPrefix`. When the feature is disabled (MQTT-only), non-own devices are allowed (legacy).
- (BOOL)friendMqttDeviceTopicPrefixAllowed:(NSString *)deviceTopicPrefix managedObjectContext:(NSManagedObjectContext *)moc;

/// Triggers GET /api/location when not already in flight and the last successful fetch is older than a short debounce (e.g. Friends tab pull-to-refresh on appear).
- (void)requestLocationRefreshIfAppropriate;

/// Makes an authenticated GET to `url`, obtaining and refreshing the OAuth token as needed.
/// Completion is called on an arbitrary background thread with the raw response data or an error.
- (void)performAuthenticatedGET:(NSURL *)url
                     completion:(void (^)(NSData * _Nullable data, NSError * _Nullable error))completion;

/// GET /api/geolocationcache
- (void)fetchGeolocationCacheWithCompletion:(void (^)(NSArray<OTWebLocationItem *> * _Nullable locations,
                                                      NSError * _Nullable error))completion;

/// Debounced prefetch of geolocation cache (Friends tab, foreground). Safe to call often.
- (void)requestGeolocationCachePrefetchIfAppropriate;

/// Best eligible cached location whose circle contains `coordinate` (excludes `Destination` and `+follow` names). Main-thread use recommended.
- (nullable OTWebLocationItem *)geolocationItemContainingCoordinate:(CLLocationCoordinate2D)coordinate;

/// DELETE /api/geolocationcache/{id}[?replacementZoneId=...]
- (void)deleteGeolocationCacheLocationId:(NSInteger)locationId
                       replacementZoneId:(nullable NSNumber *)replacementZoneId
                              completion:(void (^)(NSInteger updatedReferences,
                                                   NSNumber * _Nullable echoedReplacementZoneId,
                                                   NSError * _Nullable error))completion;

/// GET /api/notifications with parity pagination and filters.
- (void)fetchNotificationsWithSkip:(NSInteger)skip
                              take:(NSInteger)take
                       includeRead:(BOOL)includeRead
                              type:(nullable NSString *)type
                        completion:(void (^)(OTWebNotificationsPage * _Nullable page,
                                             NSError * _Nullable error))completion;

/// GET /api/notifications/unread-count
- (void)fetchUnreadNotificationCountWithCompletion:(void (^)(NSInteger count,
                                                             NSError * _Nullable error))completion;

/// PUT /api/notifications/{id}/read
- (void)markNotificationRead:(NSInteger)notificationId completion:(void (^)(NSError * _Nullable error))completion;

/// PUT /api/notifications/read-all
- (void)markAllNotificationsReadWithCompletion:(void (^)(NSError * _Nullable error))completion;

/// PUT /api/notifications/bulk-read { notificationIds: [...] }
- (void)bulkMarkNotificationsRead:(NSArray<NSNumber *> *)notificationIds
                       completion:(void (^)(NSError * _Nullable error))completion;

/// PUT /api/notifications/{id}/unread
- (void)markNotificationUnread:(NSInteger)notificationId completion:(void (^)(NSError * _Nullable error))completion;

/// PUT /api/notifications/bulk-unread { notificationIds: [...] }
- (void)bulkMarkNotificationsUnread:(NSArray<NSNumber *> *)notificationIds
                         completion:(void (^)(NSError * _Nullable error))completion;

/// DELETE /api/notifications/{id}
- (void)deleteNotification:(NSInteger)notificationId completion:(void (^)(NSError * _Nullable error))completion;

/// DELETE /api/notifications/bulk { notificationIds: [...] }
- (void)bulkDeleteNotifications:(NSArray<NSNumber *> *)notificationIds
                     completion:(void (^)(NSError * _Nullable error))completion;

/// When the app still needs remote device configuration, runs guided native provision: POST `/api/config/provision/options`
/// (device name hint), then either POST `/api/config/provision` with `mode` + `trackedDeviceId` / `mode:new` after an optional
/// device chooser, or falls back to a legacy single POST without `mode` if `/options` returns 404. Applies the final JSON
/// (`_type: configuration`) on the main queue via `OwnTracksAppDelegate configFromDictionary:` after validation. Client-side
/// identity repair on failed validation applies only to the legacy path (no `mode` in request). See `OwnTracks/docs/PROVISION_API_CONTRACT.md`.
/// Completion is called on an arbitrary background thread: `applied` YES if configuration was applied.
- (void)provisionRemoteDeviceConfigurationIfNeededWithCompletion:(void (^)(BOOL applied, NSError * _Nullable error))completion;

/// Clears cached access token, discovery client id hint, and in-flight GET state after Keychain OAuth purge.
- (void)invalidateOAuthCredentialCache;

/// Applies JSON from `GET /api/authorization/user` (keys: \c isAdmin, \c canViewRouteHistory, \c homeZoneId, \c workZoneId). Main-thread only; posts \c OwnTracksCurrentUserProfileDidUpdateNotification.
- (void)updateFromAuthorizationUserAPIPayload:(NSDictionary *)json;

/// YES after a successful parse of `/api/authorization/user` this session (until \c invalidateOAuthCredentialCache).
- (BOOL)hasAuthorizationUserProfilePayload;

/// `isAdmin` from the last authorization user response (meaningful only if \c hasAuthorizationUserProfilePayload).
- (BOOL)currentUserIsAdminFromAuthorizationAPI;

/// Route history (Recorder REST window) allowed. If no profile loaded yet, returns YES (legacy). After profile load, uses \c canViewRouteHistory (defaults to YES if key absent).
- (BOOL)currentUserMayViewRouteHistory;

/// Home / work zone ids from the last authorization user response; nil if absent or null in JSON.
- (nullable NSNumber *)authorizationUserHomeZoneId;
- (nullable NSNumber *)authorizationUserWorkZoneId;

/// Sensitive device UI (e.g. MQTT topic): if \c hasAuthorizationUserProfilePayload, uses API \c isAdmin; else JWT \c claimsIndicateLocationAdmin:. \c OTForceLocationAdminForDeviceDetail forces YES.
- (BOOL)currentUserMayViewSensitiveLocationDeviceFields;

/// Discovery `client_id` from owntracks-app-auth this session, if already fetched; used when purging Keychain.
- (nullable NSString *)peekCachedDiscoveryOAuthClientId;

/// Same ordering as Keychain silent refresh: discovery id, settings id if different, then `NSNull` for nil-client lookup.
+ (NSArray *)orderedKeychainClientIdChainDiscovery:(nullable NSString *)discoveryClientId settings:(nullable NSString *)clientPref;

/// Same silent refresh pipeline as authenticated REST APIs (Bearer token resolution).
- (void)obtainOAuthAccessTokenForAPICallsWithCompletion:(void (^)(NSString * _Nullable token))completion;

/// GET `/api/location/history/{routeUser}/{routeDevice}/route?start=&end=` (Recorder). Parses `points` array; completion is always on the **main** queue. Results are cached in-memory briefly.
- (void)fetchRouteHistoryPointsForRouteUser:(NSString *)routeUser
                              routeDevice:(NSString *)routeDevice
                               startUnix:(NSInteger)startUnix
                                 endUnix:(NSInteger)endUnix
                    managedObjectContext:(NSManagedObjectContext *)moc
                              completion:(void (^)(NSArray<NSDictionary *> * _Nullable points,
                                                   NSError * _Nullable error))completion
    NS_SWIFT_NAME(fetchRouteHistoryPoints(forRouteUser:routeDevice:startUnix:endUnix:managedObjectContext:completion:));

/// Registers or updates this device token for inbox push notifications (POST `/api/push/devices/apns`).
- (void)registerApnsDeviceTokenHex:(NSString *)hexString
                           sandbox:(BOOL)sandbox
                        completion:(void (^)(NSError * _Nullable error))completion;

/// GET `/api/users/devices?includeAllForAdmin=true` — admin-only device inventory.
- (void)fetchUsersDevicesIncludeAllForAdmin:(BOOL)includeAllForAdmin
                                 completion:(void (^)(NSArray<OTWebDeviceItem *> * _Nullable devices,
                                                      NSError * _Nullable error))completion;

/// GET `/api/dashcam/clips?from=&to=` for all accessible devices. Each clip includes `deviceId`, `user`, and `device`. Results are cached in-memory by window; completion is on an arbitrary background thread.
- (void)fetchDashcamClipsFromUnix:(NSInteger)fromUnix
                           toUnix:(NSInteger)toUnix
                       completion:(void (^)(NSArray<OTDashcamClipItem *> * _Nullable clips,
                                            NSError * _Nullable error))completion;

/// GET `/api/dashcam/clips?deviceId=&from=&to=` for one device (legacy envelope). Completion is on an arbitrary background thread.
- (void)fetchDashcamClipsForDeviceId:(NSInteger)deviceId
                            fromUnix:(NSInteger)fromUnix
                              toUnix:(NSInteger)toUnix
                          completion:(void (^)(NSArray<OTDashcamClipItem *> * _Nullable clips,
                                               NSError * _Nullable error))completion;

/// Resolves a full dashcam media URL (thumb/stream/telemetry) that embeds the current OAuth access token as `?access_token=...`. AVPlayer cannot reliably set Authorization headers on range requests, so this is the preferred form for media playback.
- (void)resolveDashcamMediaURLForClipId:(NSString *)clipId
                                 camera:(nullable NSString *)camera
                                   kind:(NSString *)kind
                             completion:(void (^)(NSURL * _Nullable url,
                                                  NSError * _Nullable error))completion;

@end

NS_ASSUME_NONNULL_END
