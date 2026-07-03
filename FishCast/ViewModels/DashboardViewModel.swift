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

// MARK: - Saved-spot conditions

/// Drives the Dashboard's "Your Spots" section: one WeatherKit fetch per
/// saved spot (current + history + forecast in a single billed request),
/// folded into a cached `SpotConditions` snapshot per spot.
///
/// Failure never blanks a card — the last successful snapshot (in-memory or
/// from `SpotConditionsCache`) stays visible, flagged stale, with a retry.
@MainActor
@Observable
final class SpotConditionsViewModel {

    /// Render state for one spot card.
    struct CardState {
        var isLoading = false
        var conditions: SpotConditions?
        /// Message from the most recent failed fetch; nil after a success.
        var errorMessage: String?
        /// True when `conditions` predate the last attempted refresh.
        var isStale = false
    }

    private(set) var states: [UUID: CardState] = [:]

    /// Skip refetching a spot whose snapshot is younger than this unless
    /// the caller forces (pull-to-refresh). Keeps tab switches from
    /// re-billing WeatherKit.
    private let freshnessWindow: TimeInterval = 10 * 60

    private let weatherService: WeatherService
    private let cache: SpotConditionsCache
    private let moonService: MoonPhaseService

    init(
        weatherService: WeatherService? = nil,
        cache: SpotConditionsCache? = nil,
        moonService: MoonPhaseService? = nil
    ) {
        self.weatherService = weatherService ?? .shared
        self.cache = cache ?? .shared
        self.moonService = moonService ?? .shared
    }

    func state(for spotId: UUID) -> CardState {
        states[spotId] ?? CardState()
    }

    /// Refreshes every spot concurrently. `force` bypasses the freshness
    /// window (pull-to-refresh / explicit retry).
    func loadAll(spots: [FishingSpot], historyDays: Int, force: Bool = false) async {
        cache.prune(keeping: Set(spots.map(\.id)))
        states = states.filter { key, _ in spots.contains(where: { $0.id == key }) }

        await withTaskGroup(of: Void.self) { group in
            for spot in spots {
                group.addTask {
                    await self.load(spot: spot, historyDays: historyDays, force: force)
                }
            }
        }
    }

    /// Fetch + score a single spot. Used for both bulk loads and per-card retry.
    func load(spot: FishingSpot, historyDays: Int, force: Bool = false) async {
        var state = states[spot.id] ?? CardState()

        // Seed from disk so even a cold start with no network shows data.
        if state.conditions == nil, let cached = cache.conditions(for: spot.id) {
            state.conditions = cached
            state.isStale = true
        }

        if !force,
           let existing = state.conditions,
           !state.isStale,
           Date().timeIntervalSince(existing.fetchedAt) < freshnessWindow,
           (existing.history?.windowDays ?? historyDays) == historyDays {
            states[spot.id] = state
            return
        }

        state.isLoading = true
        states[spot.id] = state

        do {
            let location = CLLocation(latitude: spot.latitude, longitude: spot.longitude)
            let weather = try await weatherService.spotForecast(
                for: location, historyDays: historyDays
            )
            let conditions = buildConditions(
                spot: spot, weather: weather, historyDays: historyDays
            )
            cache.save(conditions)
            states[spot.id] = CardState(
                isLoading: false,
                conditions: conditions,
                errorMessage: nil,
                isStale: false
            )
        } catch {
            var failed = states[spot.id] ?? CardState()
            failed.isLoading = false
            failed.errorMessage = (error as? LocalizedError)?.errorDescription
                ?? error.localizedDescription
            failed.isStale = failed.conditions != nil
            states[spot.id] = failed
        }
    }

    // MARK: - Snapshot assembly

