import Foundation

/// Compact, Codable snapshot of the dashboard score that can be read by
/// the widget extension. Written to App Group UserDefaults so the widget
/// process can share state with the main app — falls back to standard
/// UserDefaults when the group isn't available (e.g. in dev before the
/// App Group is enabled in entitlements).
struct WidgetSnapshot: Codable, Sendable, Equatable {
    let score: Int
    let rating: String          // FishingScore.Rating.label
    let summary: String         // short summary
    let locationName: String?
    let bestHour: Int?          // 0...23 — peak score hour
    let bestHourScore: Int?
    let topFactor: String?      // most positive factor name
    let updatedAt: Date

    /// Lightweight stand-in used until the dashboard has loaded once.
    static let placeholder = WidgetSnapshot(
        score: 72,
        rating: "Good",
        summary: "Conditions look promising — light wind and steady pressure.",
        locationName: "Your spot",
        bestHour: 18,
        bestHourScore: 84,
        topFactor: "Pressure Trend",
        updatedAt: .now
    )
}

/// Read/write the snapshot to App Group UserDefaults. The group identifier
/// must match the one configured in the app + widget entitlements.
enum WidgetStorage {
    static let appGroupIdentifier = "group.com.fishcast.shared"
    static let snapshotKey = "widget.snapshot"

    private static var defaults: UserDefaults {
        UserDefaults(suiteName: appGroupIdentifier) ?? .standard
    }

    static func save(_ snapshot: WidgetSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: snapshotKey)
    }

    static func load() -> WidgetSnapshot? {
        guard let data = defaults.data(forKey: snapshotKey) else { return nil }
        return try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
    }
}
