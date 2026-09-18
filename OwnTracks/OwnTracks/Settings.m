//
//  Settings.m
//  OwnTracks
//
//  Created by Christoph Krey on 31.01.14.
//  Copyright © 2014-2026  Christoph Krey. All rights reserved.
//

#import "Settings.h"
#import "CoreData.h"
#import "OwnTracking.h"
#import "LocationManager.h"
#import "OwnTracksLog.h"

@interface SettingsDefaults: NSObject
@property (strong, nonatomic) NSDictionary *mqttDefaults;
@property (strong, nonatomic) NSDictionary *httpDefaults;
@end

static SettingsDefaults *defaults;

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

+ (NSString *)theIntentAuthKey {
    NSString *intentAuthKey = [[NSUserDefaults standardUserDefaults] stringForKey:@"intentAuthKey"];
    if (intentAuthKey == nil) {
        intentAuthKey = [NSUUID UUID].UUIDString;
        [[NSUserDefaults standardUserDefaults] setObject:intentAuthKey forKey:@"intentAuthKey"];
    }
    return intentAuthKey;
}

+ (NSString *)changesFromDictionary:(NSDictionary *)dictionary
                             inMOC:(NSManagedObjectContext *)context {
    NSString *changes = @"";

    if (!dictionary && ![dictionary isKindOfClass:[NSDictionary class]]) {
        return NSLocalizedString(@"Invalid config dictionary", @"Invalid config dictionary");
    }

    NSString *type = dictionary[@"_type"];
    if (!type || ![type isKindOfClass:[NSString class]] || ![type isEqualToString:@"configuration"]) {
        return NSLocalizedString(@"Invalid config _type", @"Invalid config _type");
    }
                
    NSNumber *mode = dictionary[@"mode"];
    if (mode) {
        if ([mode isKindOfClass:[NSNumber class]] &&
            (mode.intValue == CONNECTION_MODE_MQTT ||
             mode.intValue == CONNECTION_MODE_HTTP)) {
            if ([Settings theModeInMOC:context] != mode.intValue) {
                changes = [changes stringByAppendingFormat:@"%@: %d\n",
                           NSLocalizedString(@"New mode", @"New mode"),
                           mode.intValue];
            }
        } else {
            return NSLocalizedString(@"Invalid config mode", @"Invalid config mode");
        }
    }

    NSObject *object;
    
    object = dictionary[@"host"];
    if (object && ![[self stringForKey:@"host_preference" inMOC:context] isEqualToString:object.description]) {
        changes = [changes stringByAppendingFormat:@"%@: %@\n",
                   NSLocalizedString(@"New host", @"New host"),
                   object];
    }

    object = dictionary[@"port"];
    if (object && ![[self stringForKey:@"port_preference" inMOC:context] isEqualToString:object.description]) {
        changes = [changes stringByAppendingFormat:@"%@: %@\n",
                   NSLocalizedString(@"New port", @"New port"),
                   object];
    }

    object = dictionary[@"url"];
    if (object && ![[self stringForKey:@"url_preference" inMOC:context] isEqualToString:object.description]) {
        changes = [changes stringByAppendingFormat:@"%@: %@\n",
                   NSLocalizedString(@"New url", @"New url"),
                   object];
    }

    object = dictionary[@"monitoring"];
    if (object && ![[self stringForKey:@"monitoring_preference" inMOC:context] isEqualToString:object.description]) {
        changes = [changes stringByAppendingFormat:@"%@: %@\n",
                   NSLocalizedString(@"New monitoring", @"New monitoring"),
                   object];
    }

    object = dictionary[@"cmd"];
    if (object && ![[self stringForKey:@"cmd_preference" inMOC:context] isEqualToString:object.description]) {
        changes = [changes stringByAppendingFormat:@"%@: %@\n",
                   NSLocalizedString(@"New cmd", @"New cmd"),
                   object];
    }

    object = dictionary[@"allowRemoteLocation"];
    if (object && ![[self stringForKey:@"allowremotelocation_preference" inMOC:context] isEqualToString:object.description]) {
        changes = [changes stringByAppendingFormat:@"%@: %@\n",
                   NSLocalizedString(@"New allowRemoteLocation", @"New allowRemoteLocation"),
                   object];
    }

    object = dictionary[@"remoteConfiguration"];
    if (object && ![[self stringForKey:@"allowremoteconfiguration_preference" inMOC:context] isEqualToString:object.description]) {
        changes = [changes stringByAppendingFormat:@"%@: %@\n",
                   NSLocalizedString(@"New remoteConfiguration", @"New remoteConfiguration"),
                   object];
    }

    object = dictionary[@"tls"];
    if (object && ![[self stringForKey:@"tls_preference" inMOC:context] isEqualToString:object.description]) {
        changes = [changes stringByAppendingFormat:@"%@: %@\n",
                   NSLocalizedString(@"New tls", @"New tls"),
                   object];
    }

    object = dictionary[@"allowinvalidcerts"];
    if (object && ![[self stringForKey:@"allowinvalidcerts" inMOC:context] isEqualToString:object.description]) {
        changes = [changes stringByAppendingFormat:@"%@: %@\n",
                   NSLocalizedString(@"New allowinvalidcerts", @"New allowinvalidcerts"),
                   object];
    }

    object = dictionary[@"locked"];
    if (object && ![[self stringForKey:@"locked" inMOC:context] isEqualToString:object.description]) {
        changes = [changes stringByAppendingFormat:@"%@: %@\n",
                   NSLocalizedString(@"New locked", @"New locked"),
                   object];
    }

    object = dictionary[@"deviceId"];
    if (object && ![[Settings stringForKey:@"deviceid_preference"inMOC:context] isEqualToString:object.description]) {
        changes = [changes stringByAppendingFormat:@"%@: %@\n",
                   NSLocalizedString(@"New device id", @"New device id"),
                   object];
    }
    
    object = dictionary[@"tid"];
    if (object && ![[self stringForKey:@"trackerid_preference" inMOC:context] isEqualToString:object.description]) {
        changes = [changes stringByAppendingFormat:@"%@: %@\n",
                   NSLocalizedString(@"New tid", @"New tid"),
                   object];
    }
    
    object = dictionary[@"clientId"];
    if (object && ![[self stringForKey:@"clientid_preference" inMOC:context] isEqualToString:object.description]) {
        changes = [changes stringByAppendingFormat:@"%@: %@\n",
                   NSLocalizedString(@"New clientid", @"New clientid"),
                   object];
    }

    object = dictionary[@"subTopic"];
    if (object && ![[self stringForKey:@"subscription_preference" inMOC:context] isEqualToString:object.description]) {
        changes = [changes stringByAppendingFormat:@"%@: %@\n",
                   NSLocalizedString(@"New subTopic", @"New subTopic"),
                   object];
    }

    object = dictionary[@"pubTopicBase"];
    if (object && ![[self stringForKey:@"topic_preference" inMOC:context] isEqualToString:object.description]) {
        changes = [changes stringByAppendingFormat:@"%@: %@\n",
                   NSLocalizedString(@"New pubTopicBase", @"New pubTopicBase"),
                   object];
    }

    object = dictionary[@"httpHeaders"];
    if (object && ![[self stringForKey:@"httpheaders_preference" inMOC:context] isEqualToString:object.description]) {
        changes = [changes stringByAppendingFormat:@"%@: %@\n",
                   NSLocalizedString(@"New httpHeaders", @"New httpHeaders"),
                   object];
    }

    object = dictionary[@"encryptionKey"];
    if (object && ![[self stringForKey:@"secret_preference" inMOC:context] isEqualToString:object.description]) {
        changes = [changes stringByAppendingFormat:@"%@: %@\n",
                   NSLocalizedString(@"New encryptionKey", @"New encryptionKey"),
                   object];
    }

    object = dictionary[@"osmTemplate"];
    if (object && ![[self stringForKey:@"osmtemplate_preference" inMOC:context] isEqualToString:object.description]) {
        changes = [changes stringByAppendingFormat:@"%@: %@\n",
                   NSLocalizedString(@"New osmTemplate", @"New osmTemplate"),
                   object];
    }

    object = dictionary[@"osmCopyright"];
    if (object && ![[self stringForKey:@"osmcopyright_preference" inMOC:context] isEqualToString:object.description]) {
        changes = [changes stringByAppendingFormat:@"%@: %@\n",
                   NSLocalizedString(@"New osmCopyright", @"New osmCopyright"),
                   object];
    }

    object = dictionary[@"username"];
    if (object && ![[self stringForKey:@"user_preference" inMOC:context] isEqualToString:object.description]) {
        changes = [changes stringByAppendingFormat:@"%@: %@\n",
                   NSLocalizedString(@"New username", @"New username"),
                   object];
    }

    object = dictionary[@"password"];
    if (object && ![[self stringForKey:@"pass_preference" inMOC:context] isEqualToString:object.description]) {
        changes = [changes stringByAppendingFormat:@"%@: %@\n",
                   NSLocalizedString(@"New password", @"New password"),
                   object];
    }

    object = dictionary[@"subQos"];
    if (object && ![[self stringForKey:@"subscriptionqos_preference" inMOC:context] isEqualToString:object.description]) {
        changes = [changes stringByAppendingFormat:@"%@: %@\n",
                   NSLocalizedString(@"New subQos", @"New subQos"),
                   object];
    }

    object = dictionary[@"pubQos"];
    if (object && ![[self stringForKey:@"qos_preference" inMOC:context] isEqualToString:object.description]) {
        changes = [changes stringByAppendingFormat:@"%@: %@\n",
                   NSLocalizedString(@"New pubQos", @"New pubQos"),
                   object];
    }

    object = dictionary[@"mqttProtocolLevel"];
    if (object && ![[self stringForKey:@"mqttProtocolLevel" inMOC:context] isEqualToString:object.description]) {
        changes = [changes stringByAppendingFormat:@"%@: %@\n",
                   NSLocalizedString(@"New mqttProtocolLevel", @"New mqttProtocolLevel"),
                   object];
    }

    object = dictionary[@"ignoreStaleLocations"];
    if (object && ![[self stringForKey:@"ignorestalelocations_preference" inMOC:context] isEqualToString:object.description]) {
        changes = [changes stringByAppendingFormat:@"%@: %@\n",
                   NSLocalizedString(@"New ignoreStaleLocations", @"New ignoreStaleLocations"),
                   object];
    }

    object = dictionary[@"ignoreInaccurateLocations"];
    if (object && ![[self stringForKey:@"ignoreinaccuratelocations_preference" inMOC:context] isEqualToString:object.description]) {
        changes = [changes stringByAppendingFormat:@"%@: %@\n",
                   NSLocalizedString(@"New ignoreInaccurateLocations", @"New ignoreInaccurateLocations"),
                   object];
    }

    object = dictionary[@"keepalive"];
    if (object && ![[self stringForKey:@"keepalive_preference" inMOC:context] isEqualToString:object.description]) {
        changes = [changes stringByAppendingFormat:@"%@: %@\n",
                   NSLocalizedString(@"New keepalive", @"New keepalive"),
                   object];
    }

    object = dictionary[@"locatorDisplacement"];
    if (object && ![[self stringForKey:@"mindist_preference" inMOC:context] isEqualToString:object.description]) {
        changes = [changes stringByAppendingFormat:@"%@: %@\n",
                   NSLocalizedString(@"New locatorDisplacement", @"New locatorDisplacement"),
                   object];
    }

    object = dictionary[@"locatorInterval"];
    if (object && ![[self stringForKey:@"mintime_preference" inMOC:context] isEqualToString:object.description]) {
        changes = [changes stringByAppendingFormat:@"%@: %@\n",
                   NSLocalizedString(@"New locatorInterval", @"New locatorInterval"),
                   object];
    }

    object = dictionary[@"downgrade"];
    if (object && ![[self stringForKey:@"downgrade_preference" inMOC:context] isEqualToString:object.description]) {
        changes = [changes stringByAppendingFormat:@"%@: %@\n",
                   NSLocalizedString(@"New downgrade", @"New downgrade"),
                   object];
    }

    object = dictionary[@"adapt"];
    if (object && ![[self stringForKey:@"adapt_preference" inMOC:context] isEqualToString:object.description]) {
        changes = [changes stringByAppendingFormat:@"%@: %@\n",
                   NSLocalizedString(@"New adapt", @"New adapt"),
                   object];
    }

    object = dictionary[@"ranging"];
    if (object && ![[self stringForKey:@"ranging_preference" inMOC:context] isEqualToString:object.description]) {
        changes = [changes stringByAppendingFormat:@"%@: %@\n",
                   NSLocalizedString(@"New ranging", @"New ranging"),
                   object];
    }

    object = dictionary[@"sub"];
    if (object && ![[self stringForKey:@"sub_preference" inMOC:context] isEqualToString:object.description]) {
        changes = [changes stringByAppendingFormat:@"%@: %@\n",
                   NSLocalizedString(@"New sub", @"New sub"),
                   object];
    }

    object = dictionary[@"pubRetain"];
    if (object && ![[self stringForKey:@"retain_preference" inMOC:context] isEqualToString:object.description]) {
        changes = [changes stringByAppendingFormat:@"%@: %@\n",
                   NSLocalizedString(@"New pubRetain", @"New pubRetain"),
                   object];
    }

    object = dictionary[@"ws"];
    if (object && ![[self stringForKey:@"ws_preference" inMOC:context] isEqualToString:object.description]) {
        changes = [changes stringByAppendingFormat:@"%@: %@\n",
                   NSLocalizedString(@"New ws", @"New ws"),
                   object];
    }

    object = dictionary[@"auth"];
    if (object && ![[self stringForKey:@"auth_preference" inMOC:context] isEqualToString:object.description]) {
        changes = [changes stringByAppendingFormat:@"%@: %@\n",
                   NSLocalizedString(@"New auth", @"New auth"),
                   object];
    }

    object = dictionary[@"usePassword"];
    if (object && ![[self stringForKey:@"usepassword_preference" inMOC:context] isEqualToString:object.description]) {
        changes = [changes stringByAppendingFormat:@"%@: %@\n",
                   NSLocalizedString(@"New usePassword", @"New usePassword"),
                   object];
    }

    object = dictionary[@"cleanSession"];
    if (object && ![[self stringForKey:@"clean_preference" inMOC:context] isEqualToString:object.description]) {
        changes = [changes stringByAppendingFormat:@"%@: %@\n",
                   NSLocalizedString(@"New cleanSession", @"New cleanSession"),
                   object];
    }

    object = dictionary[@"positions"];
    if (object && ![[self stringForKey:@"positions_preference" inMOC:context] isEqualToString:object.description]) {
        changes = [changes stringByAppendingFormat:@"%@: %@\n",
                   NSLocalizedString(@"New positions", @"New positions"),
                   object];
    }

    object = dictionary[@"days"];
    if (object && ![[self stringForKey:@"days_preference" inMOC:context] isEqualToString:object.description]) {
        changes = [changes stringByAppendingFormat:@"%@: %@\n",
                   NSLocalizedString(@"New days", @"New days"),
                   object];
    }

    object = dictionary[@"maxHistory"];
    if (object && ![[self stringForKey:@"maxhistory_preference" inMOC:context] isEqualToString:object.description]) {
        changes = [changes stringByAppendingFormat:@"%@: %@\n",
                   NSLocalizedString(@"New maxHistory", @"New maxHistory"),
                   object];
    }

    object = dictionary[@"extendedData"];
    if (object && ![[self stringForKey:@"extendeddata_preference" inMOC:context] isEqualToString:object.description]) {
        changes = [changes stringByAppendingFormat:@"%@: %@\n",
                   NSLocalizedString(@"New extendedData", @"New extendedData"),
                   object];
    }

    object = dictionary[@"clientpkcs"];
    if (object && ![[self stringForKey:@"clientpkcs" inMOC:context] isEqualToString:object.description]) {
        changes = [changes stringByAppendingFormat:@"%@: %@\n",
                   NSLocalizedString(@"New clientpkcs", @"New clientpkcs"),
                   object];
    }

    object = dictionary[@"passphrase"];
    if (object && ![[self stringForKey:@"passphrase" inMOC:context] isEqualToString:object.description]) {
        changes = [changes stringByAppendingFormat:@"%@: %@\n",
                   NSLocalizedString(@"New passphrase", @"New passphrase"),
                   object];
    }

    NSArray *waypoints = dictionary[@"waypoints"];
    if (waypoints) {
        if ([waypoints isKindOfClass:[NSArray class]]) {
            changes = [changes stringByAppendingFormat:@"%@", [Settings changesSetWaypoints:waypoints inMOC:context]];
        } else {
            changes = [changes stringByAppendingFormat:@"waypoints are not an array"];
        }
    }
    
    return changes;
}

