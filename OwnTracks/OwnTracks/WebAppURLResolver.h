//
//  WebAppURLResolver.h
//  OwnTracks
//
//  Resolves web app origin, Keychain base URL, and location API URL from webappurl_preference.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

NS_ASSUME_NONNULL_BEGIN

@interface WebAppURLResolver : NSObject

/// Raw user-configured URL (e.g. https://host/map), or nil if unset/invalid.
+ (nullable NSURL *)webAppUserURLFromPreferenceInMOC:(NSManagedObjectContext *)moc;

/// Scheme + host + port (no path). Used as API origin for /api/location.
+ (nullable NSURL *)webAppOriginURLFromPreferenceInMOC:(NSManagedObjectContext *)moc;

/// Normalized base URL with path; must match WebAppViewController / WebAppAuthHelper Keychain lookup.
+ (nullable NSURL *)webAppKeychainURLFromPreferenceInMOC:(NSManagedObjectContext *)moc;

/// All plausible Keychain base URLs to try (preference path, `/map`, and `/`). Tokens may be stored under any of these depending on Web App URL settings and login flow.
+ (NSArray<NSURL *> *)webAppKeychainURLCandidatesFromPreferenceInMOC:(NSManagedObjectContext *)moc;

/// Same candidate list as `webAppKeychainURLCandidatesFromPreferenceInMOC:` but derived from an explicit configured URL (e.g. captured before a settings reset).
+ (NSArray<NSURL *> *)webAppKeychainURLCandidatesForUserConfiguredURL:(NSURL *)userURL;

/// GET {origin}/api/location?showTeslaBeacons=false
+ (nullable NSURL *)locationAPIRequestURLFromPreferenceInMOC:(NSManagedObjectContext *)moc;

/// POST {origin}/api/config/provision (same origin as location API).
+ (nullable NSURL *)configProvisionAPIRequestURLFromPreferenceInMOC:(NSManagedObjectContext *)moc;

/// POST {origin}/api/config/provision/options (guided provision step 1).
+ (nullable NSURL *)configProvisionOptionsAPIRequestURLFromPreferenceInMOC:(NSManagedObjectContext *)moc;

/// GET {origin}/api/geolocationcache
+ (nullable NSURL *)geolocationCacheAPIRequestURLFromPreferenceInMOC:(NSManagedObjectContext *)moc;

/// {origin}{relativePath} for geolocation cache mutation endpoints.
+ (nullable NSURL *)geolocationCacheAPIURLFromPreferenceInMOC:(NSManagedObjectContext *)moc
                                                  relativePath:(NSString *)relativePath
                                                    queryItems:(nullable NSArray<NSURLQueryItem *> *)queryItems;

/// GET {origin}/api/notifications?skip=...&take=...&includeRead=...&type=...
+ (nullable NSURL *)notificationsAPIRequestURLFromPreferenceInMOC:(NSManagedObjectContext *)moc
                                                             skip:(NSInteger)skip
                                                             take:(NSInteger)take
                                                      includeRead:(BOOL)includeRead
                                                             type:(nullable NSString *)type;

/// GET {origin}/api/notifications/unread-count
+ (nullable NSURL *)notificationsUnreadCountAPIRequestURLFromPreferenceInMOC:(NSManagedObjectContext *)moc;

/// {origin}{relativePath} for notification mutation endpoints.
+ (nullable NSURL *)notificationsAPIURLFromPreferenceInMOC:(NSManagedObjectContext *)moc
                                               relativePath:(NSString *)relativePath;

/// Fully qualified LocationHub URL (`…/locationHub`, negotiate + WebSockets) including `access_token` for JwtBearer (see `OTInboxRealtimeHubPathComponent`).
+ (nullable NSURL *)signalRHubURLFromPreferenceInMOC:(NSManagedObjectContext *)moc accessToken:(NSString *)accessToken;

/// POST {origin}/api/push/devices/apns (OAuth Bearer); see OTInboxRealtimeContract.h.
+ (nullable NSURL *)apnsDeviceRegistrationAPIURLFromPreferenceInMOC:(NSManagedObjectContext *)moc;

/// GET {origin}/api/users/devices[?includeAllForAdmin=true]
+ (nullable NSURL *)usersDevicesAPIRequestURLFromPreferenceInMOC:(NSManagedObjectContext *)moc
                                              includeAllForAdmin:(BOOL)includeAllForAdmin;

/// GET {origin}/api/dashcam/clips?from=&to= (all accessible devices).
+ (nullable NSURL *)dashcamClipsAPIRequestURLFromPreferenceInMOC:(NSManagedObjectContext *)moc
                                                       fromUnix:(NSInteger)fromUnix
                                                         toUnix:(NSInteger)toUnix;

/// GET {origin}/api/dashcam/clips?deviceId=&from=&to= (single device; legacy).
+ (nullable NSURL *)dashcamClipsAPIRequestURLFromPreferenceInMOC:(NSManagedObjectContext *)moc
                                                        deviceId:(NSInteger)deviceId
                                                       fromUnix:(NSInteger)fromUnix
                                                         toUnix:(NSInteger)toUnix;

/// GET {origin}/api/dashcam/thumb/{clipId}[?access_token=...]
+ (nullable NSURL *)dashcamThumbAPIURLFromPreferenceInMOC:(NSManagedObjectContext *)moc
                                                   clipId:(NSString *)clipId
                                              accessToken:(nullable NSString *)accessToken;

/// GET {origin}/api/dashcam/stream/{clipId}/{camera}[?access_token=...]
+ (nullable NSURL *)dashcamStreamAPIURLFromPreferenceInMOC:(NSManagedObjectContext *)moc
                                                    clipId:(NSString *)clipId
                                                    camera:(NSString *)camera
                                               accessToken:(nullable NSString *)accessToken;

/// GET {origin}/api/dashcam/telemetry/{clipId}/{camera}[?access_token=...]
+ (nullable NSURL *)dashcamTelemetryAPIURLFromPreferenceInMOC:(NSManagedObjectContext *)moc
                                                       clipId:(NSString *)clipId
                                                       camera:(NSString *)camera
                                                  accessToken:(nullable NSString *)accessToken;

@end

NS_ASSUME_NONNULL_END
