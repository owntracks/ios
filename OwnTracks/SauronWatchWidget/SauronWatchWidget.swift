//
//  SauronWatchWidget.swift
//  SauronWatchWidget
//

import WidgetKit
import SwiftUI

// MARK: - Shared data

private struct WidgetData {
    let mode: String
    let queueDepth: Int
    let lastUpload: Date?

    static func load() -> WidgetData {
        let d = WatchWidgetDefaults.store
        return WidgetData(
            mode: d.string(forKey: "watch_tracking_mode") ?? "passive",
            queueDepth: d.integer(forKey: "widget_queue_depth"),
            lastUpload: d.object(forKey: "widget_last_upload") as? Date
        )
    }
}

// MARK: - Timeline provider

struct SauronTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> SauronEntry {
        SauronEntry(date: Date(), mode: "passive", queueDepth: 0, lastUpload: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (SauronEntry) -> Void) {
        let data = WidgetData.load()
        completion(SauronEntry(date: Date(), mode: data.mode, queueDepth: data.queueDepth, lastUpload: data.lastUpload))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SauronEntry>) -> Void) {
        let data = WidgetData.load()
        let entry = SauronEntry(date: Date(), mode: data.mode, queueDepth: data.queueDepth, lastUpload: data.lastUpload)
        let next = Calendar.current.date(byAdding: .minute, value: 5, to: Date()) ?? Date()
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

struct SauronEntry: TimelineEntry {
    let date: Date
    let mode: String
    let queueDepth: Int
    let lastUpload: Date?
}

// MARK: - Complication helpers

/// Vector eye without GeometryReader (zero-sized in many watch complication slots).
private struct DrawnSauronEye: View {
    let isOpen: Bool

    var body: some View {
        ZStack {
            if isOpen {
                Ellipse()
                    .strokeBorder(lineWidth: 2.5)
                    .frame(width: 36, height: 18)
                Capsule()
                    .frame(width: 5, height: 16)
            } else {
                Capsule()
                    .trim(from: 0.0, to: 0.5)
                    .frame(width: 32, height: 32)
                    .rotationEffect(.degrees(90))
                    .offset(y: 2)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .widgetAccentable()
    }
}

private struct SauronComplicationEye: View {
    let entry: SauronEntry
    var padding: CGFloat = 6
    var showBuildStamp: Bool = false

    private var isActive: Bool { entry.mode == "active" }

    var body: some View {
        ZStack {
            statusRing
            DrawnSauronEye(isOpen: isActive)
                .padding(padding)
            if showBuildStamp {
                VStack {
                    HStack {
                        Spacer()
                        Text(WidgetBuildLabel.text)
                            .font(.system(size: 7, weight: .bold).monospacedDigit())
                            .minimumScaleFactor(0.5)
                            .lineLimit(1)
                    }
                    Spacer()
                }
                .padding(2)
            }
        }
    }

    @ViewBuilder
    private var statusRing: some View {
        Circle()
            .stroke(lineWidth: isActive ? 3 : 1.5)
            .opacity(isActive ? 1 : 0.35)
            .widgetAccentable()
    }
}

// MARK: - Complication views

struct CircularView: View {
    let entry: SauronEntry

    var body: some View {
        ZStack {
            SauronComplicationEye(entry: entry, showBuildStamp: true)
            if entry.queueDepth > 0 {
                VStack {
                    Spacer()
                    Text("\(entry.queueDepth)")
                        .font(.system(size: 9, weight: .bold).monospacedDigit())
                        .foregroundStyle(.white)
                        .shadow(radius: 1)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct CornerView: View {
    let entry: SauronEntry
    private var isActive: Bool { entry.mode == "active" }

    var body: some View {
        SauronComplicationEye(entry: entry, padding: 4)
            .widgetLabel {
                Text("\(isActive ? "Active" : "Passive") · \(WidgetBuildLabel.text)")
            }
    }
}

struct RectangularView: View {
    let entry: SauronEntry
    private var isActive: Bool { entry.mode == "active" }

    var body: some View {
        HStack(spacing: 6) {
            SauronComplicationEye(entry: entry, padding: 4)
                .frame(width: 28, height: 28)
            VStack(alignment: .leading, spacing: 1) {
                Text(isActive ? "Active" : "Passive")
                    .font(.headline)
                Text(WidgetBuildLabel.text)
                    .font(.system(size: 8).monospacedDigit())
                    .foregroundStyle(.secondary)
                if let last = entry.lastUpload {
                    Text(last, style: .relative)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } else {
                    Text("No uploads yet")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if entry.queueDepth > 0 {
                Text("\(entry.queueDepth)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.orange)
            }
        }
    }
}

struct InlineView: View {
    let entry: SauronEntry
    private var isActive: Bool { entry.mode == "active" }

    var body: some View {
        HStack(spacing: 3) {
            DrawnSauronEye(isOpen: isActive)
                .frame(width: 14, height: 14)
            Text("\(isActive ? "Active" : "Passive") \(WidgetBuildLabel.text)")
        }
    }
}

// MARK: - Widget entry view dispatcher

struct SauronWidgetEntryView: View {
    var entry: SauronEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        Group {
            switch family {
            case .accessoryCircular:
                CircularView(entry: entry)
            case .accessoryCorner:
                CornerView(entry: entry)
            case .accessoryRectangular:
                RectangularView(entry: entry)
            case .accessoryInline:
                InlineView(entry: entry)
            default:
                CircularView(entry: entry)
            }
        }
        .containerBackground(.clear, for: .widget)
    }
}

// MARK: - Widget declaration

struct SauronWatchWidget: Widget {
    /// Bump kind when complication metadata or art changes so watchOS picks up a new entry.
    let kind = "SauronComplicationV3"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SauronTimelineProvider()) { entry in
            SauronWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Sauron Eye")
        .description("Open eye + ring = active; closed = passive. Build on face.")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryCorner,
            .accessoryRectangular,
            .accessoryInline,
        ])
    }
}

// MARK: - Entry point

@main
struct SauronWatchWidgetBundle: WidgetBundle {
    var body: some Widget {
        SauronWatchWidget()
    }
}
