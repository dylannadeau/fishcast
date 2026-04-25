import CoreLocation
import Foundation
import Observation
import WidgetKit

/// Orchestrates the Dashboard screen: location → weather → pressure → score.
/// Uses the iOS 17 `@Observable` macro; views consume published state directly.
@MainActor
@Observable
final class DashboardViewModel {

    enum LoadState: Equatable {
        case idle
        case loading
        case loaded
        case failed(String)
    }

    /// Score for a single hour in the current day's forecast.
    struct HourlyScore: Identifiable {
        let id: Date
        let hour: HourlyForecast
        let score: FishingScore
    }

    // MARK: State

    var loadState: LoadState = .idle
    var locationName: String?
    var weather: WeatherBundle?
    var fishingScore: FishingScore?
    var pressureTrend: PressureTrend = .steady
    var pressureReadings: [PressureReading] = []
    var hourlyScores: [HourlyScore] = []
    var speciesPredictions: [SpeciesPrediction] = []

    // MARK: Dependencies

    private let locationService: LocationService
    private let weatherService: WeatherService
    private let barometricService: BarometricService
    private let geocoder = CLGeocoder()

    init(
        locationService: LocationService = .shared,
        weatherService: WeatherService = .shared,
        barometricService: BarometricService = .shared
    ) {
        self.locationService = locationService
        self.weatherService = weatherService
        self.barometricService = barometricService
    }

    // MARK: Loading

    func load() async {
        loadState = .loading
        do {
            _ = await locationService.requestWhenInUseAuthorization()
            let location = try await locationService.requestCurrentLocation()

            async let placemarkTask: String? = reverseGeocode(location)
            async let forecastTask = weatherService.fullForecast(for: location)

            let bundle = try await forecastTask
            let placeName = await placemarkTask

            let trend = try await barometricService.record(pressure: bundle.current.pressure)
            let readings = await barometricService.allReadings()

            let now = Date()
            let score = FishingConditionsEngine.computeScore(
                weather: bundle.current, trend: trend, date: now
            )
            let today = todayHourlyScores(bundle: bundle, trend: trend, now: now)
            let bets = FishingConditionsEngine.speciesRecommendations(
                weather: bundle.current, trend: trend, date: now, topN: 3
            )

            self.locationName = placeName
            self.weather = bundle
            self.fishingScore = score
            self.pressureTrend = trend
            self.pressureReadings = readings
            self.hourlyScores = today
            self.speciesPredictions = bets
            self.loadState = .loaded

            updateWidgetSnapshot(score: score, hourlyScores: today, locationName: placeName)
        } catch {
            let message = (error as? LocalizedError)?.errorDescription
                ?? error.localizedDescription
            self.loadState = .failed(message)
        }
    }

    // MARK: Helpers

    private func reverseGeocode(_ location: CLLocation) async -> String? {
        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            guard let placemark = placemarks.first else { return nil }
            return placemark.locality
                ?? placemark.subLocality
                ?? placemark.administrativeArea
                ?? placemark.name
        } catch {
            // Reverse geocoding failures aren't fatal — surface coordinates as fallback.
            return nil
        }
    }

    private func todayHourlyScores(
        bundle: WeatherBundle,
        trend: PressureTrend,
        now: Date
    ) -> [HourlyScore] {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: now)
        let dayEnd = dayStart.addingTimeInterval(24 * 3600)

        return bundle.hourly
            .filter { $0.date >= dayStart && $0.date < dayEnd }
            .map { hour in
                let synthetic = synthesizeCurrent(from: bundle.current, at: hour)
                let score = FishingConditionsEngine.computeScore(
                    weather: synthetic, trend: trend, date: hour.date
                )
                return HourlyScore(id: hour.date, hour: hour, score: score)
            }
    }

    /// Pushes a compact snapshot to the App Group so the widget can render
    /// without having to make its own WeatherKit call. Best-effort — failure
    /// here is silent because the widget gracefully shows a placeholder.
    private func updateWidgetSnapshot(
        score: FishingScore,
        hourlyScores: [HourlyScore],
        locationName: String?
    ) {
        let now = Date()
        let upcoming = hourlyScores.filter { $0.hour.date >= now }
        let peak = upcoming.max(by: { $0.score.score < $1.score.score })
        let topFactor = score.factors
            .filter { $0.impact == .positive }
            .first?.name

        let snapshot = WidgetSnapshot(
            score: score.score,
            rating: score.rating.label,
            summary: score.summary,
            locationName: locationName,
            bestHour: peak.map { Calendar.current.component(.hour, from: $0.hour.date) },
            bestHourScore: peak?.score.score,
            topFactor: topFactor,
            updatedAt: now
        )
        WidgetStorage.save(snapshot)
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Hourly forecasts don't include pressure/humidity/UV, so we reuse the
    /// current-conditions values and let the hour-specific wind/temp/precip
    /// drive the variance across the day.
    private func synthesizeCurrent(
        from current: CurrentWeather,
        at hour: HourlyForecast
    ) -> CurrentWeather {
        CurrentWeather(
            date: hour.date,
            temperature: hour.temperature,
            apparentTemperature: hour.temperature,
            humidity: current.humidity,
            windSpeed: hour.windSpeed,
            windDirection: hour.windDirection,
            windGust: nil,
            uvIndex: current.uvIndex,
            visibility: current.visibility,
            precipitationChance: hour.precipitationChance,
            pressure: current.pressure,
            conditionDescription: hour.conditionDescription,
            symbolName: hour.symbolName
        )
    }
}
