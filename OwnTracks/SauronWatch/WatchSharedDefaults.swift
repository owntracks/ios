//
//  WatchSharedDefaults.swift
//  SauronWatch
//
//  Shared UserDefaults for the watch app and SauronWatchWidget extension.
//

import Foundation

enum WatchSharedDefaults {
    /// Watch-only app group (register in Signing & Capabilities for SauronWatch + SauronWatchWidget).
    static let suiteName = "group.org.laskatj.owntracksfork.watch"

    static var store: UserDefaults {
        UserDefaults(suiteName: suiteName) ?? .standard
    }
}
