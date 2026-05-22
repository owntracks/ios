//
//  Settings.m
//  OwnTracks
//
//  Created by Christoph Krey on 31.01.14.
//  Copyright © 2014-2025  Christoph Krey. All rights reserved.
//

#import "Settings.h"
#import "CoreData.h"
#import "OwnTracking.h"
#import "LocationManager.h"
#import "Friend+CoreDataClass.h"
#import <UIKit/UIKit.h>
#import <CocoaLumberjack/CocoaLumberjack.h>

static const DDLogLevel ddLogLevel = DDLogLevelInfo;

static NSString *OTTrimProvisioningString(id obj) {
    if (![obj isKindOfClass:[NSString class]]) {
        return @"";
    }
    return [(NSString *)obj stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

/// Same rules as `LocationAPISyncService` `OTProvisionSanitizedDeviceName` (for comparing server `deviceId` to raw name).
static NSString *OTSettingsProvisionSanitizedDeviceName(void) {
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

static NSSet<NSString *> *OTSettingsForbiddenProvisionDeviceTokens(void) {
    static NSSet<NSString *> *set;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        set = [NSSet setWithArray:@[
            @"iphone", @"ipad", @"ipod", @"ipod touch", @"device", @"phone", @"ios", @"apple"
        ]];
    });
    return set;
}

static BOOL OTSettingsTokenEqualsForbiddenDeviceIdentity(NSString *token) {
    if (!token.length) {
        return NO;
    }
    return [OTSettingsForbiddenProvisionDeviceTokens() containsObject:token.lowercaseString];
}

/// True if any alphanumeric token in `s` matches a forbidden generic device word (e.g. `Toms-iPhone-OTT`).
static BOOL OTSettingsIdentityStringContainsGenericToken(NSString *s) {
    if (![s isKindOfClass:[NSString class]] || s.length == 0) {
        return NO;
    }
    NSCharacterSet *sep = [[NSCharacterSet alphanumericCharacterSet] invertedSet];
    for (NSString *part in [s componentsSeparatedByCharactersInSet:sep]) {
        if (part.length && OTSettingsTokenEqualsForbiddenDeviceIdentity(part)) {
            return YES;
        }
    }
    return NO;
}

/// `applyLocalProvisionIdentityRepair` uses `slug-<6 hex from idfv>`; the slug may still spell `iphone`, which must not trip generic-token detection for the whole id.
static BOOL OTSettingsDeviceIdLooksLikeSlugPlusSixHexSuffix(NSString *t) {
    if (![t isKindOfClass:[NSString class]] || t.length == 0) {
        return NO;
    }
    NSString *lower = t.lowercaseString;
    NSArray<NSString *> *parts = [lower componentsSeparatedByString:@"-"];
    if (parts.count != 2) {
        return NO;
    }
    NSString *head = parts[0];
    NSString *tail = parts[1];
    if (head.length < 1 || head.length > 28 || tail.length != 6) {
        return NO;
    }
    NSCharacterSet *nonHex = [[NSCharacterSet characterSetWithCharactersInString:@"0123456789abcdef"] invertedSet];
    if ([tail rangeOfCharacterFromSet:nonHex].location != NSNotFound) {
        return NO;
    }
    NSCharacterSet *nonAlnum = [[NSCharacterSet alphanumericCharacterSet] invertedSet];
    if ([head rangeOfCharacterFromSet:nonAlnum].location != NSNotFound) {
        return NO;
    }
    return YES;
}

static BOOL OTSettingsDeviceIdOrClientIdStringIsSuspect(NSString *s) {
    if (![s isKindOfClass:[NSString class]]) {
        return NO;
    }
    NSString *t = [s stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (!t.length) {
        return NO;
    }
    if (OTSettingsDeviceIdLooksLikeSlugPlusSixHexSuffix(t)) {
        return NO;
    }
    if (OTSettingsIdentityStringContainsGenericToken(t)) {
        return YES;
    }
    if (OTSettingsTokenEqualsForbiddenDeviceIdentity(t)) {
        return YES;
    }
    if (t.length < 3) {
        return YES;
    }
    NSString *san = OTSettingsProvisionSanitizedDeviceName();
    if (san.length && [t caseInsensitiveCompare:san] == NSOrderedSame) {
        return YES;
    }
    NSString *model = [UIDevice currentDevice].model;
    if (model.length && [t caseInsensitiveCompare:model] == NSOrderedSame) {
        return YES;
    }
    if (t.length > 0 && t.length < 36) {
        NSString *tl = t.lowercaseString;
        if ([tl rangeOfString:@"iphone"].location != NSNotFound ||
            [tl rangeOfString:@"ipad"].location != NSNotFound ||
            [tl rangeOfString:@"ipod"].location != NSNotFound) {
            return YES;
        }
    }
    return NO;
}

/// True when `deviceId` equals the last path segment of `topicOrPubBase` (trimmed; percent-decoded), case-insensitive.
/// Used when the broker topic was explicitly keyed with a display-style name so local "suspect" heuristics do not reject it.
static BOOL OTSettingsDeviceIdMatchesTopicPathTail(NSString *deviceId, NSString *topicOrPubBase) {
    if (![deviceId isKindOfClass:[NSString class]] || deviceId.length == 0) {
        return NO;
    }
    if (![topicOrPubBase isKindOfClass:[NSString class]] || topicOrPubBase.length == 0) {
        return NO;
    }
    NSString *pub = [topicOrPubBase stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (!pub.length) {
        return NO;
    }
    NSArray<NSString *> *parts = [pub componentsSeparatedByString:@"/"];
    NSString *last = parts.lastObject;
    last = [last stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (!last.length) {
        return NO;
    }
    NSString *decoded = last.stringByRemovingPercentEncoding;
    if (!decoded.length) {
        decoded = last;
    }
    NSString *did = [deviceId stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    return did.length > 0 && [decoded caseInsensitiveCompare:did] == NSOrderedSame;
}

/// Alphanumeric + ASCII hyphen only (OwnTracks-style MQTT client slugs from the broker).
static BOOL OTSettingsProvisionClientIdIsAlphanumericHyphenSlug(NSString *s) {
    if (![s isKindOfClass:[NSString class]] || s.length < 12) {
        return NO;
    }
    NSCharacterSet *allowed =
        [NSCharacterSet characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-"];
    return [s rangeOfCharacterFromSet:allowed.invertedSet].location == NSNotFound;
}

static NSString *OTSettingsIdentitySlugFromVisibleString(NSString *raw) {
    if (![raw isKindOfClass:[NSString class]] || raw.length == 0) {
        return @"user";
    }
    NSCharacterSet *allowed = [NSCharacterSet alphanumericCharacterSet];
    NSMutableString *out = [NSMutableString string];
    for (NSUInteger i = 0; i < raw.length; i++) {
        unichar c = [raw characterAtIndex:i];
        if ([allowed characterIsMember:c]) {
            [out appendFormat:@"%C", c];
        }
    }
    if (!out.length) {
        return @"user";
    }
    NSString *lower = out.lowercaseString;
    if (lower.length > 28) {
        return [lower substringToIndex:28];
    }
    return lower;
}

static NSInteger OTSettingsModeFromPayloadOrMOC(NSDictionary *payload, NSManagedObjectContext *moc) {
    id modeObj = payload[@"mode"];
    if ([modeObj isKindOfClass:[NSNumber class]]) {
        return [(NSNumber *)modeObj integerValue];
    }
    if ([modeObj isKindOfClass:[NSString class]]) {
        return [(NSString *)modeObj integerValue];
    }
    return [Settings intForKey:@"mode" inMOC:moc];
}

static NSInteger OTSettingsTidAmbiguousFriendCount(NSString *tid, NSManagedObjectContext *moc) {
    if (!tid.length) {
        return 0;
    }
    NSFetchRequest *req = [NSFetchRequest fetchRequestWithEntityName:@"Friend"];
    NSError *ferr = nil;
    NSArray *friends = [moc executeFetchRequest:req error:&ferr];
    if (ferr) {
        DDLogWarn(@"[Settings] OTSettingsTidAmbiguousFriendCount fetch: %@", ferr);
        return 0;
    }
    NSInteger n = 0;
    for (Friend *f in friends) {
        if ([f.effectiveTid isEqualToString:tid]) {
            n++;
        }
    }
    return n;
}

/// Picks a short `tid` from idfv hex (sliding 6-char window, then random UUID tries) until at most one Friend matches `effectiveTid`.
static NSString *OTSettingsPickRepairTidFromIdfvHexAvoidingAmbiguity(NSString *hex, NSManagedObjectContext *moc) {
    if (![hex isKindOfClass:[NSString class]] || hex.length < 6) {
        return @"DEVICE";
    }
    NSMutableOrderedSet<NSString *> *tried = [NSMutableOrderedSet orderedSet];
    NSUInteger maxStart = hex.length - 6;
    for (NSUInteger start = 0; start <= maxStart && start < 32u; start++) {
        NSString *cand = [[hex substringWithRange:NSMakeRange(start, 6)] uppercaseString];
        if ([tried containsObject:cand]) {
            continue;
        }
        [tried addObject:cand];
        if (OTSettingsTidAmbiguousFriendCount(cand, moc) <= 1) {
            return cand;
        }
    }
    for (NSInteger attempt = 0; attempt < 24; attempt++) {
        NSString *uuidHex = [[[[NSUUID UUID] UUIDString] lowercaseString] stringByReplacingOccurrencesOfString:@"-" withString:@""];
        if (uuidHex.length < 6) {
            continue;
        }
        NSString *cand = [[uuidHex substringToIndex:6] uppercaseString];
        if ([tried containsObject:cand]) {
            continue;
        }
        [tried addObject:cand];
        if (OTSettingsTidAmbiguousFriendCount(cand, moc) <= 1) {
            return cand;
        }
    }
    return [[hex substringToIndex:MIN(6u, (unsigned)hex.length)] uppercaseString];
}


@interface SettingsDefaults: NSObject
@property (strong, nonatomic) NSDictionary *mqttDefaults;
@property (strong, nonatomic) NSDictionary *httpDefaults;
@end

static SettingsDefaults *defaults;

static NSString * const kOwnTracksNeedsWebProvisioningKey = @"owntracks_needs_web_provisioning";
static NSString * const kOwnTracksNeedsWebProvisioningMigratedV1Key = @"owntracks_needs_web_provisioning_migrated_v1";

@implementation SettingsDefaults
+ (SettingsDefaults *)theDefaults {
    if (!defaults) {
        defaults = [[SettingsDefaults alloc] init];
    }
    return defaults;
}

- (instancetype)init {
    self = [super init];

    if (self) {
        NSURL *mqttPlistURL = [[NSBundle mainBundle] URLForResource:@"MQTT"
                                                      withExtension:@"plist"];
        NSURL *httpPlistURL = [[NSBundle mainBundle] URLForResource:@"HTTP"
                                                      withExtension:@"plist"];
        self.mqttDefaults = [NSDictionary dictionaryWithContentsOfURL:mqttPlistURL];
        self.httpDefaults = [NSDictionary dictionaryWithContentsOfURL:httpPlistURL];
    }

    return self;
}

@end

@implementation Settings

+ (NSError *)fromStream:(NSInputStream *)input
                  inMOC:(NSManagedObjectContext *)context {
    NSError *error;
    
    NSDictionary *dictionary = [NSJSONSerialization JSONObjectWithStream:input
                                                                 options:0
                                                                   error:&error];
    if (dictionary) {
        return [self fromDictionary:dictionary inMOC:context];
    } else {
        return error;
    }
}

+ (NSError *)fromDictionary:(NSDictionary *)dictionary
                      inMOC:(NSManagedObjectContext *)context {
    if (dictionary && [dictionary isKindOfClass:[NSDictionary class]]) {
        for (NSString *key in dictionary.allKeys) {
            NSObject *object = dictionary[key];
            DDLogInfo(@"Configuration %@:%@ (%@)", key, object, object.class);
        }
        
        NSString *type = dictionary[@"_type"];
        if (type && [type isKindOfClass:[NSString class]] && [type isEqualToString:@"configuration"]) {
            NSObject *object;

            NSNumber *mode = dictionary[@"mode"];
            if (mode) {
                if ([mode isKindOfClass:[NSNumber class]] &&
                (mode.intValue == CONNECTION_MODE_MQTT ||
                 mode.intValue == CONNECTION_MODE_HTTP)) {
                    [self setInt:mode.intValue forKey:@"mode" inMOC:context];
                } else {
                    DDLogError(@"[Settings] fromDictionary invalid mode");
                    return [NSError errorWithDomain:@"OwnTracks Settings"
                                               code:1
                                           userInfo:@{@"mode": [NSString stringWithFormat:@"%@", dictionary[@"mode"]]}];
                }
            }

            object = dictionary[@"deviceId"];
            if (object) [self setString:(NSString *)object forKey:@"deviceid_preference" inMOC:context];

            object = dictionary[@"tid"];
            if (object) [self setString:object forKey:@"trackerid_preference" inMOC:context];
            
            object = dictionary[@"clientId"];
            if (object) [self setString:object forKey:@"clientid_preference" inMOC:context];
            
            object = dictionary[@"subTopic"];
            if (object) [self setString:object forKey:@"subscription_preference" inMOC:context];
            
            object = dictionary[@"pubTopicBase"];
            if (object) [self setString:object forKey:@"topic_preference" inMOC:context];
            
            object = dictionary[@"host"];
            if (object) [self setString:object forKey:@"host_preference" inMOC:context];
            
            object = dictionary[@"url"];
            if (object) [self setString:object forKey:@"url_preference" inMOC:context];

            object = dictionary[@"httpHeaders"];
            if (object) [self setString:object forKey:@"httpheaders_preference" inMOC:context];

            object = dictionary[@"encryptionKey"];
            if (object) [self setString:object forKey:@"secret_preference" inMOC:context];

            object = dictionary[@"osmTemplate"];
            if (object) [self setString:object forKey:@"osmtemplate_preference" inMOC:context];

            object = dictionary[@"osmCopyright"];
            if (object) [self setString:object forKey:@"osmcopyright_preference" inMOC:context];

            object = dictionary[@"username"];
            if (object) [self setString:object forKey:@"user_preference" inMOC:context];

            object = dictionary[@"password"];
            if (object) [self setString:object forKey:@"pass_preference" inMOC:context];

            object = dictionary[@"webappurl"];
            if (object) [self setString:(NSString *)object forKey:@"webappurl_preference" inMOC:context];

            object = dictionary[@"oidc_discovery_url"];
            if (object) [self setString:(NSString *)object forKey:@"oidc_discovery_url_preference" inMOC:context];

            object = dictionary[@"oauth_client_id"];
            if (object) [self setString:(NSString *)object forKey:@"oauth_client_id_preference" inMOC:context];

            object = dictionary[@"subQos"];
            if (object) [self setString:object forKey:@"subscriptionqos_preference" inMOC:context];
            
            object = dictionary[@"pubQos"];
            if (object) [self setString:object forKey:@"qos_preference" inMOC:context];
            
            object = dictionary[@"port"];
            if (object) [self setString:object forKey:@"port_preference" inMOC:context];

            object = dictionary[@"mqttProtocolLevel"];
            if (object) [self setString:object forKey:SETTINGS_PROTOCOL inMOC:context];

            object = dictionary[@"ignoreStaleLocations"];
            if (object) [self setString:object forKey:@"ignorestalelocations_preference" inMOC:context];

            object = dictionary[@"ignoreInaccurateLocations"];
            if (object) [self setString:object forKey:@"ignoreinaccuratelocations_preference" inMOC:context];

            object = dictionary[@"keepalive"];
            if (object) [self setString:object forKey:@"keepalive_preference" inMOC:context];
                        
            object = dictionary[@"locatorDisplacement"];
            if (object) {
                [self setString: object forKey:@"mindist_preference" inMOC:context];
                [LocationManager sharedInstance].minDist =
                [Settings doubleForKey:@"mindist_preference"
                              inMOC:context];
            }
            
            object = dictionary[@"locatorInterval"];
            if (object) {
                [self setString:object forKey:@"mintime_preference" inMOC:context];
                [LocationManager sharedInstance].minTime =
                [Settings doubleForKey:@"mintime_preference"
                              inMOC:context];
            }
            
            object = dictionary[@"monitoring"];
            if (object) {
                [[NSUserDefaults standardUserDefaults] setBool:FALSE forKey:@"downgraded"];
                [self setString:object forKey:@"monitoring_preference" inMOC:context];
                [LocationManager sharedInstance].monitoring =
                [Settings intForKey:@"monitoring_preference"
                              inMOC:context];
            }

            object = dictionary[@"downgrade"];
            if (object) [self setString:object forKey:@"downgrade_preference" inMOC:context];
            
            object = dictionary[@"adapt"];
            if (object) [self setString:object forKey:@"adapt_preference" inMOC:context];
            
            object = dictionary[@"ranging"];
            if (object) [self setString:object forKey:@"ranging_preference" inMOC:context];
            
            object = dictionary[@"cmd"];
            if (object) [self setString:object forKey:@"cmd_preference" inMOC:context];

            object = dictionary[@"sub"];
            if (object) [self setString:object forKey:@"sub_preference" inMOC:context];

            object = dictionary[@"pubRetain"];
            if (object) [self setString:object forKey:@"retain_preference" inMOC:context];
            
            object = dictionary[@"tls"];
            if (object) [self setString:object forKey:@"tls_preference" inMOC:context];

            object = dictionary[@"ws"];
            if (object) [self setString:object forKey:@"ws_preference" inMOC:context];

            object = dictionary[@"auth"];
            if (object) [self setString:object forKey:@"auth_preference" inMOC:context];

            object = dictionary[@"usePassword"];
            if (object) [self setString:object forKey:@"usepassword_preference" inMOC:context];

            object = dictionary[@"cleanSession"];
            if (object) [self setString:object forKey:@"clean_preference" inMOC:context];
            
            object = dictionary[@"positions"];
            if (object) [self setString:object forKey:@"positions_preference" inMOC:context];

            object = dictionary[@"days"];
            if (object) [self setString:object forKey:@"days_preference" inMOC:context];

            object = dictionary[@"maxHistory"];
            if (object) [self setString:object forKey:@"maxhistory_preference" inMOC:context];

            object = dictionary[@"allowRemoteLocation"];
            if (object) [self setString:object forKey:@"allowremotelocation_preference" inMOC:context];
            
            object = dictionary[@"extendedData"];
            if (object) [self setString:object forKey:@"extendeddata_preference" inMOC:context];
            
            object = dictionary[@"locked"];
            if (object) [self setString:object forKey:@"locked" inMOC:context];
            
            object = dictionary[@"clientpkcs"];
            if (object) [self setString:object forKey:@"clientpkcs" inMOC:context];

            object = dictionary[@"passphrase"];
            if (object) [self setString:object forKey:@"passphrase" inMOC:context];
            
            object = dictionary[@"allowinvalidcerts"];
            if (object) [self setString:object forKey:@"allowinvalidcerts" inMOC:context];
                                                
            NSArray *waypoints = dictionary[@"waypoints"];
            if (waypoints) [self setWaypoints:waypoints inMOC:context];
            
        } else {
            DDLogError(@"[Settings] fromDictionary invalid _type");
            return [NSError errorWithDomain:@"OwnTracks Settings"
                                       code:1
                                   userInfo:@{@"_type": [NSString stringWithFormat:@"%@", dictionary[@"_type"]]}];
        }
    } else {
        DDLogError(@"[Settings] fromDictionary invalid dictionary");
        return [NSError errorWithDomain:@"OwnTracks Settings"
                                   code:2
                               userInfo:@{}];
    }

    return nil;
}

+ (NSError *)waypointsFromStream:(NSInputStream *)input
                           inMOC:(NSManagedObjectContext *)context  {
    NSError *error;
    
    NSDictionary *dictionary = [NSJSONSerialization JSONObjectWithStream:input
                                                                 options:0
                                                                   error:&error];
    if (dictionary) {
        return [self waypointsFromDictionary:dictionary inMOC:context];
    } else {
        return error;
    }
}

+ (NSError *)waypointsFromDictionary:(NSDictionary *)dictionary
                               inMOC:(NSManagedObjectContext *)context {
    if (dictionary && [dictionary isKindOfClass:[NSDictionary class]]) {
        for (NSString *key in dictionary.allKeys) {
            DDLogVerbose(@"Waypoints %@:%@", key, dictionary[key]);
        }
        
        if ([dictionary[@"_type"] isEqualToString:@"waypoints"]) {
            NSArray *waypoints = dictionary[@"waypoints"];
            [self setWaypoints:waypoints inMOC:context];
        } else {
            return [NSError errorWithDomain:@"OwnTracks Waypoints"
                                       code:1
                                   userInfo:@{@"_type": dictionary[@"_type"]}];
        }
    }
    return nil;
}

+ (void)setWaypoints:(NSArray *)waypoints
               inMOC:(NSManagedObjectContext *)context {
    if (!waypoints || ![waypoints isKindOfClass:[NSArray class]]) {
        DDLogError(@"[Settings][setWaypoints] invalid waypoints array");
        return;
    }
    
    for (NSDictionary *waypoint in waypoints) {
        if (![waypoint isKindOfClass:[NSDictionary class]]) {
            DDLogError(@"[Settings][setWaypoints] waypoints array does contain non dictionary");
            continue;
        }
        
        NSString *type = waypoint[@"_type"];
        if (!type || ![type isKindOfClass:[NSString class]] || ![type isEqualToString:@"waypoint"]) {
            DDLogError(@"[Settings][setWaypoints] waypoint does not contain _type waypoint");
            continue;
        }
        
        NSString *desc = waypoint[@"desc"];
        if (!desc || ![desc isKindOfClass:[NSString class]]) {
            DDLogError(@"[Settings][setWaypoints] waypoint does not contain valid desc");
            continue;
        }

        NSArray *components = [desc componentsSeparatedByString:@":"];
        NSString *name = components[0];
        NSString *uuid = components.count >= 2 ? components[1] : nil;
        unsigned int major = components.count >= 3 ? [components[2] unsignedIntValue]: 0;
        unsigned int minor = components.count >= 4 ? [components[3] unsignedIntValue]: 0;
        
        NSNumber *tstNumber = waypoint[@"tst"];
        if (!tstNumber || ![tstNumber isKindOfClass:[NSNumber class]]) {
            DDLogError(@"[Settings][setWaypoints] waypoint does not contain valid tst");
            continue;
        }
        
        NSDate *tst = [NSDate dateWithTimeIntervalSince1970:
                       [tstNumber doubleValue]];
                        
        NSString *rid = waypoint[@"rid"];
        if (!rid || ![rid isKindOfClass:[NSString class]]) {
            rid = [Region ridFromTst:tst andName:name];
        }
                        
        Friend *friend = [Friend friendWithTopic:[self theGeneralTopicInMOC:context]
                          inManagedObjectContext:context];
                        
        for (Region *region in friend.hasRegions) {
            if ([region.getAndFillRid isEqualToString:rid]) {
                DDLogVerbose(@"[Settings][setWaypoints] removeRegion %@", rid);
                [[OwnTracking sharedInstance] removeRegion:region context:context];
                break;
            }
        }
                        
        CLLocationDegrees latDegrees = 0.0;
        NSNumber *lat = waypoint[@"lat"];
        if (lat && ![lat isKindOfClass:[NSNumber class]]) {
            DDLogError(@"[Settings][setWaypoints] json does not contain valid lat: not processed");
            continue;
        }
        latDegrees = lat.doubleValue;

        CLLocationDegrees lonDegrees = 0.0;
        NSNumber *lon = waypoint[@"lon"];
        if (lon && ![lon isKindOfClass:[NSNumber class]]) {
            DDLogError(@"[Settings][setWaypoints] json does not contain valid lon: not processed");
            continue;
        }
        lonDegrees = lon.doubleValue;
        
        CLLocationCoordinate2D coord = CLLocationCoordinate2DMake(latDegrees, lonDegrees);
        if (!CLLocationCoordinate2DIsValid(coord)) {
            DDLogError(@"[Settings][setWaypoints] coord is no valid: not processed");
            continue;
        }

        CLLocationDistance radDistance = 0.0;
        NSNumber *rad = waypoint[@"rad"];
        if (rad && ![rad isKindOfClass:[NSNumber class]]) {
            DDLogError(@"[Settings][setWaypoints] json does not contain valid rad: not processed");
            continue;
        }
        radDistance = rad.doubleValue;

        [[OwnTracking sharedInstance] addRegionFor:rid
                                            friend:friend
                                              name:name
                                               tst:tst
                                              uuid:uuid
                                             major:major
                                             minor:minor
                                            radius:radDistance
                                               lat:latDegrees
                                               lon:lonDegrees];
    }
}

+ (NSError *)clearWaypoints:(NSManagedObjectContext *)context {
    Friend *friend = [Friend friendWithTopic:[self theGeneralTopicInMOC:context]
                            inManagedObjectContext:context];

    while (friend.hasRegions.count) {
        Region *region = friend.hasRegions.anyObject;
        DDLogInfo(@"[Settings][clearWaypoints] removeRegion %@", region.rid);
        [[OwnTracking sharedInstance] removeRegion:region context:context];
    }
    DDLogInfo(@"[Settings][clearWaypoints] clearWaypoints");
    return nil;
}

+ (void)resetStoredPreferencesToBundledDefaultsInMOC:(NSManagedObjectContext *)context {
    NSArray *stored = [Setting allSettingsInMOC:context];
    for (Setting *setting in stored) {
        [context deleteObject:setting];
    }
    [CoreData.sharedInstance sync:context];

    LocationManager *lm = [LocationManager sharedInstance];
    lm.monitoring = [Settings intForKey:@"monitoring_preference" inMOC:context];
    lm.ranging = [Settings boolForKey:@"ranging_preference" inMOC:context];
    lm.minDist = [Settings doubleForKey:@"mindist_preference" inMOC:context];
    lm.minTime = [Settings doubleForKey:@"mintime_preference" inMOC:context];

    DDLogInfo(@"[Settings] resetStoredPreferencesToBundledDefaults — removed %lu Setting row(s)",
              (unsigned long)stored.count);
}

#pragma mark - Web provisioning (embedded WebView / needs_provision)

+ (void)setNeedsWebProvisioning:(BOOL)needs {
    [[NSUserDefaults standardUserDefaults] setBool:needs forKey:kOwnTracksNeedsWebProvisioningKey];
    DDLogInfo(@"[Provisioning] setNeedsWebProvisioning → %@", needs ? @"YES" : @"NO");
}

+ (BOOL)userDefaultsIndicatesNeedsWebProvisioning {
    return [[NSUserDefaults standardUserDefaults] boolForKey:kOwnTracksNeedsWebProvisioningKey];
}

+ (BOOL)legacyBrokerHostIndicatesNeedsWebProvisioningInMOC:(NSManagedObjectContext *)moc {
    NSString *host = [self theHostInMOC:moc];
    if (!host || host.length == 0) {
        return YES;
    }
    if ([host isEqualToString:@"host"]) {
        return YES;
    }
    return NO;
}

+ (BOOL)appEmbeddedWebShouldRequestProvisioningInMOC:(NSManagedObjectContext *)moc {
    return [self userDefaultsIndicatesNeedsWebProvisioning] ||
           [self legacyBrokerHostIndicatesNeedsWebProvisioningInMOC:moc];
}

+ (void)migrateWebProvisioningFlagIfNeededInMOC:(NSManagedObjectContext *)moc {
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    if ([ud boolForKey:kOwnTracksNeedsWebProvisioningMigratedV1Key]) {
        DDLogVerbose(@"[Provisioning] migrateWebProvisioningFlag v1 — already migrated");
        return;
    }
    BOOL initial = [self legacyBrokerHostIndicatesNeedsWebProvisioningInMOC:moc];
    NSString *host = [self theHostInMOC:moc] ?: @"(nil)";
    [ud setBool:initial forKey:kOwnTracksNeedsWebProvisioningKey];
    [ud setBool:YES forKey:kOwnTracksNeedsWebProvisioningMigratedV1Key];
    DDLogInfo(@"[Provisioning] migrateWebProvisioningFlag v1 — needs_web_provisioning=%@ (legacyHost=%@ theHost=%@)",
              initial ? @"YES" : @"NO",
              [self legacyBrokerHostIndicatesNeedsWebProvisioningInMOC:moc] ? @"YES" : @"NO",
              host);
}

+ (void)markWebProvisioningSatisfiedAfterApplyingConfigurationDictionary:(NSDictionary *)dictionary
                                                                    error:(NSError *)error {
    if (error) {
        DDLogWarn(@"[Provisioning] markWebProvisioningSatisfied — skipped (fromDictionary error: %@)", error);
        return;
    }
    NSString *type = dictionary[@"_type"];
    if (![type isKindOfClass:[NSString class]] || ![type isEqualToString:@"configuration"]) {
        DDLogWarn(@"[Provisioning] markWebProvisioningSatisfied — skipped (_type=%@, expected configuration)",
                  type ?: @"(nil)");
        return;
    }
    [self setNeedsWebProvisioning:NO];
}

+ (NSString *)webProvisioningDebugSummaryInMOC:(NSManagedObjectContext *)moc {
    BOOL ud = [self userDefaultsIndicatesNeedsWebProvisioning];
    BOOL leg = [self legacyBrokerHostIndicatesNeedsWebProvisioningInMOC:moc];
    NSString *host = [self theHostInMOC:moc] ?: @"(nil)";
    BOOL combined = [self appEmbeddedWebShouldRequestProvisioningInMOC:moc];
    return [NSString stringWithFormat:
            @"appNeedsProvision=%@ ud_flag=%@ legacy_placeholder_host=%@ theHostInMOC=%@",
            combined ? @"YES" : @"NO", ud ? @"YES" : @"NO", leg ? @"YES" : @"NO", host];
}

+ (void)applyCanonicalDeviceIdFromPubTopicTailIfDeviceIdSuspectToMutableConfiguration:(NSMutableDictionary *)payload {
    if (![payload isKindOfClass:[NSMutableDictionary class]] || payload.count == 0) {
        return;
    }
    NSString *did = OTTrimProvisioningString(payload[@"deviceId"]);
    if (!did.length || !OTSettingsDeviceIdOrClientIdStringIsSuspect(did)) {
        return;
    }
    NSString *pub = OTTrimProvisioningString(payload[@"pubTopicBase"]);
    if (!pub.length) {
        return;
    }
    NSArray<NSString *> *parts = [pub componentsSeparatedByString:@"/"];
    NSString *last = parts.lastObject;
    last = [last stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (!last.length || [last caseInsensitiveCompare:did] == NSOrderedSame) {
        return;
    }
    if (OTSettingsDeviceIdOrClientIdStringIsSuspect(last)) {
        return;
    }
    payload[@"deviceId"] = last;
    DDLogInfo(@"[Provisioning] applyCanonicalDeviceIdFromPubTopicTail — deviceId was suspect (%@); aligned to topic tail \"%@\"",
              did, last);
}

+ (void)applyLocalProvisionIdentityRepairToMutableConfiguration:(NSMutableDictionary *)payload
                                                         inMOC:(NSManagedObjectContext *)moc {
    if (![payload isKindOfClass:[NSMutableDictionary class]] || payload.count == 0) {
        return;
    }
    if ([self validationErrorForRemoteProvisionConfiguration:payload inMOC:moc] == nil) {
        return;
    }

    NSUUID *idfv = [UIDevice currentDevice].identifierForVendor;
    NSString *uuidStr = idfv ? idfv.UUIDString : @"";
    NSString *hex = [[uuidStr stringByReplacingOccurrencesOfString:@"-" withString:@""] lowercaseString];
    while (hex.length < 6) {
        hex = [@"0" stringByAppendingString:hex];
    }
    NSString *suffix = [hex substringFromIndex:hex.length - 6];

    NSString *userRaw = OTTrimProvisioningString(payload[@"username"]);
    if (!userRaw.length) {
        userRaw = [self stringForKey:@"user_preference" inMOC:moc];
    }
    NSString *userSlug = OTSettingsIdentitySlugFromVisibleString(userRaw);

    NSString *nameRaw = OTSettingsProvisionSanitizedDeviceName();
    NSString *namePart = OTSettingsIdentitySlugFromVisibleString(nameRaw);
    if ([namePart isEqualToString:@"user"]) {
        namePart = @"dev";
    }
    if (namePart.length > 14) {
        namePart = [namePart substringToIndex:14];
    }

    NSString *newDeviceId = [NSString stringWithFormat:@"%@-%@", namePart, suffix];
    payload[@"deviceId"] = newDeviceId;
    payload[@"username"] = userSlug;

    NSInteger mode = OTSettingsModeFromPayloadOrMOC(payload, moc);
    if (mode == CONNECTION_MODE_MQTT) {
        NSUInteger maxUser = 32 - suffix.length;
        NSString *u = userSlug;
        if (maxUser < 1u) {
            u = @"u";
        } else if (u.length > maxUser) {
            u = [u substringToIndex:maxUser];
        }
        payload[@"clientId"] = [NSString stringWithFormat:@"%@%@", u, suffix];
    }

    NSUInteger take = MIN(6u, (unsigned)hex.length);
    NSString *tidBody = OTSettingsPickRepairTidFromIdfvHexAvoidingAmbiguity(hex, moc);
    if (!tidBody.length) {
        tidBody = [[[hex substringToIndex:take] uppercaseString] copy];
    }
    payload[@"tid"] = tidBody;

    DDLogWarn(@"[Provisioning] applyLocalProvisionIdentityRepair — deviceId=%@ username=%@ tid=%@ (pubTopicBase unchanged)",
               newDeviceId, userSlug, tidBody);
}

+ (NSArray *)waypointsToArrayInMOC:(NSManagedObjectContext *)context {
    NSMutableArray *waypoints = [[NSMutableArray alloc] init];
    Friend *friend = [Friend existsFriendWithTopic:[self theGeneralTopicInMOC:context]
                            inManagedObjectContext:context];
    for (Region *region in friend.hasRegions) {
        [waypoints addObject:[[OwnTracking sharedInstance] regionAsJSON:region]];
    }
    
    return waypoints;
}



+ (NSDictionary *)waypointsToDictionaryInMOC:(NSManagedObjectContext *)context {
    return @{@"_type": @"waypoints", @"waypoints": [self waypointsToArrayInMOC:context]};
}

+ (NSDictionary *)toDictionaryInMOC:(NSManagedObjectContext *)context {
    NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
    dict[@"_type"] =                        @"configuration";
    dict[@"mode"] =                         @([Settings intForKey:@"mode" inMOC:context]);
    dict[@"ranging"] =                      @([Settings boolForKey:@"ranging_preference" inMOC:context]);
    dict[@"locked"] =                       @([Settings boolForKey:@"locked" inMOC:context]);
    dict[@"tid"] =                          [Settings stringOrZeroForKey:@"trackerid_preference" inMOC:context];
    dict[@"pubTopicBase"] =                 [Settings stringOrZeroForKey:@"topic_preference" inMOC:context];
    dict[@"monitoring"] =                   @([Settings intForKey:@"monitoring_preference" inMOC:context]);
    dict[@"downgrade"] =                    @([Settings intForKey:@"downgrade_preference" inMOC:context]);
    dict[@"adapt"] =                        @([Settings intForKey:@"adapt_preference" inMOC:context]);
    dict[@"waypoints"] =                    [Settings waypointsToArrayInMOC:context];
    dict[@"positions"] =                    @([Settings intForKey:@"positions_preference" inMOC:context]);
    dict[@"days"] =                         @([Settings intForKey:@"days_preference" inMOC:context]);
    dict[@"maxHistory"] =                   @([Settings intForKey:@"maxhistory_preference" inMOC:context]);
    dict[@"locatorDisplacement"] =          @([Settings intForKey:@"mindist_preference" inMOC:context]);
    dict[@"locatorInterval"] =              @([Settings intForKey:@"mintime_preference" inMOC:context]);
    dict[@"extendedData"] =                 @([Settings boolForKey:@"extendeddata_preference" inMOC:context]);
    dict[@"ignoreStaleLocations"] =         @([Settings doubleForKey:@"ignorestalelocations_preference" inMOC:context]);
    dict[@"ignoreInaccurateLocations"] =    @([Settings intForKey:@"ignoreinaccuratelocations_preference" inMOC:context]);

    dict[@"deviceId"] =             [Settings stringOrZeroForKey:@"deviceid_preference" inMOC:context];
    dict[@"cmd"] =                  @([Settings boolForKey:@"cmd_preference" inMOC:context]);
    dict[@"allowRemoteLocation"] =  @([Settings boolForKey:@"allowremotelocation_preference" inMOC:context]);
    dict[@"auth"] =                 @([Settings boolForKey:@"auth_preference" inMOC:context]);
    dict[@"usePassword"] =          @([Settings boolForKey:@"usepassword_preference" inMOC:context]);
    dict[@"encryptionKey"] =        [Settings stringOrZeroForKey:@"secret_preference" inMOC:context];
    dict[@"osmTemplate"] =          [Settings theOSMTemplate:context];
    dict[@"osmCopyright"] =         [Settings theOSMCopyrightInMOC:context];
    dict[@"username"] =             [Settings stringOrZeroForKey:@"user_preference" inMOC:context];
    dict[@"password"] =             [Settings stringOrZeroForKey:@"pass_preference" inMOC:context];
    dict[@"webappurl"] =            [Settings stringOrZeroForKey:@"webappurl_preference" inMOC:context];
    dict[@"oidc_discovery_url"] =   [Settings stringOrZeroForKey:@"oidc_discovery_url_preference" inMOC:context];
    dict[@"oauth_client_id"] =      [Settings stringOrZeroForKey:@"oauth_client_id_preference" inMOC:context];

    switch ([Settings intForKey:@"mode" inMOC:context]) {
        case CONNECTION_MODE_MQTT:
            dict[@"clientId"] =             [Settings stringOrZeroForKey:@"clientid_preference" inMOC:context];
            dict[@"sub"] =                  @([Settings boolForKey:@"sub_preference" inMOC:context]);
            dict[@"subTopic"] =             [Settings stringOrZeroForKey:@"subscription_preference" inMOC:context];
            dict[@"host"] =                 [Settings stringOrZeroForKey:@"host_preference" inMOC:context];
            dict[@"clientpkcs"] =           [Settings stringOrZeroForKey:@"clientpkcs" inMOC:context];
            dict[@"passphrase"] =           [Settings stringOrZeroForKey:@"passphrase" inMOC:context];
            
            dict[@"subQos"] =               @([Settings intForKey:@"subscriptionqos_preference" inMOC:context]);
            dict[@"pubQos"] =               @([Settings intForKey:@"qos_preference" inMOC:context]);
            dict[@"port"] =                 @([Settings intForKey:@"port_preference" inMOC:context]);
            dict[@"mqttProtocolLevel"] =    @([Settings intForKey:SETTINGS_PROTOCOL inMOC:context]);
            dict[@"keepalive"] =            @([Settings intForKey:@"keepalive_preference" inMOC:context]);

            dict[@"pubRetain"] =            @([Settings boolForKey:@"retain_preference" inMOC:context]);
            dict[@"tls"] =                  @([Settings boolForKey:@"tls_preference" inMOC:context]);
            dict[@"allowinvalidcerts"] =    @([Settings boolForKey:@"allowinvalidcerts" inMOC:context]);
            dict[@"ws"] =                   @([Settings boolForKey:@"ws_preference" inMOC:context]);
            dict[@"cleanSession"] =         @([Settings boolForKey:@"clean_preference" inMOC:context]);
            break;

        case CONNECTION_MODE_HTTP:
            dict[@"url"] =                  [Settings stringOrZeroForKey:@"url_preference" inMOC:context];
            dict[@"httpHeaders"] =          [Settings stringOrZeroForKey:@"httpheaders_preference" inMOC:context];
            break;

        default:
            break;
    }
    
    return dict;
}

+ (NSData *)waypointsToDataInMOC:(NSManagedObjectContext *)context {
    NSDictionary *dict = [Settings waypointsToDictionaryInMOC:context];
    
    NSError *error;
    NSData *myData = [NSJSONSerialization dataWithJSONObject:dict
                                                     options:NSJSONWritingPrettyPrinted
                                                       error:&error];
    return myData;
}

+ (NSData *)toDataInMOC:(NSManagedObjectContext *)context {
    NSDictionary *dict = [self toDictionaryInMOC:context];
    
    NSError *error;
    NSData *myData = [NSJSONSerialization dataWithJSONObject:dict
                                                     options:NSJSONWritingPrettyPrinted
                                                       error:&error];
    return myData;
}

+ (void)setString:(NSObject *)object
           forKey:(NSString *)key
            inMOC:(NSManagedObjectContext *)context {
    if (object && ![object isKindOfClass:[NSNull class]]) {
        Setting *setting = [Setting settingWithKey:key inMOC:context];
        setting.value = [NSString stringWithFormat:@"%@", object];
    } else {
        Setting *setting = [Setting existsSettingWithKey:key inMOC:context];
        if (setting) {
            [context deleteObject:setting];
        }
    }
}

+ (void)setInt:(int)i
        forKey:(NSString *)key
         inMOC:(NSManagedObjectContext *)context {
    [self setString:[NSString stringWithFormat:@"%d", i] forKey:key inMOC:context];
}

+ (void)setDouble:(double)d
           forKey:(NSString *)key
            inMOC:(NSManagedObjectContext *)context {
    [self setString:[NSString stringWithFormat:@"%f", d] forKey:key inMOC:context];
}

+ (void)setBool:(BOOL)b
         forKey:(NSString *)key
          inMOC:(NSManagedObjectContext *)context {
    DDLogVerbose(@"setBoolForKey:%@ = %d", key, b);
    [self setString:[NSString stringWithFormat:@"%d", b] forKey:key inMOC:context];
}

+ (NSString *)stringOrZeroForKey:(NSString *)key
                           inMOC:(NSManagedObjectContext *)context {
    NSString *value = [self stringForKey:key inMOC:context];
    if (!value) {
        DDLogVerbose(@"stringOrZeroForKey %@", key);
        value = @"";
    }
    return value;
}

+ (NSString *)stringForKey:(NSString *)key
                     inMOC:(NSManagedObjectContext *)context {
    return [Settings stringForKeyRaw:key inMOC:context];
}

+ (NSString *)stringForKeyUsingPlistDefaultWhenEmpty:(NSString *)key
                                              inMOC:(NSManagedObjectContext *)context {
    NSString *value = [Settings stringForKeyRaw:key inMOC:context];
    if (value.length) {
        return value;
    }
    id object = ([SettingsDefaults theDefaults].httpDefaults)[key];
    if (!object) {
        object = ([SettingsDefaults theDefaults].mqttDefaults)[key];
    }
    if ([object isKindOfClass:[NSString class]]) {
        return (NSString *)object;
    }
    if ([object isKindOfClass:[NSNumber class]]) {
        return ((NSNumber *)object).stringValue;
    }
    return @"";
}

+ (NSString *)stringForKeyRaw:(NSString *)key
                        inMOC:(NSManagedObjectContext *)context {
    __block NSString *value = nil;
    Setting *setting = [Setting existsSettingWithKey:key inMOC:context];
    if (setting) {
        value = setting.value;
    } else {
        id object = ([SettingsDefaults theDefaults].mqttDefaults)[key];
        if (!object) {
            object = ([SettingsDefaults theDefaults].httpDefaults)[key];
        }
        if (object) {
            if ([object isKindOfClass:[NSString class]]) {
                value = (NSString *)object;
            } else if ([object isKindOfClass:[NSNumber class]]) {
                value = ((NSNumber *)object).stringValue;
            }
        }
    }
    return value;
}

+ (int)intForKey:(NSString *)key
           inMOC:(NSManagedObjectContext *)context {
    return [self stringForKey:key inMOC:context].intValue;
}

+ (double)doubleForKey:(NSString *)key
                 inMOC:(NSManagedObjectContext *)context {
    return [self stringForKey:key inMOC:context].doubleValue;
}

+ (BOOL)boolForKey:(NSString *)key
             inMOC:(NSManagedObjectContext *)context {
    NSString *value = [self stringForKey:key inMOC:context];
    DDLogVerbose(@"boolForKey:%@ = %@", key, value);
    return value.boolValue;
}

+ (NSString *)theGeneralTopicInMOC:(NSManagedObjectContext *)context {
    NSString *topic = [self stringForKey:@"topic_preference" inMOC:context];
            
    if (!topic || [topic isEqualToString:@""]) {
        NSString *userId = [self theUserIdInMOC:context];
        NSString *deviceId = [self theDeviceIdInMOC:context];

        if (!userId || [userId isEqualToString:@""]) {
            userId = @"user";
        }
        if (!deviceId || [deviceId isEqualToString:@""]) {
            deviceId = @"device";
        }

        topic = [NSString stringWithFormat:@"owntracks/%@/%@", userId, deviceId];
    } else {
        topic = [topic stringByReplacingOccurrencesOfString:@"%u"
                                                 withString:[Settings theUserIdInMOC:context]];
        topic = [topic stringByReplacingOccurrencesOfString:@"%d"
                                                 withString:[Settings theDeviceIdInMOC:context]];
    }
    return topic;
}

+ (NSString *)theWillTopicInMOC:(NSManagedObjectContext *)context {
    // willTopic is not the same as theGeneralTopic
    return [Settings theGeneralTopicInMOC:context];
}

+ (NSInteger)theWillQosInMOC:(NSManagedObjectContext *)context {
    // willQos is now the same as pubQos
    return [Settings intForKey:@"qos_preference" inMOC:context];
}

+ (BOOL)theWillRetainFlagInMOC:(NSManagedObjectContext *)context {
    // willRetainFlag is now always false
    return FALSE;
}

+ (NSString *)theClientIdInMOC:(NSManagedObjectContext *)context {
    NSString *clientId;
    clientId = [self stringForKey:@"clientid_preference" inMOC:context];
    
    if (!clientId || [clientId isEqualToString:@""]) {
        clientId = [self theIdInMOC:context];
    }
    return clientId;
}

+ (NSString *)theIdInMOC:(NSManagedObjectContext *)context {
    NSString *theId;
    
    NSString *userId = [self theUserIdInMOC:context];
    NSString *deviceId = [self theDeviceIdInMOC:context];

    if (!userId || [userId isEqualToString:@""]) {
        if (!deviceId || [deviceId isEqualToString:@""]) {
            theId = [UIDevice currentDevice].name;
        } else {
            theId = deviceId;
        }
    } else {
        if (!deviceId || [deviceId isEqualToString:@""]) {
            theId = userId;
        } else {
            theId = [NSString stringWithFormat:@"%@%@",
                     userId,
                     deviceId];
        }
    }
    NSCharacterSet *allowed = [NSCharacterSet alphanumericCharacterSet];
    NSCharacterSet *notAllowed = allowed.invertedSet;
    theId = [[theId componentsSeparatedByCharactersInSet:notAllowed]
             componentsJoinedByString:@""];

    return theId;
}

+ (NSString *)theDeviceIdInMOC:(NSManagedObjectContext *)context {
    NSString *deviceId = [self stringForKey:@"deviceid_preference" inMOC:context];
    if (!deviceId || deviceId.length == 0) {
        deviceId = ([UIDevice currentDevice].identifierForVendor).UUIDString;
    }
    return deviceId;
}

+ (NSString *)theSubscriptionsInMOC:(NSManagedObjectContext *)context {
    NSString *subscriptions = [self stringForKey:@"subscription_preference" inMOC:context];

    if (!subscriptions || subscriptions.length == 0) {
        NSArray *baseComponents = [[self theGeneralTopicInMOC:context] componentsSeparatedByString:@"/"];

        NSString *anyDevice = @"";
        int any = 1;
        NSString *firstString = nil;
        if (baseComponents.count > 0) {
            firstString = baseComponents[0];
        }
        if (firstString && firstString.length == 0) {
            any++;
        }

        for (int i = 0; i < any; i++) {
            if (i > 0) {
                anyDevice = [anyDevice stringByAppendingString:@"/"];
            }
            anyDevice = [anyDevice stringByAppendingString:baseComponents[i]];
        }

        for (int i = any; i < baseComponents.count; i++) {
            if (i > 0) {
                anyDevice = [anyDevice stringByAppendingString:@"/"];
            }
            anyDevice = [anyDevice stringByAppendingString:@"+"];
        }

        subscriptions = [NSString stringWithFormat:@"%@,%@/event,%@/info,%@/cmd",
                         anyDevice,
                         anyDevice,
                         anyDevice,
                         [self theGeneralTopicInMOC:context]];
    }
    NSString *userId = [Settings theUserIdInMOC:context];
    if (userId) {
        subscriptions = [subscriptions stringByReplacingOccurrencesOfString:@"%u"
                                                                 withString:userId];
    }
    NSString *deviceId = [Settings theDeviceIdInMOC:context];
    if (deviceId) {
        subscriptions = [subscriptions stringByReplacingOccurrencesOfString:@"%d"
                                                                 withString:deviceId];
    }

    return subscriptions;
}

+ (NSString *)theUserIdInMOC:(NSManagedObjectContext *)context {
    return [self stringForKey:@"user_preference" inMOC:context];
}

+ (NSString *)theHostInMOC:(NSManagedObjectContext *)context {
    int mode = [self intForKey:@"mode" inMOC:context];
    switch (mode) {
        case CONNECTION_MODE_HTTP: {
            NSURL *url = [NSURL URLWithString:[self stringForKey:@"url_preference" inMOC:context]];
            NSString *host = url.host;
            return host ? host : @"host";
            break;
        }

        case CONNECTION_MODE_MQTT:
        default:
            return [self stringForKey:@"host_preference" inMOC:context];
            break;
    }
}

+ (NSString *)theMqttUserInMOC:(NSManagedObjectContext *)context {
    return [self stringForKey:@"user_preference" inMOC:context];
}

+ (NSString *)theMqttPassInMOC:(NSManagedObjectContext *)context {
    return [self stringForKey:@"pass_preference" inMOC:context];
}

+ (BOOL)theMqttUsePasswordInMOC:(NSManagedObjectContext *)context {
    return [self boolForKey:@"usepassword_preference" inMOC:context];
}

+ (BOOL)theLockedInMOC:(NSManagedObjectContext *)context {
    return [self boolForKey:@"locked" inMOC:context];
}

+ (BOOL)theMqttAuthInMOC:(NSManagedObjectContext *)context {
    return [self boolForKey:@"auth_preference" inMOC:context];
}

+ (int)theMaximumHistoryInMOC:(NSManagedObjectContext *)context {
    return [self intForKey:@"maxhistory_preference" inMOC:context];
}

+ (NSString *)theOSMTemplate:(NSManagedObjectContext *)context {
    return [self stringForKey:@"osmtemplate_preference" inMOC:context];
}
+ (void)setOSMTemplate:(NSString *)osmTemplate inMOC:(NSManagedObjectContext *)context {
    [self setString:osmTemplate
             forKey:@"osmtemplate_preference"
              inMOC:context];
}

+ (NSString *)theOSMCopyrightInMOC:(NSManagedObjectContext *)context {
    return [self stringForKey:@"osmcopyright_preference" inMOC:context];
}
+ (void)setOSMCopyright:(NSString *)osmCopyright inMOC:(NSManagedObjectContext *)context {
    [self setString:osmCopyright
             forKey:@"osmcopyright_preference"
              inMOC:context];
}

+ (BOOL)validIdsInMOC:(NSManagedObjectContext *)context {
    NSString *user = [self theUserIdInMOC:context];
    NSString *device = [self theDeviceIdInMOC:context];
    
    return (user && user.length != 0 && device && device.length != 0);
}

+ (NSError *)validationErrorForRemoteProvisionConfiguration:(NSDictionary *)payload
                                                     inMOC:(NSManagedObjectContext *)moc {
    static NSString * const kDomain = @"OTProvisionConfiguration";
    if (![payload isKindOfClass:[NSDictionary class]] || payload.count == 0) {
        return [NSError errorWithDomain:kDomain
                                   code:1
                               userInfo:@{NSLocalizedDescriptionKey: @"Provision payload empty or not a dictionary"}];
    }

    NSString *deviceId = OTTrimProvisioningString(payload[@"deviceId"]);
    if (deviceId.length == 0) {
        return [NSError errorWithDomain:kDomain
                                   code:2
                               userInfo:@{NSLocalizedDescriptionKey: @"Provisioning response missing deviceId"}];
    }
    if (OTSettingsDeviceIdOrClientIdStringIsSuspect(deviceId)) {
        NSString *pubBase = OTTrimProvisioningString(payload[@"pubTopicBase"]);
        NSString *subTopic = OTTrimProvisioningString(payload[@"subTopic"]);
        if (OTSettingsDeviceIdMatchesTopicPathTail(deviceId, pubBase) ||
            OTSettingsDeviceIdMatchesTopicPathTail(deviceId, subTopic)) {
            DDLogInfo(@"[Settings] provision validation — deviceId \"%@\" matches pubTopicBase/subTopic tail; accepting despite suspect heuristics",
                      deviceId);
        } else {
            return [NSError errorWithDomain:kDomain
                                       code:3
                                   userInfo:@{NSLocalizedDescriptionKey:
                                                  [NSString stringWithFormat:@"Provisioning deviceId is generic or suspect (%@)", deviceId]}];
        }
    }

    id modeObj = payload[@"mode"];
    NSInteger mode = NSNotFound;
    if ([modeObj isKindOfClass:[NSNumber class]]) {
        mode = [(NSNumber *)modeObj integerValue];
    } else if ([modeObj isKindOfClass:[NSString class]]) {
        mode = [(NSString *)modeObj integerValue];
    }

    if (mode == CONNECTION_MODE_MQTT) {
        NSString *user = OTTrimProvisioningString(payload[@"username"]);
        if (user.length == 0) {
            return [NSError errorWithDomain:kDomain
                                       code:6
                                   userInfo:@{NSLocalizedDescriptionKey: @"MQTT provisioning response missing username"}];
        }
        NSString *clientId = OTTrimProvisioningString(payload[@"clientId"]);
        if (clientId.length == 0) {
            return [NSError errorWithDomain:kDomain
                                       code:7
                                   userInfo:@{NSLocalizedDescriptionKey: @"MQTT provisioning response missing clientId"}];
        }
        if (OTSettingsDeviceIdOrClientIdStringIsSuspect(clientId)) {
            NSString *pubBase = OTTrimProvisioningString(payload[@"pubTopicBase"]);
            NSString *subTopic = OTTrimProvisioningString(payload[@"subTopic"]);
            NSString *didForClient = OTTrimProvisioningString(payload[@"deviceId"]);
            BOOL topicAlignedDevice =
                OTSettingsDeviceIdMatchesTopicPathTail(didForClient, pubBase) ||
                OTSettingsDeviceIdMatchesTopicPathTail(didForClient, subTopic);
            if (topicAlignedDevice && OTSettingsProvisionClientIdIsAlphanumericHyphenSlug(clientId)) {
                DDLogInfo(@"[Settings] provision validation — clientId \"%@\" is suspect heuristically but deviceId matches topic tail and clientId is a broker-style slug — accepting",
                          clientId);
            } else {
                return [NSError errorWithDomain:kDomain
                                           code:9
                                       userInfo:@{NSLocalizedDescriptionKey:
                                                          [NSString stringWithFormat:@"MQTT clientId is generic or suspect (%@)", clientId]}];
            }
        }
    }

    NSString *tid = OTTrimProvisioningString(payload[@"tid"]);
    if (tid.length > 0) {
        if (OTSettingsTokenEqualsForbiddenDeviceIdentity(tid) ||
            OTSettingsIdentityStringContainsGenericToken(tid)) {
            return [NSError errorWithDomain:kDomain
                                       code:10
                                   userInfo:@{NSLocalizedDescriptionKey:
                                                  [NSString stringWithFormat:@"Provisioning tid is generic or suspect (%@)", tid]}];
        }
        NSFetchRequest *req = [NSFetchRequest fetchRequestWithEntityName:@"Friend"];
        NSError *ferr = nil;
        NSArray *friends = [moc executeFetchRequest:req error:&ferr];
        if (ferr) {
            DDLogWarn(@"[Settings] validationErrorForRemoteProvisionConfiguration Friend fetch: %@", ferr);
        } else {
            NSInteger matchCount = 0;
            for (Friend *f in friends) {
                if ([f.effectiveTid isEqualToString:tid]) {
                    matchCount++;
                }
            }
            if (matchCount > 1) {
                return [NSError errorWithDomain:kDomain
                                           code:8
                                       userInfo:@{NSLocalizedDescriptionKey:
                                                      [NSString stringWithFormat:
                                                       @"Provisioning tid matches %ld friends (ambiguous)", (long)matchCount]}];
            }
        }
    }

    DDLogInfo(@"[Settings] provision configuration validation OK (deviceId length=%lu, mode=%ld)",
              (unsigned long)deviceId.length, (long)mode);
    return nil;
}

+ (instancetype)sharedInstance {
    static dispatch_once_t once = 0;
    static id sharedInstance = nil;
    dispatch_once(&once, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init {
    self = [super init];
    return self;
}

@end

