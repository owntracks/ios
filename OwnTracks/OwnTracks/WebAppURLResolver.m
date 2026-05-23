//
//  WebAppURLResolver.m
//  OwnTracks
//

#import "WebAppURLResolver.h"
#import "OTInboxRealtimeContract.h"
#import "Settings.h"

@implementation WebAppURLResolver

+ (nullable NSURL *)webAppUserURLFromPreferenceInMOC:(NSManagedObjectContext *)moc {
    NSString *urlString = [Settings stringForKey:@"webappurl_preference" inMOC:moc];
    if (urlString.length == 0) {
        return nil;
    }
    return [NSURL URLWithString:urlString];
}

+ (nullable NSURL *)webAppOriginURLFromPreferenceInMOC:(NSManagedObjectContext *)moc {
    NSURL *url = [self webAppUserURLFromPreferenceInMOC:moc];
    if (!url) {
        return nil;
    }
    NSURLComponents *c = [NSURLComponents new];
    c.scheme = url.scheme;
    c.host = url.host;
    c.port = url.port;
    return c.URL;
}

+ (nullable NSURL *)webAppKeychainURLFromPreferenceInMOC:(NSManagedObjectContext *)moc {
    NSURL *url = [self webAppUserURLFromPreferenceInMOC:moc];
    if (!url) {
        return nil;
    }
    NSURLComponents *base = [NSURLComponents componentsWithURL:url resolvingAgainstBaseURL:NO];
    base.query = nil;
    base.fragment = nil;
    NSString *path = (base.path.length > 0 && ![base.path isEqualToString:@"/"]) ? base.path : @"";
    if (path.length > 0 && [path hasSuffix:@"/"]) {
        path = [path substringToIndex:path.length - 1];
    }
    base.path = path.length > 0 ? path : @"/";
    return base.URL ?: [self webAppOriginURLFromPreferenceInMOC:moc];
}

+ (nullable NSURL *)webAppKeychainBaseURLFromUserURL:(NSURL *)url {
    if (!url) {
        return nil;
    }
    NSURLComponents *base = [NSURLComponents componentsWithURL:url resolvingAgainstBaseURL:NO];
    base.query = nil;
    base.fragment = nil;
    NSString *path = (base.path.length > 0 && ![base.path isEqualToString:@"/"]) ? base.path : @"";
    if (path.length > 0 && [path hasSuffix:@"/"]) {
        path = [path substringToIndex:path.length - 1];
    }
    base.path = path.length > 0 ? path : @"/";
    return base.URL;
}

+ (NSArray<NSURL *> *)webAppKeychainURLCandidatesForUserConfiguredURL:(NSURL *)userURL {
    NSMutableOrderedSet<NSString *> *seen = [NSMutableOrderedSet orderedSet];
    NSMutableArray<NSURL *> *out = [NSMutableArray array];
    void (^add)(NSURL *) = ^(NSURL *u) {
        if (!u) {
            return;
        }
        NSString *s = u.absoluteString;
        if ([seen containsObject:s]) {
            return;
        }
        [seen addObject:s];
        [out addObject:u];
    };

    add([self webAppKeychainBaseURLFromUserURL:userURL]);

    NSURLComponents *originC = [NSURLComponents new];
    originC.scheme = userURL.scheme;
    originC.host = userURL.host;
    originC.port = userURL.port;
    NSURL *origin = originC.URL;
    if (!origin) {
        return out;
    }

    NSURLComponents *map = [NSURLComponents new];
    map.scheme = origin.scheme;
    map.host = origin.host;
    map.port = origin.port;
    map.path = @"/map";
    add(map.URL);

    NSURLComponents *root = [NSURLComponents new];
    root.scheme = origin.scheme;
    root.host = origin.host;
    root.port = origin.port;
    root.path = @"/";
    add(root.URL);

    return out;
}

+ (NSArray<NSURL *> *)webAppKeychainURLCandidatesFromPreferenceInMOC:(NSManagedObjectContext *)moc {
    NSURL *user = [self webAppUserURLFromPreferenceInMOC:moc];
    if (!user) {
        return @[];
    }
    return [self webAppKeychainURLCandidatesForUserConfiguredURL:user];
}

