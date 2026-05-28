import CoreLocation
import Foundation
import Observation
import WidgetKit

/// Orchestrates the Dashboard screen: location → weather → pressure → score.
/// Uses the iOS 17 `@Observable` macro; views consume published state directly.
///
/// Caching strategy: a failed refresh never clears previously-loaded data, so
/// the UI stays useful (with a "Last updated X min ago" hint) while the user
/// is on bad connectivity. `lastError` surfaces the failure independently of
/// `loadState` so we can show a transient banner without re-rendering loading
/// skeletons over good data.
@MainActor
@Observable
final class DashboardViewModel {

    enum LoadState: Equatable {
        case idle
        case loading
        case loaded
        case failed(String)
    }

    /// Score for a single hour in the rolling 72-hour forecast.
    struct HourlyScore: Identifiable, Sendable {
        let id: Date
        let hour: HourlyForecast
        let score: FishingScore

        /// Whether `hour` falls within ±1h of sunrise/sunset.
        let isGoldenHour: Bool
        /// Whether `hour` is inside a solunar major window.
        let isSolunarMajor: Bool
    }

    // MARK: State

    var loadState: LoadState = .idle
    var locationName: String?
    var coordinate: CLLocationCoordinate2D?
    var weather: WeatherBundle?
    var fishingScore: FishingScore?
    var pressureTrend: PressureTrend = .steady
    var pressureReadings: [PressureReading] = []
    /// All hourly scores within the available forecast window (72h by default).
    var hourlyScores: [HourlyScore] = []
    var speciesPredictions: [SpeciesPrediction] = []
    var moon: MoonInfo?
    var sunrise: Date?
    var sunset: Date?

    /// Last time `load()` or `refreshConditions()` completed successfully.
    var lastUpdatedAt: Date?
    /// Transient error from the most recent fetch. Cleared on next success.
    var lastError: String?

    // MARK: Dependencies

    private let locationService: LocationService
    private let weatherService: WeatherService
    private let barometricService: BarometricService
    private let moonService: MoonPhaseService
    private let geocoder = CLGeocoder()

    init(
        locationService: LocationService? = nil,
        weatherService: WeatherService? = nil,
        barometricService: BarometricService? = nil,
        moonService: MoonPhaseService? = nil
    ) {
        self.locationService = locationService ?? .shared
        self.weatherService = weatherService ?? .shared
        self.barometricService = barometricService ?? .shared
        self.moonService = moonService ?? .shared
    }

    // MARK: Public entry points

    /// Cold-start loader. Shows a loading skeleton while running.
    func load() async {
        loadState = .loading
        await runFetch()
    }

    /// Foreground / pull-to-refresh / explicit refresh button. Doesn't
    /// downgrade `loadState` to `.loading` — the existing data stays on
    /// screen while the new fetch runs.
    func refreshConditions() async {
        await runFetch()
    }

    // MARK: Loading

    private func runFetch() async {
        do {
            _ = await locationService.requestWhenInUseAuthorization()
            let location = try await locationService.requestCurrentLocation()
            self.coordinate = location.coordinate

            async let placemarkTask: String? = reverseGeocode(location)
            async let forecastTask = weatherService.fullForecast(for: location)

            let bundle = try await forecastTask
            let placeName = await placemarkTask

            let trend = try await barometricService.record(pressure: bundle.current.pressure)
            let readings = await barometricService.allReadings()

            let now = Date()
            let moonInfo = moonService.info(for: now, at: location.coordinate)
            let today = bundle.daily.first
            let score = FishingConditionsEngine.computeScore(
                weather: bundle.current,
                trend: trend,
                date: now,
                hourlyForecast: bundle.hourly,
                moonInfo: moonInfo,
                sunrise: today?.sunrise,
                sunset: today?.sunset
            )
            let scoredHours = computeHourlyScores(
                bundle: bundle, trend: trend, moonInfo: moonInfo
            )

            self.locationName = placeName
            self.weather = bundle
            self.fishingScore = score
            self.pressureTrend = trend
            self.pressureReadings = readings
            self.hourlyScores = scoredHours
            self.speciesPredictions = score.topSpecies
            self.moon = moonInfo
            self.sunrise = today?.sunrise
            self.sunset = today?.sunset
            self.lastUpdatedAt = now
            self.lastError = nil
            self.loadState = .loaded

            updateWidgetSnapshot(
                score: score, hourlyScores: scoredHours, locationName: placeName
            )
        } catch {
            let message = (error as? LocalizedError)?.errorDescription
                ?? error.localizedDescription
            self.lastError = message
            // Only flip to `.failed` if we had no prior data — otherwise the
            // UI shows the cached state with a transient error banner.
            if self.fishingScore == nil {
                self.loadState = .failed(message)
            }
        }
    }

