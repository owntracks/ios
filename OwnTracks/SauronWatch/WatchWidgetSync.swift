//
//  WatchWidgetSync.swift
//  SauronWatch
//

import Foundation
import WidgetKit

enum WatchWidgetSync {
    static let widgetKind = "SauronComplicationV3"

    static func push(queueDepth: Int, lastUpload: Date?) {
        let d = WatchSharedDefaults.store
        d.set(queueDepth, forKey: "widget_queue_depth")
        if let date = lastUpload {
            d.set(date, forKey: "widget_last_upload")
        }
        reloadWidgetTimelines()
    }

    static func reloadWidgetTimelines() {
        WidgetCenter.shared.reloadTimelines(ofKind: widgetKind)
    }
}
