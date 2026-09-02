//
//  SauronSharedDefaults.h
//  OwnTracks
//
//  Single source of truth for the app group shared by the app, the Siri
//  intents extension and the watch targets.
//
//  This value MUST match the com.apple.security.application-groups entry in
//  every target's entitlements:
//    OwnTracks/OwnTracks.entitlements
//    OwnTracksIntents/OwnTracksIntents.entitlements
//    SauronWatch/SauronWatch.entitlements
//    SauronWatchWidget/SauronWatchWidget.entitlements
//  and the Swift side in WatchSharedDefaults.swift / WatchWidgetDefaults.swift.
//
//  Why this is a shared constant rather than a literal at each call site:
//  -initWithSuiteName: does NOT fail when the process is not entitled to the
//  suite. iOS hands back an NSUserDefaults backed by the process's own
//  container, so every read and write succeeds while being completely
//  invisible to other processes. A drifted string therefore produces no error,
//  no log and no crash - just a feature that silently stops working. That is
//  exactly how the Siri "change monitoring" shortcut broke: the extension kept
//  writing to group.org.owntracks.Owntracks, an upstream group no target has
//  been entitled to since this fork was created.
//

#import <Foundation/Foundation.h>

#define kSauronAppGroupSuiteName @"group.org.laskatj.owntracksfork.watch"

/// Defaults backed by the shared app group container. Use this everywhere
/// instead of building the suite by hand.
static inline NSUserDefaults *SauronSharedDefaults(void) {
    return [[NSUserDefaults alloc] initWithSuiteName:kSauronAppGroupSuiteName];
}
