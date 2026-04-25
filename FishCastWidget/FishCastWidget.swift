import SwiftUI
import WidgetKit

struct FishCastWidget: Widget {
    let kind: String = "FishCastWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: FishCastTimelineProvider()) { entry in
            FishCastWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Fishing Score")
        .description("Today's fishing forecast at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Timeline provider

struct FishCastTimelineEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
}

struct FishCastTimelineProvider: TimelineProvider {

    func placeholder(in context: Context) -> FishCastTimelineEntry {
        FishCastTimelineEntry(date: .now, snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (FishCastTimelineEntry) -> Void) {
        let entry = FishCastTimelineEntry(
            date: .now,
            snapshot: WidgetStorage.load() ?? .placeholder
        )
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<FishCastTimelineEntry>) -> Void) {
        let snapshot = WidgetStorage.load() ?? .placeholder
        let entry = FishCastTimelineEntry(date: .now, snapshot: snapshot)
        // Refresh hourly — the main app also pokes WidgetCenter on dashboard load.
        let next = Calendar.current.date(byAdding: .hour, value: 1, to: .now) ?? .now
        let timeline = Timeline(entries: [entry], policy: .after(next))
        completion(timeline)
    }
}
