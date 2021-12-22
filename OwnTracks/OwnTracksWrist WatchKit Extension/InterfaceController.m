//
//  InterfaceController.m
//  OwnTracksWrist WatchKit Extension
//
//  Created by Christoph Krey on 01.04.20.
//  Copyright © 2020 OwnTracks. All rights reserved.
//

#import "InterfaceController.h"
#import "SettingsInterfaceController.h"
#import <MQTTLog.h>

@interface InterfaceController ()
@property (weak, nonatomic) IBOutlet WKInterfaceTextField *accuracy;
@property (weak, nonatomic) IBOutlet WKInterfaceSwitch *track;
@property (weak, nonatomic) IBOutlet WKInterfaceTextField *connection;

@property (strong, nonatomic) CLLocationManager *locationManager;
@property (strong, nonatomic) NSURLSession *urlSession;
@property (strong, nonatomic) MQTTSession *mqttSession;

@end

@implementation InterfaceController

- (NSString *)authorizationStatus:(CLAuthorizationStatus)authorizationStatus {
    switch (authorizationStatus) {
        case kCLAuthorizationStatusNotDetermined:
            return @"kCLAuthorizationStatusNotDetermined The user has not chosen whether the app can use location services.";
        case kCLAuthorizationStatusRestricted:
            return @"The app is not authorized to use location services.";
        case kCLAuthorizationStatusDenied:
            return @"kCLAuthorizationStatusDenied The user denied the use of location services for the app or they are disabled globally in Settings.";
        case kCLAuthorizationStatusAuthorizedAlways:
            return @"kCLAuthorizationStatusAuthorizedAlways The user authorized the app to start location services at any time.";
        case kCLAuthorizationStatusAuthorizedWhenInUse:
            return @"kCLAuthorizationStatusAuthorizedWhenInUse The user authorized the app to start location services while it is in use.";
        default:
            return @"unknown";
    }
}

- (void)awakeWithContext:(id)context {
    [super awakeWithContext:context];

    [[NSUserDefaults standardUserDefaults] registerDefaults:@{
        @"url": @"mqtt://user@test.mosquitto.org:1883"
    }];

    [[WKInterfaceDevice currentDevice] setBatteryMonitoringEnabled:TRUE];

    self.locationManager = [[CLLocationManager alloc] init];
    self.locationManager.delegate = self;

    [MQTTLog setLogLevel:DDLogLevelWarning];
    self.mqttSession = [[MQTTSession alloc] init];
    self.mqttSession.delegate = self;

    self.urlSession = NSURLSession.sharedSession;

    NSLog(@"CLLocationManager authorizationStatus %d %@",
          CLLocationManager.authorizationStatus,
          [self authorizationStatus:CLLocationManager.authorizationStatus]);
    [self locationManager:self.locationManager
didChangeAuthorizationStatus:CLLocationManager.authorizationStatus];

    if (CLLocationManager.authorizationStatus == kCLAuthorizationStatusNotDetermined) {
        [self.locationManager requestAlwaysAuthorization];
    }
    // Configure interface objects here.

}

- (void)willActivate {
    NSLog(@"willActivate");
    [super willActivate];
}

- (void)didDeactivate {
    NSLog(@"didDeactivate");
    [super didDeactivate];
}

- (void)locationManager:(CLLocationManager *)manager
       didFailWithError:(NSError *)error {
    NSLog(@"locationManager didFailWithError %@", error);
}

- (void)locationManager:(CLLocationManager *)manager
       didUpdateHeading:(CLHeading *)newHeading {
    NSLog(@"locationManager didUpdateHeading %@", newHeading);
}

