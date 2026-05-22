//
//  WatchTrackingPolicy.swift
//  SauronWatch
//
//  Passive vs active sampling and upload cadence. See docs/watch/TRACKING_MODES.md
//

import Foundation
import CoreLocation

enum WatchTrackingMode: String, CaseIterable {
    case passive
    case active
}

enum WatchTrackingPolicy {
    /// When non-empty, location POSTs use this URL instead of the HTTP URL synced from iPhone
    /// (e.g. separate Home Assistant webhook for watch).
    static let ingestURLOverride = ""

    /// Passive: coarse updates, best-effort background behavior.
    static let passiveDesiredAccuracy = kCLLocationAccuracyHundredMeters
    static let passiveDistanceFilter: CLLocationDistance = 200

    /// Active: user-started session, higher fidelity.
    static let activeDesiredAccuracy = kCLLocationAccuracyBest
    /// Hint to Core Location; drift can still deliver more often than this.
    static let activeDistanceFilter: CLLocationDistance = 35

    /// Active mode: do not enqueue a new point unless this many **seconds** have passed **or** moved ≥ `activeMinDisplacementMeters` (reduces sitting-still spam).
    static let activeMinEnqueueInterval: TimeInterval = 30

    /// Active mode: always enqueue if moved this far from last **enqueued** point (meters).
    static let activeMinDisplacementMeters: CLLocationDistance = 35

    /// Minimum interval between uploads when the queue is **empty** (steady-state throttling; seconds).
    static let passiveUploadMinInterval: TimeInterval = 5 * 60

    /// Minimum interval between uploads when the queue is **empty** (active mode; seconds).
    static let activeUploadMinInterval: TimeInterval = 90

    /// Spacing between **single-point** POSTs while draining (unused when batching ≥2 points).
    static let backlogUploadSpacing: TimeInterval = 0.5

    /// Spacing between **batch** POSTs when the queue still has more after one batch (seconds).
    static let backlogBatchSpacing: TimeInterval = 0.15

    /// Max locations per batch POST when queue depth ≥ `minQueueDepthForBatchIngest`.
    static let maxBatchSize = 40

    /// Use batch envelope only when at least this many points are queued (1 keeps iOS-compatible single-object POST).
    static let minQueueDepthForBatchIngest = 2

    /// Safety cap: HTTP operations (single or batch) per scheduler tick.
    static let maxUploadsPerSchedulerTick = 100

    /// Max persisted queued points (oldest dropped under pressure).
    static let maxQueuedPoints = 500

    /// Retry backoff: initial and max (seconds).
    static let uploadBackoffInitial: TimeInterval = 30
    static let uploadBackoffMax: TimeInterval = 30 * 60
}
