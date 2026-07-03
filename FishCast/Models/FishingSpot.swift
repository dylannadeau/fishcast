import CoreLocation
import Foundation

/// A saved fishing spot. `CLLocationCoordinate2D` is not `Codable`, so we
/// persist latitude/longitude as primitives and expose a computed
/// `coordinate` to callers. Catches are owned by `CatchStore` and linked
/// back via `CatchEntry.spotId`.
struct FishingSpot: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    var name: String
    var latitude: Double
    var longitude: Double
    var notes: String
    var fishSpecies: [String]
    let createdAt: Date

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    init(
        id: UUID = UUID(),
        name: String,
        coordinate: CLLocationCoordinate2D,
        notes: String = "",
        fishSpecies: [String] = [],
        createdAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.latitude = coordinate.latitude
        self.longitude = coordinate.longitude
        self.notes = notes
        self.fishSpecies = fishSpecies
        self.createdAt = createdAt
    }
}

// MARK: - Per-spot dashboard conditions

/// Everything one Dashboard spot card renders, flattened to plain `Codable`
/// primitives (°F, hPa, mph) so the last successful fetch can be cached to
/// disk and re-shown when a refresh fails. Built from a `SpotWeather` fetch
/// by `SpotConditionsViewModel`; never constructed by views.
struct SpotConditions: Codable, Sendable, Identifiable {
    let spotId: UUID
    let fetchedAt: Date

    var id: UUID { spotId }

    // MARK: Current conditions

    struct Current: Codable, Sendable {
        let tempF: Double
        let feelsLikeF: Double
        let pressureHPa: Double
        let windMph: Double
        let windCompass: String
        let humidity: Double            // 0 ... 1
        let precipChance: Double        // 0 ... 1
        let conditionDescription: String
        let symbolName: String
    }
    let current: Current

    /// 3-hour trend derived from this spot's own WeatherKit hourly history
    /// (not the device-location `BarometricService` cache).
    let pressureTrend: PressureTrend

    // MARK: Historical context

    /// Averages over the trailing window so "today vs the recent past" is a
    /// glance, not math. `nil` when WeatherKit returned no history.
    struct History: Codable, Sendable {
        let windowDays: Int
        let avgTempF: Double
        let avgPressureHPa: Double
        /// current − average; positive means today is warmer / higher.
        let tempDeltaF: Double
        let pressureDeltaHPa: Double
    }
    let history: History?

    // MARK: Upcoming trend

    /// One forecast day for the game-planning strip. Pressure values come
    /// from averaging hourly forecast pressure, so they run out (nil) past
    /// the 72h hourly horizon even though temps continue from daily data.
    struct OutlookDay: Codable, Sendable, Identifiable {
        let date: Date
        let highF: Double
        let lowF: Double
        let avgPressureHPa: Double?
        /// Day-over-day pressure change (first entry compares to current).
        let pressureDeltaHPa: Double?
        let symbolName: String

        var id: Date { date }

        var pressureTrend: PressureTrend? {
            pressureDeltaHPa.map(dailyTrend(fromDelta:))
        }
    }
    let outlook: [OutlookDay]

    // MARK: Fish likelihood

    /// Overall 0–100 spot score for today (same engine as the hero card).
    let score: Int
    let summary: String
    /// Top of the species ranking for today — best bets at this spot.
    let mostLikely: [SpeciesPrediction]
    /// Bottom of the ranking, worst first — what not to chase today.
    let leastLikely: [SpeciesPrediction]
}

/// Day-over-day deltas span 24h, not 3h, so the rapid/slow thresholds are
/// scaled up (×2) from the meteorological 3-hour convention.
private func dailyTrend(fromDelta delta: Double) -> PressureTrend {
    let magnitude = abs(delta)
    if magnitude <= 2 { return .steady }
    let rising = delta > 0
    if magnitude > 6 { return rising ? .rapidRise : .rapidFall }
    return rising ? .slowRise : .slowFall
}
