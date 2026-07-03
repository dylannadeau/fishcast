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

    /// Single WeatherKit request returning current + N-hour hourly + 7d daily.
    /// Hourly default is 72h — enough for the Dashboard's 48h "next best
    /// window" search and its 3-day outlook hour rolls.
    func fullForecast(for location: CLLocation, hourlyHours: Int = 72) async throws -> WeatherBundle {
        let weather = try await fetchWeather(for: location)
        let precipChance = upcomingHour(in: weather)?.precipitationChance ?? 0
        return WeatherBundle(
            current: CurrentWeather(from: weather.currentWeather, precipitationChance: precipChance),
            hourly:  Array(weather.hourlyForecast.prefix(hourlyHours)).map(HourlyForecast.init(from:)),
            daily:   Array(weather.dailyForecast.prefix(7)).map(DailyForecast.init(from:))
        )
    }

    /// Everything a spot card needs in one billed WeatherKit request:
    /// current conditions, hourly spanning `historyDays` back through 72h
    /// ahead, and the 7-day daily forecast. History powers the "vs recent
    /// average" comparison and the per-spot pressure trend.
    func spotForecast(
        for location: CLLocation,
        historyDays: Int = 7,
        hourlyHours: Int = 72
    ) async throws -> SpotWeather {
        let now = Date.now
        // WeatherKit caps a single hourly query around 10 days — clamp so
        // history + 3-day forecast stays inside the envelope.
        let clampedDays = max(1, min(historyDays, 7))
        let historyStart = Calendar.current.startOfDay(for: now)
            .addingTimeInterval(TimeInterval(-clampedDays * 86_400))
        let hourlyEnd = now.addingTimeInterval(TimeInterval(hourlyHours) * 3600)

        do {
            let (current, hourly, daily) = try await kit.weather(
                for: location,
                including: .current,
                .hourly(startDate: historyStart, endDate: hourlyEnd),
                .daily
            )
            let allHours = hourly.map(HourlyForecast.init(from:))
            let history = allHours.filter { $0.date < now }
            // Keep the in-progress hour at the head of the forward slice.
            let upcoming = allHours.filter { $0.date >= now.addingTimeInterval(-3600) }
            let precipChance = upcoming.first(where: { $0.date >= now })?.precipitationChance
                ?? upcoming.first?.precipitationChance
                ?? 0

            return SpotWeather(
                bundle: WeatherBundle(
                    current: CurrentWeather(from: current, precipitationChance: precipChance),
                    hourly:  Array(upcoming.prefix(hourlyHours)),
                    daily:   Array(daily.prefix(7)).map(DailyForecast.init(from:))
                ),
                historyHourly: history
            )
        } catch {
            throw mapWeatherError(error)
        }
    }

    // MARK: - Private

    private func fetchWeather(for location: CLLocation) async throws -> Weather {
        do {
            return try await kit.weather(for: location)
        } catch {
            throw mapWeatherError(error)
        }
    }

    /// WeatherKit auth failures (`WDSJWTAuthenticationError` from
    /// WeatherDaemon) mean the app isn't provisioned for WeatherKit — a
    /// setup problem, not a network one. Surface a targeted message so the
    /// user isn't left retrying something that can't succeed.
    private func mapWeatherError(_ error: Error) -> AppError {
        let ns = error as NSError
        let signature = "\(ns.domain) \(String(describing: error))".lowercased()
        if signature.contains("jwtauthentication")
            || signature.contains("jwtauthenticator") {
            return .weatherKitNotAuthorized
        }
        return .weatherFetchFailed(underlying: error)
    }

    /// WeatherKit's CurrentWeather omits precipitation chance — we read it off the next hour.
    private func upcomingHour(in weather: Weather) -> HourWeather? {
        let now = Date.now
        return weather.hourlyForecast.first { $0.date >= now }
            ?? weather.hourlyForecast.first
    }
}