    // MARK: Derived state

    /// Hourly scores filtered to a given calendar day.
    func hourlyScores(on date: Date, calendar: Calendar = .current) -> [HourlyScore] {
        let start = calendar.startOfDay(for: date)
        let end = start.addingTimeInterval(24 * 3600)
        return hourlyScores.filter { $0.hour.date >= start && $0.hour.date < end }
    }

    /// Today's hourly scores — kept as a property for the timeline view that
    /// always wants "now plus the rest of today".
    var todaysHourlyScores: [HourlyScore] {
        hourlyScores(on: Date())
    }

    /// Best hour within a given day (highest-scoring), if any.
    func bestHour(on date: Date) -> HourlyScore? {
        hourlyScores(on: date).max(by: { $0.score.score < $1.score.score })
    }

    /// Maps each hour's date to its overall score (handy for charts).
    var hourlyScoreMap: [Date: Int] {
        Dictionary(uniqueKeysWithValues: hourlyScores.map { ($0.hour.date, $0.score.score) })
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

    private func computeHourlyScores(
        bundle: WeatherBundle,
        trend: PressureTrend,
        moonInfo: MoonInfo
    ) -> [HourlyScore] {
        let today = bundle.daily.first
        let solunarMajors = solunarMajorWindows(moon: moonInfo)

        return bundle.hourly.map { hour in
            let dayMatch = bundle.daily.first(where: {
                Calendar.current.isDate($0.date, inSameDayAs: hour.date)
            }) ?? today
            let sunrise = dayMatch?.sunrise
            let sunset = dayMatch?.sunset

            let synthetic = synthesizeCurrent(from: bundle.current, at: hour)
            let score = FishingConditionsEngine.computeScore(
                weather: synthetic,
                trend: trend,
                date: hour.date,
                moonInfo: moonInfo,
                sunrise: sunrise,
                sunset: sunset
            )
            return HourlyScore(
                id: hour.date,
                hour: hour,
                score: score,
                isGoldenHour: isInGoldenHour(hour.date, sunrise: sunrise, sunset: sunset),
                isSolunarMajor: solunarMajors.contains(where: { window in
                    window.contains(hour.date)
                })
            )
        }
    }

    /// A solunar major period sits ±1h around the moon being overhead or
    /// underfoot. We approximate "underfoot" as the rise/set time ±12h.
    private func solunarMajorWindows(moon: MoonInfo) -> [DateInterval] {
        let anchors: [Date] = [moon.moonrise, moon.moonset]
            .compactMap { $0 }
            .flatMap { [$0, $0.addingTimeInterval(12 * 3600), $0.addingTimeInterval(-12 * 3600)] }
        return anchors.map {
            DateInterval(start: $0.addingTimeInterval(-3600), end: $0.addingTimeInterval(3600))
        }
    }

    private func isInGoldenHour(_ date: Date, sunrise: Date?, sunset: Date?) -> Bool {
        guard let sunrise, let sunset else {
            let hour = Calendar.current.component(.hour, from: date)
            return (5...7).contains(hour) || (18...20).contains(hour)
        }
        let dawnEnd = sunrise.addingTimeInterval(3600)
        let duskStart = sunset.addingTimeInterval(-3600)
        return (sunrise...dawnEnd).contains(date)
            || (duskStart...sunset).contains(date)
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