+ (nullable NSURL *)locationAPIRequestURLFromPreferenceInMOC:(NSManagedObjectContext *)moc {
    NSURL *origin = [self webAppOriginURLFromPreferenceInMOC:moc];
    if (!origin) {
        return nil;
    }
    NSURLComponents *c = [NSURLComponents componentsWithURL:origin resolvingAgainstBaseURL:NO];
    c.path = @"/api/location";
    c.queryItems = @[ [NSURLQueryItem queryItemWithName:@"showTeslaBeacons" value:@"false"] ];
    return c.URL;
}

+ (nullable NSURL *)configProvisionAPIRequestURLFromPreferenceInMOC:(NSManagedObjectContext *)moc {
    NSURL *origin = [self webAppOriginURLFromPreferenceInMOC:moc];
    if (!origin) {
        return nil;
    }
    NSURLComponents *c = [NSURLComponents componentsWithURL:origin resolvingAgainstBaseURL:NO];
    c.path = @"/api/config/provision";
    c.query = nil;
    c.fragment = nil;
    return c.URL;
}

+ (nullable NSURL *)configProvisionOptionsAPIRequestURLFromPreferenceInMOC:(NSManagedObjectContext *)moc {
    NSURL *origin = [self webAppOriginURLFromPreferenceInMOC:moc];
    if (!origin) {
        return nil;
    }
    NSURLComponents *c = [NSURLComponents componentsWithURL:origin resolvingAgainstBaseURL:NO];
    c.path = @"/api/config/provision/options";
    c.query = nil;
    c.fragment = nil;
    return c.URL;
}

+ (nullable NSURL *)geolocationCacheAPIRequestURLFromPreferenceInMOC:(NSManagedObjectContext *)moc {
    NSURL *origin = [self webAppOriginURLFromPreferenceInMOC:moc];
    if (!origin) {
        return nil;
    }
    NSURLComponents *c = [NSURLComponents componentsWithURL:origin resolvingAgainstBaseURL:NO];
    c.path = @"/api/geolocationcache";
    c.query = nil;
    c.fragment = nil;
    return c.URL;
}

+ (nullable NSURL *)geolocationCacheAPIURLFromPreferenceInMOC:(NSManagedObjectContext *)moc
                                                  relativePath:(NSString *)relativePath
                                                    queryItems:(NSArray<NSURLQueryItem *> *)queryItems {
    NSURL *origin = [self webAppOriginURLFromPreferenceInMOC:moc];
    if (!origin || relativePath.length == 0) {
        return nil;
    }
    NSURLComponents *c = [NSURLComponents componentsWithURL:origin resolvingAgainstBaseURL:NO];
    c.path = relativePath;
    c.queryItems = queryItems;
    c.fragment = nil;
    return c.URL;
}

+ (nullable NSURL *)notificationsAPIRequestURLFromPreferenceInMOC:(NSManagedObjectContext *)moc
                                                             skip:(NSInteger)skip
                                                             take:(NSInteger)take
                                                      includeRead:(BOOL)includeRead
                                                             type:(nullable NSString *)type {
    NSURL *origin = [self webAppOriginURLFromPreferenceInMOC:moc];
    if (!origin) {
        return nil;
    }
    NSURLComponents *c = [NSURLComponents componentsWithURL:origin resolvingAgainstBaseURL:NO];
    c.path = @"/api/notifications";
    NSMutableArray<NSURLQueryItem *> *items = [NSMutableArray arrayWithArray:@[
        [NSURLQueryItem queryItemWithName:@"skip" value:[NSString stringWithFormat:@"%ld", (long)MAX(skip, 0)]],
        [NSURLQueryItem queryItemWithName:@"take" value:[NSString stringWithFormat:@"%ld", (long)MAX(take, 1)]],
        [NSURLQueryItem queryItemWithName:@"includeRead" value:includeRead ? @"true" : @"false"]
    ]];
    if (type.length > 0) {
        [items addObject:[NSURLQueryItem queryItemWithName:@"type" value:type]];
    }
    c.queryItems = items;
    return c.URL;
}

+ (nullable NSURL *)notificationsUnreadCountAPIRequestURLFromPreferenceInMOC:(NSManagedObjectContext *)moc {
    NSURL *origin = [self webAppOriginURLFromPreferenceInMOC:moc];
    if (!origin) {
        return nil;
    }
    NSURLComponents *c = [NSURLComponents componentsWithURL:origin resolvingAgainstBaseURL:NO];
    c.path = @"/api/notifications/unread-count";
    c.query = nil;
    c.fragment = nil;
    return c.URL;
}

