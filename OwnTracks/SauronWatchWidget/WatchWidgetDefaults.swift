//
//  WatchWidgetDefaults.swift
//  SauronWatchWidget
//

import Foundation

enum WatchWidgetDefaults {
    static let suiteName = "group.org.laskatj.owntracksfork.watch"

    static var store: UserDefaults {
        UserDefaults(suiteName: suiteName) ?? .standard
    }
}

enum WidgetBuildLabel {
    static var text: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(version).\(build)"
    }
}