+ (NSError *)fromDictionary:(NSDictionary *)dictionary
                      inMOC:(NSManagedObjectContext *)context {
    if (!dictionary && ![dictionary isKindOfClass:[NSDictionary class]]) {
        OwnTracksLogError("[Settings] fromDictionary invalid dictionary");
        return [NSError errorWithDomain:@"OwnTracks Settings"
                                   code:2
                               userInfo:@{}];
    }
        
    NSString *type = dictionary[@"_type"];
    if (!type || ![type isKindOfClass:[NSString class]] || ![type isEqualToString:@"configuration"]) {
        OwnTracksLogError("[Settings] fromDictionary invalid _type");
        return [NSError errorWithDomain:@"OwnTracks Settings"
                                   code:1
                               userInfo:@{@"_type": [NSString stringWithFormat:@"%@", dictionary[@"_type"]]}];
    }
                
    NSObject *object;
    
    NSNumber *mode = dictionary[@"mode"];
    if (mode) {
        if ([mode isKindOfClass:[NSNumber class]] &&
            (mode.intValue == CONNECTION_MODE_MQTT ||
             mode.intValue == CONNECTION_MODE_HTTP)) {
            [self setInt:mode.intValue forKey:@"mode" inMOC:context];
        } else {
            OwnTracksLogError("[Settings] fromDictionary invalid mode");
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
    
    object = dictionary[@"subQos"];
    if (object) [self setString:object forKey:@"subscriptionqos_preference" inMOC:context];
    
    object = dictionary[@"pubQos"];
    if (object) [self setString:object forKey:@"qos_preference" inMOC:context];
    
    object = dictionary[@"port"];
    if (object) [self setString:object forKey:@"port_preference" inMOC:context];
    
    object = dictionary[@"mqttProtocolLevel"];
    if (object) [self setString:object forKey:@"mqttProtocolLevel" inMOC:context];
    
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
    
    object = dictionary[@"remoteConfiguration"];
    if (object) [self setString:object forKey:@"allowremoteconfiguration_preference" inMOC:context];
        
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
    if (waypoints) {
        if ([waypoints isKindOfClass:[NSArray class]]) {
            [self setWaypoints:waypoints inMOC:context];
        } else {
            OwnTracksLogError("[Settings] fromDictionary invalid waypoints");
            return [NSError errorWithDomain:@"OwnTracks Settings"
                                       code:4
                                   userInfo:@{@"waypoints": @"not an array"}];
        }
    }
            
    return nil;
}

+ (NSString *)changesWaypointsFromDictionary:(NSDictionary *)dictionary
                                       inMOC:(NSManagedObjectContext *)context {
    NSString *changes = @"";
    
    if (!dictionary && ![dictionary isKindOfClass:[NSDictionary class]]) {
        return NSLocalizedString(@"Invalid config dictionary", @"Invalid config dictionary");
    }
    
    NSString *type = dictionary[@"_type"];
    if (!type || ![type isKindOfClass:[NSString class]] || ![type isEqualToString:@"waypoints"]) {
        return NSLocalizedString(@"Invalid config _type", @"Invalid config _type");
    }
    
    NSArray *waypoints = dictionary[@"waypoints"];
    if (!waypoints || ![waypoints isKindOfClass:[NSArray class]]) {
        return NSLocalizedString(@"Invalid waypoints array", @"Invalid waypoints array");;
    }
    
    changes = [Settings changesSetWaypoints:waypoints inMOC:context];
    return changes;
}

+ (NSError *)waypointsFromDictionary:(NSDictionary *)dictionary
                               inMOC:(NSManagedObjectContext *)context {
    if (dictionary && [dictionary isKindOfClass:[NSDictionary class]]) {
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

+ (NSString *)changesSetWaypoints:(NSArray *)waypoints
                            inMOC:(NSManagedObjectContext *)context {
    return [Settings changesSetWaypoints:waypoints andDoChange:FALSE inMOC:context];
}

+ (NSString *)changesSetWaypoints:(NSArray *)waypoints
                      andDoChange:(BOOL)doChange
                            inMOC:(NSManagedObjectContext *)context {
    NSString *changes = @"";

    for (NSDictionary *waypoint in waypoints) {
        BOOL equal = TRUE;
        BOOL remove = FALSE;
        
        if (![waypoint isKindOfClass:[NSDictionary class]]) {
            changes = [changes stringByAppendingFormat:@"waypoints array does not contain dictionary\n"];
            OwnTracksLogError("[Settings][setWaypoints] waypoints array does contain non dictionary");
            continue;
        }
        
        NSString *type = waypoint[@"_type"];
        if (!type || ![type isKindOfClass:[NSString class]] || ![type isEqualToString:@"waypoint"]) {
            changes = [changes stringByAppendingFormat:@"waypoint does not contain _type waypoint\n"];
            OwnTracksLogError("[Settings][setWaypoints] waypoint does not contain _type waypoint");
            continue;
        }
        
        NSString *desc = waypoint[@"desc"];
        if (!desc || ![desc isKindOfClass:[NSString class]]) {
            changes = [changes stringByAppendingFormat:@"waypoint does not contain valid desc\n"];
            OwnTracksLogError("[Settings][setWaypoints] waypoint does not contain valid desc");
            continue;
        }
        
        NSArray *components = [desc componentsSeparatedByString:@":"];
        NSString *name = components[0];
        NSString *uuid = components.count >= 2 ? components[1] : @"";
        unsigned int major = components.count >= 3 ? [components[2] unsignedIntValue]: 0;
        unsigned int minor = components.count >= 4 ? [components[3] unsignedIntValue]: 0;

        NSNumber *tstNumber = waypoint[@"tst"];
        if (!tstNumber || ![tstNumber isKindOfClass:[NSNumber class]]) {
            changes = [changes stringByAppendingFormat:@"waypoint does not contain valid tst\n"];
            OwnTracksLogError("[Settings][setWaypoints] waypoint does not contain valid tst");
            continue;
        }
        
        NSDate *tst = [NSDate dateWithTimeIntervalSince1970:
                       [tstNumber doubleValue]];
                        
        NSString *rid = waypoint[@"rid"];
        if (!rid || ![rid isKindOfClass:[NSString class]]) {
            rid = [Region ridFromTst:tst andName:name];
        }
                                
        CLLocationDegrees latDegrees = 0.0;
        NSNumber *lat = waypoint[@"lat"];
        if (lat && ![lat isKindOfClass:[NSNumber class]]) {
            OwnTracksLogError("[Settings][setWaypoints] json does not contain valid lat: not processed");
            continue;
        }
        latDegrees = lat.doubleValue;

        CLLocationDegrees lonDegrees = 0.0;
        NSNumber *lon = waypoint[@"lon"];
        if (lon && ![lon isKindOfClass:[NSNumber class]]) {
            OwnTracksLogError("[Settings][setWaypoints] json does not contain valid lon: not processed");
            continue;
        }
        lonDegrees = lon.doubleValue;

        CLLocationDistance radDistance = 0.0;
        NSNumber *rad = waypoint[@"rad"];
        if (rad && ![rad isKindOfClass:[NSNumber class]]) {
            OwnTracksLogError("[Settings][setWaypoints] json does not contain valid rad: not processed");
            continue;
        }
        radDistance = rad.doubleValue;

        CLLocationCoordinate2D coord = CLLocationCoordinate2DMake(latDegrees, lonDegrees);
        if (!CLLocationCoordinate2DIsValid(coord)) {
            remove = TRUE;
            OwnTracksLogError("[Settings][setWaypoints] coord is no valid: not processed");
        }

        Friend *friend = [Friend friendWithTopic:[self theGeneralTopicInMOC:context]
                          inManagedObjectContext:context];
                    
        Region *foundRegion = nil;
        for (Region *region in friend.hasRegions) {
            if ([region.getAndFillRid isEqualToString:rid]) {
                foundRegion = region;
                if (![name isEqualToString:region.name]) {
                    equal = FALSE;
                }
                
                NSString *regionUUID = region.uuid != nil ? region.uuid : @"";
                if (![uuid isEqualToString:regionUUID]) {
                    equal = FALSE;
                }
                if (major != region.major.unsignedIntValue) {
                    equal = FALSE;
                }
                if (minor != region.minor.unsignedIntValue) {
                    equal = FALSE;
                }
                CLRegion *clRegion = region.CLregion;
                if (!clRegion || !clRegion.isFollow) {
                    if (latDegrees != region.lat.doubleValue) {
                        equal = FALSE;
                    }
                    if (lonDegrees != region.lon.doubleValue) {
                        equal = FALSE;
                    }
                    if (radDistance != region.radius.doubleValue) {
                        equal = FALSE;
                    }
                }
                break;
            }
        }

        if (foundRegion) {
            if (remove) {
                changes = [changes stringByAppendingFormat:@"Region %@ will be removed\n", name];
                if (doChange) {
                    [[OwnTracking sharedInstance] removeRegion:foundRegion context:context];
                }
            } else {
                if (!equal) {
                    changes = [changes stringByAppendingFormat:@"Region %@ will be updated\n", name];
                    if (doChange) {
                        [[OwnTracking sharedInstance] removeRegion:foundRegion context:context];
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
            }
        } else {
            changes = [changes stringByAppendingFormat:@"Region %@ will be inserted\n", name];
            if (doChange) {
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
    }

    return changes;
}

+ (void)setWaypoints:(NSArray *)waypoints
               inMOC:(NSManagedObjectContext *)context {
    if (!waypoints || ![waypoints isKindOfClass:[NSArray class]]) {
        OwnTracksLogError("[Settings][setWaypoints] invalid waypoints array");
        return;
    }

    (void)[Settings changesSetWaypoints:waypoints andDoChange:TRUE inMOC:context];
}

+ (NSError *)clearWaypoints:(NSManagedObjectContext *)context {
    Friend *friend = [Friend friendWithTopic:[self theGeneralTopicInMOC:context]
                            inManagedObjectContext:context];

    while (friend.hasRegions.count) {
        Region *region = friend.hasRegions.anyObject;
        OwnTracksLogDefault("[Settings][clearWaypoints] removeRegion %@", region.rid);
        [[OwnTracking sharedInstance] removeRegion:region context:context];
    }
    OwnTracksLogDefault("[Settings][clearWaypoints] clearWaypoints");
    return nil;
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
    dict[@"remoteConfiguration"] =  @([Settings boolForKey:@"allowremoteconfiguration_preference" inMOC:context]);
    dict[@"auth"] =                 @([Settings boolForKey:@"auth_preference" inMOC:context]);
    dict[@"usePassword"] =          @([Settings boolForKey:@"usepassword_preference" inMOC:context]);
    dict[@"encryptionKey"] =        [Settings stringOrZeroForKey:@"secret_preference" inMOC:context];
    dict[@"osmTemplate"] =          [Settings theOSMTemplate:context];
    dict[@"osmCopyright"] =         [Settings theOSMCopyrightInMOC:context];
    dict[@"username"] =             [Settings stringOrZeroForKey:@"user_preference" inMOC:context];
    dict[@"password"] =             [Settings stringOrZeroForKey:@"pass_preference" inMOC:context];

    switch ([Settings intForKey:@"mode" inMOC:context]) {
        case CONNECTION_MODE_MQTT:
            dict[@"clientId"] =             [Settings stringOrZeroForKey:@"clientid_preference" inMOC:context];
            dict[@"sub"] =                  @([Settings boolForKey:@"sub_preference" inMOC:context]);
            dict[@"subTopic"] =             [Settings stringOrZeroForKey:@"subscription_preference" inMOC:context];
            dict[@"host"] =                 [Settings stringOrZeroForKey:@"host_preference" inMOC:context];
            dict[@"clientpkcs"] =           [Settings stringOrZeroForKey:@"clientpkcs" inMOC:context];
            dict[@"passphrase"] =           [Settings stringOrZeroForKey:@"passphrase" inMOC:context];
            
            dict[@"subQos"] =               @([Settings intForKey:@"subscriptionqos_preference" inMOC:context]);
            dict[@"pubQos"] =               @([Settings theQosInMOC:context]);
            dict[@"port"] =                 @([Settings intForKey:@"port_preference" inMOC:context]);
            dict[@"mqttProtocolLevel"] =    @([Settings intForKey:@"mqttProtocolLevel" inMOC:context]);
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
                                                     options:NSJSONWritingPrettyPrinted | NSJSONWritingSortedKeys
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
    OwnTracksLogDebug("setBoolForKey:%@ = %d", key, b);
    [self setString:[NSString stringWithFormat:@"%d", b] forKey:key inMOC:context];
}

+ (NSString *)stringOrZeroForKey:(NSString *)key
                           inMOC:(NSManagedObjectContext *)context {
    NSString *value = [self stringForKey:key inMOC:context];
    if (!value) {
        OwnTracksLogDebug("stringOrZeroForKey %@", key);
        value = @"";
    }
    return value;
}

+ (NSString *)stringForKey:(NSString *)key
                     inMOC:(NSManagedObjectContext *)context {
    return [Settings stringForKeyRaw:key inMOC:context];
}

+ (NSString *)stringForKeyRaw:(NSString *)key
                        inMOC:(NSManagedObjectContext *)context {
    __block NSString *value = nil;
        Setting *setting = [Setting existsSettingWithKey:key inMOC:context];
        if (setting) {
            value = setting.value;
        } else {
            id object = ([SettingsDefaults theDefaults].mqttDefaults)[key];
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
    OwnTracksLogDebug("boolForKey:%@ = %@", key, value);
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
    // willTopic is now the same as theGeneralTopic
    return [Settings theGeneralTopicInMOC:context];
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

        subscriptions = [NSString stringWithFormat:@"%@ %@/event %@/info %@/cmd",
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

+ (BOOL)theAllowRemoteLocationInMOC:(NSManagedObjectContext *)context {
    return [self boolForKey:@"allowremotelocation_preference" inMOC:context];
}

+ (BOOL)theAllowRemoteConfigurationInMOC:(NSManagedObjectContext *)context {
    return [self boolForKey:@"allowremoteconfiguration_preference" inMOC:context];
}

+ (BOOL)theallowConfigurationByURIAndConfigFileInMOC:(NSManagedObjectContext *)context {
    return [self boolForKey:@"allowConfigurationByURIAndConfigFile" inMOC:context];
}

+ (BOOL)theAllowIntentControlInMOC:(NSManagedObjectContext *)context {
    return [self boolForKey:@"allowIntentControl" inMOC:context];
}

+ (BOOL)theMqttAuthInMOC:(NSManagedObjectContext *)context {
    return [self boolForKey:@"auth_preference" inMOC:context];
}

+ (int)theMaximumHistoryInMOC:(NSManagedObjectContext *)context {
    return [self intForKey:@"maxhistory_preference" inMOC:context];
}

+ (double)theDefaultRegionRadiusInMOC:(NSManagedObjectContext *)context {
    double value = [self doubleForKey:@"regionradius_preference" inMOC:context];
    return value > 0 ? value : 50.0;
}

+ (ConnectionMode)theModeInMOC:(NSManagedObjectContext *)context {
    return [self intForKey:@"mode" inMOC:context];
}

+ (void)setMode:(ConnectionMode)mode inMOC:(NSManagedObjectContext *)context {
    [self setInt:mode forKey:@"mode" inMOC:context];
    OwnTracksLogDebug("[Settings] (connection)mode set to %d", mode);
}

// QosLevel
+ (MQTTQosLevel)theQosInMOC:(NSManagedObjectContext *)context {
    MQTTQosLevel qos = [self intForKey:@"qos_preference" inMOC:context];
    return qos;
}

+ (void)setQos:(MQTTQosLevel)qos inMOC:(NSManagedObjectContext *)context {
    [self setInt:qos forKey:@"qos_preference" inMOC:context];
}

+ (MQTTQosLevel)theWillQosInMOC:(NSManagedObjectContext *)context {
    // willQos is now the same as pubQos
    return [Settings theQosInMOC:context];
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

