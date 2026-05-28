import CoreLocation
import Foundation

/// Drives the Forecast tab — pulls 7-day weather, computes a per-day fishing
/// score, plus moon + tide info. Tide is best-effort: inland coordinates
/// surface as `tide == nil`, and the view hides the section.
@MainActor
@Observable
final class ForecastViewModel {

    enum LoadState: Equatable {
        case idle
        case loading
        case loaded
        case failed(String)
    }

    /// One day in the 7-day forecast row.
    struct DailyEntry: Identifiable, Sendable {
        var id: Date { day.date }
        let day: DailyForecast
        let score: FishingScore
    }

    // MARK: State

    var loadState: LoadState = .idle
    var dailyEntries: [DailyEntry] = []
    var moon: MoonInfo?
    var tide: TideForecast?
    var coordinate: CLLocationCoordinate2D?

    // MARK: Dependencies

    private let locationService: LocationService
    private let weatherService: WeatherService
    private let barometricService: BarometricService
    private let moonService: MoonPhaseService
    private let tideService: TideService

    init(
        locationService: LocationService? = nil,
        weatherService: WeatherService? = nil,
        barometricService: BarometricService? = nil,
        moonService: MoonPhaseService? = nil,
        tideService: TideService? = nil
    ) {
        self.locationService = locationService ?? .shared
        self.weatherService = weatherService ?? .shared
        self.barometricService = barometricService ?? .shared
        self.moonService = moonService ?? .shared
        self.tideService = tideService ?? .shared
    }

    // MARK: Loading

    func load() async {
        loadState = .loading
        do {
            _ = await locationService.requestWhenInUseAuthorization()
            let location = try await locationService.requestCurrentLocation()
            self.coordinate = location.coordinate

            async let bundleTask = weatherService.fullForecast(for: location)
            async let tideTask: TideForecast? =
                tideService.forecast(near: location.coordinate)

            let bundle = try await bundleTask
            let trend = await barometricService.currentTrend()

            let moonInfo = moonService.info(for: .now, at: location.coordinate)
            let entries = computeDailyEntries(
                bundle: bundle, trend: trend, moonInfo: moonInfo
            )
            let tideForecast = (try? await tideTask) ?? nil

            self.dailyEntries = entries
            self.moon = moonInfo
            self.tide = tideForecast
            self.loadState = .loaded
        } catch {
            let message = (error as? LocalizedError)?.errorDescription
                ?? error.localizedDescription
            self.loadState = .failed(message)
        }
    }

    // MARK: Daily score synthesis

    private func computeDailyEntries(
        bundle: WeatherBundle,
        trend: PressureTrend,
        moonInfo: MoonInfo
    ) -> [DailyEntry] {
        bundle.daily.map { day in
            let synthetic = synthesizeCurrent(from: bundle.current, day: day)
            // Score for noon — represents the day's average daytime conditions.
            let noon = noonOfDay(day.date)
            let score = FishingConditionsEngine.computeScore(
                weather: synthetic,
                trend: trend,
                date: noon,
                moonInfo: moonInfo,
                sunrise: day.sunrise,
                sunset: day.sunset
            )
            return DailyEntry(day: day, score: score)
        }
    }

    /// Builds a `CurrentWeather` from a `DailyForecast` — daily-specific
    /// fields drive the variance, current conditions fill in pressure /
    /// humidity / UV that aren't in the daily payload.
    private func synthesizeCurrent(
        from current: CurrentWeather,
        day: DailyForecast
    ) -> CurrentWeather {
        let avgTemp = Measurement<UnitTemperature>(
            value: (day.highTemperature.converted(to: .fahrenheit).value
                  + day.lowTemperature.converted(to: .fahrenheit).value) / 2,
            unit: .fahrenheit
        )
        return CurrentWeather(
            date: day.date,
            temperature: avgTemp,
            apparentTemperature: avgTemp,
            humidity: current.humidity,
            windSpeed: day.windSpeed,
            windDirection: day.windDirection,
            windGust: nil,
            uvIndex: current.uvIndex,
            visibility: current.visibility,
            precipitationChance: day.precipitationChance,
            pressure: current.pressure,
            conditionDescription: day.conditionDescription,
            symbolName: day.symbolName
        )
    }

    private func noonOfDay(_ date: Date) -> Date {
        let calendar = Calendar.current
        return calendar.date(
            bySettingHour: 12, minute: 0, second: 0, of: date
        ) ?? date
    }
}