- (void)locationManager:(CLLocationManager *)manager
     didUpdateLocations:(NSArray<CLLocation *> *)locations {
    NSLog(@"locationManager didUpdateLocations %@", locations);
    for (CLLocation *l in locations) {
        if (l.horizontalAccuracy >= 0) {
            NSISO8601DateFormatter *df = [[NSISO8601DateFormatter alloc] init];
            df.formatOptions = NSISO8601DateFormatWithFullTime;

            [self.accuracy setText:[NSString stringWithFormat:@"%@ %@",
                                    [NSString stringWithFormat:@"±%.0fm",
                                     l.horizontalAccuracy],
                                    [df stringFromDate:l.timestamp]
                                    ]
             ];

            NSMutableDictionary *md = [[NSMutableDictionary alloc] init];
            md[@"_type"] = @"location";
            md[@"tid"] = [self effectiveTid];
            md[@"tst"] = @((int)round(l.timestamp.timeIntervalSince1970));
            if ((int)round(l.timestamp.timeIntervalSince1970) !=
                (int)round([NSDate date].timeIntervalSince1970)) {
                [md setValue:@((int)round([NSDate date].timeIntervalSince1970))
                        forKey:@"created_at"];
            }

            md[@"lat"] = @(l.coordinate.latitude);
            md[@"lon"] = @(l.coordinate.longitude);
            md[@"acc"] = @((int)l.horizontalAccuracy);
            if (l.speed >= 0) {
                md[@"vel"] = @((int)(l.speed * 3600.0 / 1000.0));
            }
            if (l.course >= 0) {
                md[@"cog"] = @((int)l.course);
            }
            if (l.verticalAccuracy >= 0) {
                md[@"alt"] = @((int)l.altitude);
                md[@"vac"] = @((int)l.verticalAccuracy);
            }

            float batteryLevel = [WKInterfaceDevice currentDevice].batteryLevel;
            if (batteryLevel != -1) {
                int batteryLevelInt = batteryLevel * 100;
                [md setValue:@(batteryLevelInt) forKey:@"batt"];
            }

            WKInterfaceDeviceBatteryState batteryState = [WKInterfaceDevice currentDevice].batteryState;
            if (batteryState != WKInterfaceDeviceBatteryStateUnknown) {
                [md setValue:@(batteryState) forKey:@"bs"];
            }

            NSData *data = [NSJSONSerialization dataWithJSONObject:md
                                                           options:0
                                                             error:nil];

            NSURL *url = [NSURL URLWithString:[[NSUserDefaults standardUserDefaults] stringForKey:@"url"]];

            if ([url.scheme isEqualToString:@"http"] ||
                [url.scheme isEqualToString:@"https"]) {
                NSString *topic = [NSString stringWithFormat:@"owntracks/%@/%@",
                                   url.user, [self effectiveTid]];
                md[@"topic"] = topic;
                data = [self clean:data dictionary:md];
                [self sendHTTP:data];
            }

            if ([url.scheme isEqualToString:@"mqtt"] ||
                [url.scheme isEqualToString:@"mqtts"] ||
                [url.scheme isEqualToString:@"ws"] ||
                [url.scheme isEqualToString:@"wss"]) {
                NSString *topic = [NSString stringWithFormat:@"owntracks/%@/%@",
                                   url.user, [self effectiveTid]];
                data = [NSJSONSerialization dataWithJSONObject:md
                                                       options:0
                                                         error:nil];
                data = [self clean:data dictionary:md];

                if (self.mqttSession.status != MQTTSessionStatusConnecting &&
                    self.mqttSession.status != MQTTSessionStatusConnected) {
                    [self.mqttSession connectWithConnectHandler:nil];
                }
                [self.mqttSession publishDataV5:data
                                        onTopic:topic
                                         retain:true
                                            qos:MQTTQosLevelAtLeastOnce
                         payloadFormatIndicator:nil
                          messageExpiryInterval:nil
                                     topicAlias:nil
                                  responseTopic:nil
                                correlationData:nil
                                 userProperties:nil
                                    contentType:nil
                                 publishHandler:
                 ^(NSError * _Nullable error,
                   NSString * _Nullable reasonString,
                   NSArray<NSDictionary<NSString *,NSString *> *> * _Nullable userProperties,
                   NSNumber * _Nullable reasonCode,
                   UInt16 msgID) {
                    //
                }];
            }
        }
    }
}

- (void)locationManager:(CLLocationManager *)manager
didChangeAuthorizationStatus:(CLAuthorizationStatus)status {
    NSLog(@"locationManager didChangeAuthorizationStatus %d %@",
          status, [self authorizationStatus:status]);
    switch (status) {
        case kCLAuthorizationStatusAuthorizedAlways:
        case kCLAuthorizationStatusAuthorizedWhenInUse:
            [self.track setEnabled:true];
            break;
        case kCLAuthorizationStatusRestricted:
        case kCLAuthorizationStatusNotDetermined:
        case kCLAuthorizationStatusDenied:
        default:
            [self.track setEnabled:false];
            break;
    }
}

