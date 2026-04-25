import Foundation

/// Immutable snapshot of conditions at the time a catch was logged. Stored
/// inline on `CatchEntry` so trend analysis ("I do well in steady 1015 hPa")
/// doesn't depend on re-fetching weather history later.
struct WeatherSnapshot: Codable, Hashable, Sendable {
    var temperatureF: Double
    var pressureHPa: Double
    var windMph: Double
    var conditionDescription: String
    var moonPhase: String?
    var capturedAt: Date

    init(
        temperatureF: Double,
        pressureHPa: Double,
        windMph: Double,
        conditionDescription: String,
        moonPhase: String? = nil,
        capturedAt: Date = .now
    ) {
        self.temperatureF = temperatureF
        self.pressureHPa = pressureHPa
        self.windMph = windMph
        self.conditionDescription = conditionDescription
        self.moonPhase = moonPhase
        self.capturedAt = capturedAt
    }

    init(from current: CurrentWeather, moonPhase: MoonPhase? = nil) {
        self.init(
            temperatureF: current.temperature.converted(to: .fahrenheit).value,
            pressureHPa:  current.pressure.converted(to: .hectopascals).value,
            windMph:      current.windSpeed.converted(to: .milesPerHour).value,
            conditionDescription: current.conditionDescription,
            moonPhase:    moonPhase?.label,
            capturedAt:   current.date
        )
    }
}
