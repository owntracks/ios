//
//  OwnTracksWatchBridge.m
//

#import "OwnTracksWatchBridge.h"
#import "Settings.h"
#import "CoreData.h"
#import <WatchConnectivity/WatchConnectivity.h>
#import <CocoaLumberjack/CocoaLumberjack.h>

static const DDLogLevel ddLogLevel = DDLogLevelInfo;

@interface OwnTracksWatchBridge () <WCSessionDelegate>
@end

@implementation OwnTracksWatchBridge

+ (instancetype)shared {
    static OwnTracksWatchBridge *s;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        s = [[self alloc] init];
    });
    return s;
}

- (void)activate {
    if (![WCSession isSupported]) {
        DDLogInfo(@"[OwnTracksWatchBridge] WatchConnectivity not supported");
        return;
    }
    WCSession *session = [WCSession defaultSession];
    session.delegate = self;
    [session activateSession];
}

- (NSDictionary *)watchConfigPayloadInMOC:(NSManagedObjectContext *)moc {
    NSString *url = [Settings stringForKey:@"url_preference" inMOC:moc] ?: @"";
    NSString *watchWebhookURL = [Settings stringForKeyUsingPlistDefaultWhenEmpty:@"watch_webhook_url_preference" inMOC:moc];

    if (!url.length && !watchWebhookURL.length) {
        return nil;
    }

    BOOL usePassword = [Settings theMqttUsePasswordInMOC:moc];
    NSString *password = @"";
    if (usePassword) {
        password = [Settings theMqttPassInMOC:moc] ?: @"";
    }

    NSString *user = [Settings theMqttUserInMOC:moc] ?: @"user";
    NSString *device = [Settings theDeviceIdInMOC:moc] ?: @"device";
    NSString *headers = [Settings stringForKey:@"httpheaders_preference" inMOC:moc] ?: @"";
    NSString *tid = [Settings stringForKey:@"trackerid_preference" inMOC:moc] ?: @"";
    BOOL extended = [Settings boolForKey:@"extendeddata_preference" inMOC:moc];
    NSString *oauthClient = [Settings stringForKey:@"oauth_client_id_preference" inMOC:moc] ?: @"";

    NSString *watchDevice = [device stringByAppendingString:@"-w"];
    NSString *watchTid = tid.length ? [NSString stringWithFormat:@"%cW", [tid characterAtIndex:0]] : @"W";
    NSString *topicPref = [Settings stringForKey:@"topic_preference" inMOC:moc] ?: @"";
    NSString *userId = [Settings theUserIdInMOC:moc] ?: @"user";
    NSString *watchTopic;
    if (topicPref.length) {
        watchTopic = [topicPref stringByReplacingOccurrencesOfString:@"%u" withString:userId];
        watchTopic = [watchTopic stringByReplacingOccurrencesOfString:@"%d" withString:watchDevice];
    } else {
        watchTopic = [NSString stringWithFormat:@"owntracks/%@/%@", userId, watchDevice];
    }

    NSDictionary *payload = @{
        @"httpURL": url,
        @"watchWebhookURL": watchWebhookURL,
        @"authBasic": @([Settings theMqttAuthInMOC:moc]),
        @"user": user,
        @"pass": password,
        @"limitU": user,
        @"limitD": watchDevice,
        @"deviceId": watchDevice,
        @"publishTopic": watchTopic,
        @"httpHeaderLines": headers,
        @"trackerId": watchTid,
        @"includeExtendedData": @(extended),
        @"oauthClientId": oauthClient.length ? oauthClient : [NSNull null],
        @"oauthRefreshURL": [NSNull null]
    };

    NSMutableDictionary *sanitized = [payload mutableCopy];
    for (id key in [sanitized allKeys]) {
        id v = sanitized[key];
        if (v == [NSNull null]) {
            [sanitized removeObjectForKey:key];
        }
    }
    return sanitized;
}

- (void)pushConfigToWatchIfNeeded {
    if (![WCSession isSupported]) {
        return;
    }
    WCSession *session = [WCSession defaultSession];
    if (session.activationState != WCSessionActivationStateActivated) {
        return;
    }
    NSManagedObjectContext *moc = CoreData.sharedInstance.mainMOC;
    NSDictionary *sanitized = [self watchConfigPayloadInMOC:moc];
    if (!sanitized) {
        DDLogVerbose(@"[OwnTracksWatchBridge] no url_preference or watch_webhook_url; skip push");
        return;
    }

    NSError *err = nil;
    if (![session updateApplicationContext:sanitized error:&err]) {
        DDLogWarn(@"[OwnTracksWatchBridge] updateApplicationContext failed: %@ — trying transferUserInfo", err);
        [session transferUserInfo:sanitized];
    } else {
        DDLogInfo(@"[OwnTracksWatchBridge] pushed watch HTTP config (webhook=%@)",
                  sanitized[@"watchWebhookURL"] ?: @"(none)");
    }
}

#pragma mark - WCSessionDelegate

- (void)session:(WCSession *)session
activationDidCompleteWithState:(WCSessionActivationState)activationState
                          error:(NSError *)error {
    if (error) {
        DDLogWarn(@"[OwnTracksWatchBridge] activation error %@", error);
        return;
    }
    if (activationState == WCSessionActivationStateActivated) {
        [self pushConfigToWatchIfNeeded];
    }
}

- (void)sessionDidBecomeInactive:(WCSession *)session {
}

- (void)sessionDidDeactivate:(WCSession *)session {
    [session activateSession];
}

- (void)sessionWatchStateDidChange:(WCSession *)session {
    if (session.paired && session.watchAppInstalled) {
        [self pushConfigToWatchIfNeeded];
    }
}

- (void)session:(WCSession *)session
didReceiveMessage:(NSDictionary<NSString *, id> *)message
      replyHandler:(void (^)(NSDictionary<NSString *, id> *))replyHandler {
    if ([message[@"requestWatchConfig"] boolValue]) {
        NSDictionary *payload = [self watchConfigPayloadInMOC:CoreData.sharedInstance.mainMOC];
        if (payload) {
            NSError *err = nil;
            [session updateApplicationContext:payload error:&err];
            if (err) {
                DDLogWarn(@"[OwnTracksWatchBridge] context update on request failed: %@", err);
            }
            replyHandler(payload);
        } else {
            replyHandler(@{@"error": @"no_http_config"});
        }
        return;
    }
    replyHandler(@{});
}

@end
