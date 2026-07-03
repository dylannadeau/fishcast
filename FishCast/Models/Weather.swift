import Foundation
import WeatherKit

// MARK: - Current

struct CurrentWeather: Sendable {
    let date: Date
    let temperature: Measurement<UnitTemperature>
    let apparentTemperature: Measurement<UnitTemperature>
    let humidity: Double                         // 0 ... 1
    let windSpeed: Measurement<UnitSpeed>
    let windDirection: Measurement<UnitAngle>
    let windGust: Measurement<UnitSpeed>?
    let uvIndex: Int
    let visibility: Measurement<UnitLength>
    let precipitationChance: Double              // 0 ... 1  (sourced from upcoming hour)
    let pressure: Measurement<UnitPressure>
    let conditionDescription: String
    let symbolName: String
}

extension CurrentWeather {
    init(from kit: WeatherKit.CurrentWeather, precipitationChance: Double) {
        self.date                 = kit.date
        self.temperature          = kit.temperature
        self.apparentTemperature  = kit.apparentTemperature
        self.humidity             = kit.humidity
        self.windSpeed            = kit.wind.speed
        self.windDirection        = kit.wind.direction
        self.windGust             = kit.wind.gust
        self.uvIndex              = kit.uvIndex.value
        self.visibility           = kit.visibility
        self.precipitationChance  = precipitationChance
        self.pressure             = kit.pressure
        self.conditionDescription = kit.condition.description
        self.symbolName           = kit.symbolName
    }
}

// MARK: - Hourly

struct HourlyForecast: Identifiable, Sendable {
    let id: Date
    let date: Date
    let temperature: Measurement<UnitTemperature>
    let precipitationChance: Double
    let windSpeed: Measurement<UnitSpeed>
    let windDirection: Measurement<UnitAngle>
    let pressure: Measurement<UnitPressure>
    let conditionDescription: String
    let symbolName: String
}

extension HourlyForecast {
    init(from kit: HourWeather) {
        self.id                   = kit.date
        self.date                 = kit.date
        self.temperature          = kit.temperature
        self.precipitationChance  = kit.precipitationChance
        self.windSpeed            = kit.wind.speed
        self.windDirection        = kit.wind.direction
        self.pressure             = kit.pressure
        self.conditionDescription = kit.condition.description
        self.symbolName           = kit.symbolName
    }
}

// MARK: - Daily

struct DailyForecast: Identifiable, Sendable {
    let id: Date
    let date: Date
    let highTemperature: Measurement<UnitTemperature>
    let lowTemperature: Measurement<UnitTemperature>
    let precipitationChance: Double
    let windSpeed: Measurement<UnitSpeed>
    let windDirection: Measurement<UnitAngle>
    let sunrise: Date?
    let sunset: Date?
    let moonPhase: String
    let moonPhaseSymbolName: String
    let conditionDescription: String
    let symbolName: String
}

extension DailyForecast {
    init(from kit: DayWeather) {
        self.id                   = kit.date
        self.date                 = kit.date
        self.highTemperature      = kit.highTemperature
        self.lowTemperature       = kit.lowTemperature
        self.precipitationChance  = kit.precipitationChance
        self.windSpeed            = kit.wind.speed
        self.windDirection        = kit.wind.direction
        self.sunrise              = kit.sun.sunrise
        self.sunset               = kit.sun.sunset
        self.moonPhase            = kit.moon.phase.description
        self.moonPhaseSymbolName  = kit.moon.phase.symbolName
        self.conditionDescription = kit.condition.description
        self.symbolName           = kit.symbolName
    }
}

// MARK: - Bundle

/// Bundled result for `WeatherService.fullForecast` — one network call, three slices.
struct WeatherBundle: Sendable {
    let current: CurrentWeather
    let hourly: [HourlyForecast]
    let daily: [DailyForecast]
}

/// Result of `WeatherService.spotForecast` — the forward-looking bundle plus
/// the trailing hourly history used for "how does today compare" averages
/// and the per-spot pressure trend. Still a single billed WeatherKit call.
struct SpotWeather: Sendable {
    let bundle: WeatherBundle
    /// Hours strictly before the fetch time, oldest first, spanning the
    /// requested history window (subject to WeatherKit data availability).
    let historyHourly: [HourlyForecast]
}