- (IBAction)changeTracking:(BOOL)value {
    if (value) {
        NSLog(@"locationManager startUpdatingLocation");

        self.locationManager.allowsBackgroundLocationUpdates = true;
        [self.locationManager startUpdatingLocation];
        NSURL *url = [NSURL URLWithString:[[NSUserDefaults standardUserDefaults] stringForKey:@"url"]];

        if ([url.scheme isEqualToString:@"mqtt"] ||
            [url.scheme isEqualToString:@"mqtts"] ||
            [url.scheme isEqualToString:@"ws"] ||
            [url.scheme isEqualToString:@"wss"]) {

            MQTTNWTransport *nwTransport = [[MQTTNWTransport alloc] init];
            nwTransport.host =  url.host;
            nwTransport.port = url.port.unsignedIntValue;
            if ([url.scheme isEqualToString:@"mqtts"] ||
                [url.scheme isEqualToString:@"wss"]) {
                nwTransport.tls = true;
            }
            if ([url.scheme isEqualToString:@"ws"] ||
                [url.scheme isEqualToString:@"wss"]) {
                nwTransport.ws = true;
            }
            nwTransport.allowUntrustedCertificates = false; // TODO

            self.mqttSession.transport = nwTransport;
            self.mqttSession.clientId = [NSString stringWithFormat:@"%@%@",
                                         url.user, [self effectiveTid]];
            self.mqttSession.userName = url.password ? url.user : nil;
            self.mqttSession.password = url.password ? url.password : nil;
            self.mqttSession.keepAliveInterval = 60;
            self.mqttSession.cleanSessionFlag = false;
            self.mqttSession.topicAliasMaximum = @(10);
            self.mqttSession.sessionExpiryInterval = @(0xFFFFFFFF);

            self.mqttSession.protocolLevel = MQTTProtocolVersion50;
            self.mqttSession.persistence.persistent = TRUE;
            self.mqttSession.persistence.maxMessages = 100 * 1024;
            self.mqttSession.persistence.maxSize = 100 * 1024 * 1024;

            NSString *willTopic = [NSString stringWithFormat:@"owntracks/%@/%@",
                                   url.user, [self effectiveTid]];
            NSMutableDictionary *will = [[NSMutableDictionary alloc] init];
            will[@"_type"] = @"lwt";
            will[@"tst"] = @((int)[NSDate date].timeIntervalSince1970);
            will[@"tid"] = [self effectiveTid];
            NSData *willData = [NSJSONSerialization dataWithJSONObject:will
                                                               options:0
                                                                 error:nil];

            MQTTWill *mqttWill = [[MQTTWill alloc]
                                  initWithTopic:willTopic
                                  data:willData
                                  retainFlag:false
                                  qos:MQTTQosLevelAtLeastOnce
                                  willDelayInterval:nil
                                  payloadFormatIndicator:nil
                                  messageExpiryInterval:nil
                                  contentType:nil
                                  responseTopic:nil
                                  correlationData:nil
                                  userProperties:nil];
            self.mqttSession.will = mqttWill;

            [self.mqttSession connectWithConnectHandler:^(NSError * _Nullable error) {
                //
            }];
            [self.connection setText:@"MQTT connecting"];
            [self.connection setTextColor:[UIColor cyanColor]];
        };
    } else {
        NSLog(@"locationManager stopUpdatingLocation");
        [self.locationManager stopUpdatingLocation];

        NSURL *url = [NSURL URLWithString:[[NSUserDefaults standardUserDefaults] stringForKey:@"url"]];
        if ([url.scheme isEqualToString:@"mqtt"] ||
            [url.scheme isEqualToString:@"mqtts"] ||
            [url.scheme isEqualToString:@"ws"] ||
            [url.scheme isEqualToString:@"wss"]) {
            [self.mqttSession closeWithReturnCode:MQTTSuccess
                            sessionExpiryInterval:nil
                                     reasonString:nil
                                   userProperties:nil
                                disconnectHandler:nil];
            [self.connection setText:@"MQTT disconnected"];
            [self.connection setTextColor:[UIColor cyanColor]];
        }
    }
}

- (void)sendHTTP:(NSData *)data {
    NSString *postLength = [NSString stringWithFormat:@"%ld",(unsigned long)data.length];
    NSLog(@"sendtHTTP (%@):%@",
          postLength,
          [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
    [self.connection setText:@"HTTP"];
    [self.connection setTextColor:[UIColor cyanColor]];

    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];

    NSURL *url = [NSURL URLWithString:[[NSUserDefaults standardUserDefaults] stringForKey:@"url"]];

    if (url.password) {
        NSString *authString = [NSString stringWithFormat:@"%@:%@",
                                url.user ? url.user : @"",
                                url.password ? url.password : @""];
        NSData *authData = [authString dataUsingEncoding:NSASCIIStringEncoding];
        NSString *authValue = [authData base64EncodedStringWithOptions:0];
        [request setValue:[NSString stringWithFormat:@"Basic %@", authValue] forHTTPHeaderField:@"Authorization"];
    }

    NSString *xuser = @"user";
    if (url.user && url.user.length > 0) {
        xuser = url.user;
    }
    [request setValue:xuser forHTTPHeaderField:@"X-Limit-U"];

    NSString *xdevice = @"device";
    if ([self effectiveTid] && [self effectiveTid].length > 0) {
        xdevice = [self effectiveTid];
    }
    [request setValue:xdevice forHTTPHeaderField:@"X-Limit-D"];

    request.URL = url;
    request.HTTPMethod = @"POST";
    [request setValue:postLength forHTTPHeaderField:@"Content-Length"];
    request.HTTPBody = data;

    NSString *contentType = [NSString stringWithFormat:@"application/json"];
    [request setValue:contentType forHTTPHeaderField: @"Content-Type"];

    NSURLSessionDataTask *dataTask =
    [self.urlSession dataTaskWithRequest:request completionHandler:
     ^(NSData *data, NSURLResponse *response, NSError *error) {

        NSLog(@"dataTaskWithRequest %@ %@ %@", data, response, error);
        if (!error) {
            if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
                NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
                NSLog(@"NSHTTPURLResponse %@", httpResponse);
                if (httpResponse.statusCode >= 200 && httpResponse.statusCode <= 299) {
                    [self.connection setText:[NSString stringWithFormat:@"HTTP success %ld", (long)httpResponse.statusCode]];
                    [self.connection setTextColor:[UIColor greenColor]];
                } else {
                    [self.connection setText:[NSString stringWithFormat:@"HTTP code %ld", (long)httpResponse.statusCode]];
                    [self.connection setTextColor:[UIColor orangeColor]];
                }
            } else {
                [self.connection setText:[NSString stringWithFormat:@"HTTP %@", response.description]];
                [self.connection setTextColor:[UIColor redColor]];
            }
        } else {
            [self.connection setText:[NSString stringWithFormat:@"HTTP %@", error]];
            [self.connection setTextColor:[UIColor redColor]];
        }
    }];
    [dataTask resume];
}

