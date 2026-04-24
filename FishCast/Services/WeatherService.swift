import CoreLocation
import WeatherKit

/// Wraps Apple's WeatherKit and exposes FishCast-shaped domain models.
///
/// Note: WeatherKit is billed per-request, so prefer ``fullForecast(for:)`` over
/// calling the current/hourly/daily methods separately.
final class WeatherService {
    static let shared = WeatherService()

    // Qualify with the module name to disambiguate from our own `WeatherService`.
    private let kit = WeatherKit.WeatherService.shared

    private init() {}

    func currentConditions(for location: CLLocation) async throws -> CurrentWeather {
        let weather = try await fetchWeather(for: location)
        let precipChance = upcomingHour(in: weather)?.precipitationChance ?? 0
        return CurrentWeather(from: weather.currentWeather, precipitationChance: precipChance)
    }

    func hourlyForecast(for location: CLLocation, hours: Int = 24) async throws -> [HourlyForecast] {
        let weather = try await fetchWeather(for: location)
        return Array(weather.hourlyForecast.prefix(hours)).map(HourlyForecast.init(from:))
    }

    func dailyForecast(for location: CLLocation, days: Int = 7) async throws -> [DailyForecast] {
        let weather = try await fetchWeather(for: location)
        return Array(weather.dailyForecast.prefix(days)).map(DailyForecast.init(from:))
    }

    /// Single WeatherKit request returning current + 24h hourly + 7d daily.
    func fullForecast(for location: CLLocation) async throws -> WeatherBundle {
        let weather = try await fetchWeather(for: location)
        let precipChance = upcomingHour(in: weather)?.precipitationChance ?? 0
        return WeatherBundle(
            current: CurrentWeather(from: weather.currentWeather, precipitationChance: precipChance),
            hourly:  Array(weather.hourlyForecast.prefix(24)).map(HourlyForecast.init(from:)),
            daily:   Array(weather.dailyForecast.prefix(7)).map(DailyForecast.init(from:))
        )
    }

    // MARK: - Private

    private func fetchWeather(for location: CLLocation) async throws -> Weather {
        do {
            return try await kit.weather(for: location)
        } catch {
            throw AppError.weatherFetchFailed(underlying: error)
        }
    }

    /// WeatherKit's CurrentWeather omits precipitation chance — we read it off the next hour.
    private func upcomingHour(in weather: Weather) -> HourWeather? {
        let now = Date.now
        return weather.hourlyForecast.first { $0.date >= now }
            ?? weather.hourlyForecast.first
    }
}