+ (nullable NSURL *)notificationsAPIURLFromPreferenceInMOC:(NSManagedObjectContext *)moc
                                               relativePath:(NSString *)relativePath {
    NSURL *origin = [self webAppOriginURLFromPreferenceInMOC:moc];
    if (!origin || relativePath.length == 0) {
        return nil;
    }
    NSURLComponents *c = [NSURLComponents componentsWithURL:origin resolvingAgainstBaseURL:NO];
    c.path = relativePath;
    c.query = nil;
    c.fragment = nil;
    return c.URL;
}

+ (nullable NSURL *)signalRHubURLFromPreferenceInMOC:(NSManagedObjectContext *)moc accessToken:(NSString *)accessToken {
    NSURL *origin = [self webAppOriginURLFromPreferenceInMOC:moc];
    if (!origin || accessToken.length == 0) {
        return nil;
    }
    NSURLComponents *c = [NSURLComponents componentsWithURL:origin resolvingAgainstBaseURL:NO];
    if (OTInboxRealtimeHubPathComponent.length == 0) {
        return nil;
    }
    c.path = OTInboxRealtimeHubPathComponent;
    c.percentEncodedFragment = nil;
    c.percentEncodedQuery = nil;
    c.queryItems = @[ [NSURLQueryItem queryItemWithName:OTRealtimeSignalRAccessTokenQueryName value:accessToken] ];
    return c.URL;
}

+ (nullable NSURL *)apnsDeviceRegistrationAPIURLFromPreferenceInMOC:(NSManagedObjectContext *)moc {
    NSURL *origin = [self webAppOriginURLFromPreferenceInMOC:moc];
    if (!origin || OTInboxAPNsRegisterAPIPath.length == 0) {
        return nil;
    }
    NSURLComponents *c = [NSURLComponents componentsWithURL:origin resolvingAgainstBaseURL:NO];
    c.path = OTInboxAPNsRegisterAPIPath;
    c.query = nil;
    c.fragment = nil;
    return c.URL;
}

+ (nullable NSURL *)usersDevicesAPIRequestURLFromPreferenceInMOC:(NSManagedObjectContext *)moc
                                              includeAllForAdmin:(BOOL)includeAllForAdmin {
    NSURL *origin = [self webAppOriginURLFromPreferenceInMOC:moc];
    if (!origin) {
        return nil;
    }
    NSURLComponents *c = [NSURLComponents componentsWithURL:origin resolvingAgainstBaseURL:NO];
    c.path = @"/api/users/devices";
    if (includeAllForAdmin) {
        c.queryItems = @[ [NSURLQueryItem queryItemWithName:@"includeAllForAdmin" value:@"true"] ];
    }
    c.fragment = nil;
    return c.URL;
}

+ (nullable NSURL *)dashcamClipsAPIRequestURLFromPreferenceInMOC:(NSManagedObjectContext *)moc
                                                       fromUnix:(NSInteger)fromUnix
                                                         toUnix:(NSInteger)toUnix {
    NSURL *origin = [self webAppOriginURLFromPreferenceInMOC:moc];
    if (!origin) {
        return nil;
    }
    NSURLComponents *c = [NSURLComponents componentsWithURL:origin resolvingAgainstBaseURL:NO];
    c.path = @"/api/dashcam/clips";
    c.queryItems = @[
        [NSURLQueryItem queryItemWithName:@"from" value:[NSString stringWithFormat:@"%ld", (long)fromUnix]],
        [NSURLQueryItem queryItemWithName:@"to" value:[NSString stringWithFormat:@"%ld", (long)toUnix]],
    ];
    c.fragment = nil;
    return c.URL;
}