- (void)handleEvent:(MQTTSession *)session event:(MQTTSessionEvent)eventCode error:(NSError *)error {
    NSLog(@"handleEvent %ld %@", (long)eventCode, error);
    switch (eventCode) {

        case MQTTSessionEventConnected:
            [self.connection setText:@"MQTT connected"];
            [self.connection setTextColor:[UIColor greenColor]];
            break;
        case MQTTSessionEventConnectionRefused:
            [self.connection setText:@"MQTT refused"];
            [self.connection setTextColor:[UIColor orangeColor]];
            break;
        case MQTTSessionEventConnectionClosed:
            break;
        case MQTTSessionEventConnectionError:
            [self.connection setText:@"MQTT connection error"];
            [self.connection setTextColor:[UIColor redColor]];
            break;
        case MQTTSessionEventProtocolError:
            [self.connection setText:@"MQTT protocol error"];
            [self.connection setTextColor:[UIColor redColor]];
            break;
        case MQTTSessionEventConnectionClosedByBroker:
            [self.connection setText:@"MQTT closed by broker"];
            [self.connection setTextColor:[UIColor redColor]];
            break;
    }
}

- (NSData *)clean:(NSData *)data
       dictionary:(NSDictionary *)dictionary {
    // *****
    // This is a hack because I don't see another chance to modify NSNumber
    // formatting in NSJSONSerialization
    // *****
    NSNumber *lat = [dictionary valueForKey:@"lat"];
    NSNumber *lon = [dictionary valueForKey:@"lon"];
    NSString *jsonString = [[NSString alloc] initWithData:data
                                                 encoding:NSUTF8StringEncoding];
    if (lat) {
        NSString *latString = [NSString stringWithFormat:@"\"lat\":%.6f", lat.doubleValue];
        NSData *jsonData =
        [NSJSONSerialization dataWithJSONObject:@{@"lat": lat}
                                        options:0
                                          error:nil];
        NSString *jsonSubString =
        [[NSString alloc] initWithData:jsonData
                              encoding:NSUTF8StringEncoding];
        jsonSubString =
        [jsonSubString substringWithRange:NSMakeRange(1, jsonSubString.length - 2)];

        jsonString = [jsonString stringByReplacingOccurrencesOfString:jsonSubString
                                                           withString:latString];
    }

    if (lon) {
        NSString *lonString = [NSString stringWithFormat:@"\"lon\":%.6f", lon.doubleValue];
        NSData *jsonData =
        [NSJSONSerialization dataWithJSONObject:@{@"lon": lon}
                                        options:0
                                          error:nil];
        NSString *jsonSubString =
        [[NSString alloc] initWithData:jsonData
                              encoding:NSUTF8StringEncoding];
        jsonSubString =
        [jsonSubString substringWithRange:NSMakeRange(1, jsonSubString.length - 2)];

        jsonString =
        [jsonString stringByReplacingOccurrencesOfString:jsonSubString
                                              withString:lonString];
    }

    NSData *newData = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
    // *****

    return newData;
}

- (NSString *)effectiveTid {
    NSString *tid = [[NSUserDefaults standardUserDefaults] stringForKey:@"tid"];
    if (!tid) {
        tid = ([WKInterfaceDevice currentDevice].identifierForVendor).UUIDString;
    }
    if (tid.length > 2) {
        tid = [tid substringFromIndex:tid.length - 2];
    }
    return tid;
}


@end