    private func buildConditions(
        spot: FishingSpot,
        weather: SpotWeather,
        historyDays: Int,
        now: Date = .now
    ) -> SpotConditions {
        let current = weather.bundle.current
        let currentPressureHPa = current.pressure.converted(to: .hectopascals).value

        // Pressure trend from this spot's own trailing 3 hours.
        let trend = spotPressureTrend(
            history: weather.historyHourly,
            currentPressureHPa: currentPressureHPa,
            now: now
        )

        // Trailing-window averages.
        var history: SpotConditions.History?
        if !weather.historyHourly.isEmpty {
            let temps = weather.historyHourly.map {
                $0.temperature.converted(to: .fahrenheit).value
            }
            let pressures = weather.historyHourly.map {
                $0.pressure.converted(to: .hectopascals).value
            }
            let avgTemp = temps.reduce(0, +) / Double(temps.count)
            let avgPressure = pressures.reduce(0, +) / Double(pressures.count)
            let currentTempF = current.temperature.converted(to: .fahrenheit).value
            history = SpotConditions.History(
                windowDays: historyDays,
                avgTempF: avgTemp,
                avgPressureHPa: avgPressure,
                tempDeltaF: currentTempF - avgTemp,
                pressureDeltaHPa: currentPressureHPa - avgPressure
            )
        }

        let outlook = buildOutlook(
            bundle: weather.bundle,
            currentPressureHPa: currentPressureHPa
        )

        // Species + overall score for today at this spot.
        let today = weather.bundle.daily.first
        let moonInfo = moonService.info(for: now, at: spot.coordinate)
        let ranked = FishingConditionsEngine.daySpeciesOutlook(
            weather: current,
            trend: trend,
            now: now,
            hourlyForecast: weather.bundle.hourly,
            moonInfo: moonInfo,
            sunrise: today?.sunrise,
            sunset: today?.sunset
        )
        let score = FishingConditionsEngine.computeScore(
            weather: current,
            trend: trend,
            date: now,
            hourlyForecast: weather.bundle.hourly,
            moonInfo: moonInfo,
            sunrise: today?.sunrise,
            sunset: today?.sunset
        )

        return SpotConditions(
            spotId: spot.id,
            fetchedAt: now,
            current: SpotConditions.Current(
                tempF: current.temperature.converted(to: .fahrenheit).value,
                feelsLikeF: current.apparentTemperature.converted(to: .fahrenheit).value,
                pressureHPa: currentPressureHPa,
                windMph: current.windSpeed.converted(to: .milesPerHour).value,
                windCompass: compassPoint(current.windDirection),
                humidity: current.humidity,
                precipChance: current.precipitationChance,
                conditionDescription: current.conditionDescription,
                symbolName: current.symbolName
            ),
            pressureTrend: trend,
            history: history,
            outlook: outlook,
            score: score.score,
            summary: score.summary,
            mostLikely: Array(ranked.prefix(3)),
            leastLikely: ranked.count > 3
                ? Array(ranked.suffix(min(3, ranked.count - 3)).reversed())
                : []
        )
    }

    /// Classifies the spot's 3-hour pressure change using the same
    /// thresholds as `BarometricService`, but sourced from WeatherKit's
    /// hourly history for the spot's coordinates.
    private func spotPressureTrend(
        history: [HourlyForecast],
        currentPressureHPa: Double,
        now: Date
    ) -> PressureTrend {
        let target = now.addingTimeInterval(-3 * 3600)
        guard let reference = history.min(by: {
            abs($0.date.timeIntervalSince(target)) < abs($1.date.timeIntervalSince(target))
        }), abs(reference.date.timeIntervalSince(target)) <= 2 * 3600 else {
            return .steady
        }
        let referenceHPa = reference.pressure.converted(to: .hectopascals).value
        return PressureTrend.fromThreeHourDelta(hPa: currentPressureHPa - referenceHPa)
    }

    /// Next few daily entries with hourly-averaged forecast pressure. The
    /// hourly horizon is 72h, so later days legitimately have nil pressure.
    private func buildOutlook(
        bundle: WeatherBundle,
        currentPressureHPa: Double
    ) -> [SpotConditions.OutlookDay] {
        let calendar = Calendar.current
        var previousPressure: Double? = currentPressureHPa

        return bundle.daily.prefix(4).map { day in
            let dayPressures = bundle.hourly
                .filter { calendar.isDate($0.date, inSameDayAs: day.date) }
                .map { $0.pressure.converted(to: .hectopascals).value }
            let avgPressure = dayPressures.isEmpty
                ? nil
                : dayPressures.reduce(0, +) / Double(dayPressures.count)

            let delta: Double?
            if let avgPressure, let previous = previousPressure {
                delta = avgPressure - previous
            } else {
                delta = nil
            }
            if let avgPressure { previousPressure = avgPressure }

            return SpotConditions.OutlookDay(
                date: day.date,
                highF: day.highTemperature.converted(to: .fahrenheit).value,
                lowF: day.lowTemperature.converted(to: .fahrenheit).value,
                avgPressureHPa: avgPressure,
                pressureDeltaHPa: delta,
                symbolName: day.symbolName
            )
        }
    }

    private func compassPoint(_ direction: Measurement<UnitAngle>) -> String {
        let points = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
        let degrees = direction.converted(to: .degrees).value
        let normalized = (degrees.truncatingRemainder(dividingBy: 360) + 360)
            .truncatingRemainder(dividingBy: 360)
        let index = Int((normalized / 45).rounded()) % points.count
        return points[index]
    }
}
