import Foundation

/// User-facing measurement system. Stored as a raw string in `AppStorage`.
enum UnitsPreference: String, CaseIterable, Identifiable, Sendable {
    case imperial, metric

    var id: String { rawValue }
    var label: String {
        switch self {
        case .imperial: return "Imperial"
        case .metric:   return "Metric"
        }
    }
    var summary: String {
        switch self {
        case .imperial: return "°F · mph · ft"
        case .metric:   return "°C · km/h · m"
        }
    }
}

/// Stable storage keys for `@AppStorage` and `UserDefaults` reads. Keep
/// keys in one place so the widget extension and main app stay in sync.
enum SettingsKey {
    static let onboardingComplete = "settings.onboardingComplete"
    static let units              = "settings.units"
    static let notificationsOn    = "settings.notifications.enabled"
    /// Daily reminder time as minutes since midnight (0...1439).
    static let notificationsMinute = "settings.notifications.minute"
    /// Trailing window (days) for the Dashboard's "vs recent average"
    /// comparison on spot cards. Capped at 7 — history + 3-day forecast has
    /// to fit inside one WeatherKit hourly query.
    static let historyWindowDays = "settings.dashboard.historyDays"
}

/// Selectable history windows for the spot-card comparison.
enum HistoryWindow {
    static let options = [3, 5, 7]
    static let `default` = 7
}

/// Default value bootstrap so the widget extension reads the same keys
/// without needing the AppStorage property wrapper machinery.
extension UserDefaults {
    var unitsPreference: UnitsPreference {
        UnitsPreference(rawValue: string(forKey: SettingsKey.units) ?? "")
            ?? .imperial
    }
}

extension UnitsPreference {
    func formatTemperature(_ measurement: Measurement<UnitTemperature>) -> String {
        let unit: UnitTemperature = (self == .imperial) ? .fahrenheit : .celsius
        let value = measurement.converted(to: unit).value
        return "\(Int(value.rounded()))°\(self == .imperial ? "F" : "C")"
    }

    func formatWindSpeed(_ measurement: Measurement<UnitSpeed>) -> String {
        let unit: UnitSpeed = (self == .imperial) ? .milesPerHour : .kilometersPerHour
        let suffix = (self == .imperial) ? "mph" : "km/h"
        return "\(Int(measurement.converted(to: unit).value.rounded())) \(suffix)"
    }

    func formatLength(_ measurement: Measurement<UnitLength>) -> String {
        let unit: UnitLength = (self == .imperial) ? .feet : .meters
        let suffix = (self == .imperial) ? "ft" : "m"
        return "\(Int(measurement.converted(to: unit).value.rounded())) \(suffix)"
    }
}