+ (nullable NSURL *)dashcamClipsAPIRequestURLFromPreferenceInMOC:(NSManagedObjectContext *)moc
                                                        deviceId:(NSInteger)deviceId
                                                       fromUnix:(NSInteger)fromUnix
                                                         toUnix:(NSInteger)toUnix {
    NSURL *origin = [self webAppOriginURLFromPreferenceInMOC:moc];
    if (!origin) {
        return nil;
    }
    NSURLComponents *c = [NSURLComponents componentsWithURL:origin resolvingAgainstBaseURL:NO];
    c.path = @"/api/dashcam/clips";
    c.queryItems = @[
        [NSURLQueryItem queryItemWithName:@"deviceId" value:[NSString stringWithFormat:@"%ld", (long)deviceId]],
        [NSURLQueryItem queryItemWithName:@"from" value:[NSString stringWithFormat:@"%ld", (long)fromUnix]],
        [NSURLQueryItem queryItemWithName:@"to" value:[NSString stringWithFormat:@"%ld", (long)toUnix]],
    ];
    c.fragment = nil;
    return c.URL;
}

+ (NSString *)OT_pathEncodedDashcamClipId:(NSString *)clipId {
    NSCharacterSet *allowed = [NSCharacterSet characterSetWithCharactersInString:
        @"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~"];
    return [clipId stringByAddingPercentEncodingWithAllowedCharacters:allowed] ?: @"";
}

+ (nullable NSURL *)dashcamThumbAPIURLFromPreferenceInMOC:(NSManagedObjectContext *)moc
                                                   clipId:(NSString *)clipId
                                              accessToken:(nullable NSString *)accessToken {
    NSURL *origin = [self webAppOriginURLFromPreferenceInMOC:moc];
    if (!origin || clipId.length == 0) {
        return nil;
    }
    NSString *encoded = [self OT_pathEncodedDashcamClipId:clipId];
    if (encoded.length == 0) {
        return nil;
    }
    NSURLComponents *c = [NSURLComponents componentsWithURL:origin resolvingAgainstBaseURL:NO];
    c.percentEncodedPath = [NSString stringWithFormat:@"/api/dashcam/thumb/%@", encoded];
    if (accessToken.length > 0) {
        c.queryItems = @[ [NSURLQueryItem queryItemWithName:@"access_token" value:accessToken] ];
    } else {
        c.query = nil;
    }
    c.fragment = nil;
    return c.URL;
}

+ (nullable NSURL *)dashcamStreamAPIURLFromPreferenceInMOC:(NSManagedObjectContext *)moc
                                                    clipId:(NSString *)clipId
                                                    camera:(NSString *)camera
                                               accessToken:(nullable NSString *)accessToken {
    NSURL *origin = [self webAppOriginURLFromPreferenceInMOC:moc];
    if (!origin || clipId.length == 0 || camera.length == 0) {
        return nil;
    }
    NSString *encClip = [self OT_pathEncodedDashcamClipId:clipId];
    NSString *encCam = [self OT_pathEncodedDashcamClipId:camera];
    if (encClip.length == 0 || encCam.length == 0) {
        return nil;
    }
    NSURLComponents *c = [NSURLComponents componentsWithURL:origin resolvingAgainstBaseURL:NO];
    c.percentEncodedPath = [NSString stringWithFormat:@"/api/dashcam/stream/%@/%@", encClip, encCam];
    if (accessToken.length > 0) {
        c.queryItems = @[ [NSURLQueryItem queryItemWithName:@"access_token" value:accessToken] ];
    } else {
        c.query = nil;
    }
    c.fragment = nil;
    return c.URL;
}

+ (nullable NSURL *)dashcamTelemetryAPIURLFromPreferenceInMOC:(NSManagedObjectContext *)moc
                                                       clipId:(NSString *)clipId
                                                       camera:(NSString *)camera
                                                  accessToken:(nullable NSString *)accessToken {
    NSURL *origin = [self webAppOriginURLFromPreferenceInMOC:moc];
    if (!origin || clipId.length == 0 || camera.length == 0) {
        return nil;
    }
    NSString *encClip = [self OT_pathEncodedDashcamClipId:clipId];
    NSString *encCam = [self OT_pathEncodedDashcamClipId:camera];
    if (encClip.length == 0 || encCam.length == 0) {
        return nil;
    }
    NSURLComponents *c = [NSURLComponents componentsWithURL:origin resolvingAgainstBaseURL:NO];
    c.percentEncodedPath = [NSString stringWithFormat:@"/api/dashcam/telemetry/%@/%@", encClip, encCam];
    if (accessToken.length > 0) {
        c.queryItems = @[ [NSURLQueryItem queryItemWithName:@"access_token" value:accessToken] ];
    } else {
        c.query = nil;
    }
    c.fragment = nil;
    return c.URL;
}

@end
