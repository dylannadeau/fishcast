import Foundation

/// Tracks barometric pressure readings over a rolling 3-hour window.
///
/// Pressure readings are persisted in `UserDefaults` so trend calculation survives
/// app relaunches. Thresholds follow standard meteorological convention:
///
/// - |Δ| > 3 hPa over 3h → rapid rise/fall
/// - 1 hPa < |Δ| ≤ 3    → slow rise/fall
/// - |Δ| ≤ 1            → steady
actor BarometricService {
    static let shared = BarometricService()

    private let defaults: UserDefaults
    private let cacheKey: String
    private let windowHours: TimeInterval = 3 * 3600
    private let pruneBuffer: TimeInterval = 3600   // keep 1h beyond window as grace

    init(
        defaults: UserDefaults = .standard,
        cacheKey: String = "com.fishcast.pressure.readings"
    ) {
        self.defaults = defaults
        self.cacheKey = cacheKey
    }

    /// Records a new reading (hPa/mb) and returns the updated 3-hour trend.
    @discardableResult
    func record(pressureHPa: Double, at date: Date = .now) throws -> PressureTrend {
        var readings = loadReadings()
        readings.append(PressureReading(pressure: pressureHPa, timestamp: date))

        let cutoff = date.addingTimeInterval(-(windowHours + pruneBuffer))
        readings = readings.filter { $0.timestamp > cutoff }

        try saveReadings(readings)
        return computeTrend(readings, at: date)
    }

    /// Convenience for WeatherKit's `Measurement<UnitPressure>`.
    @discardableResult
    func record(pressure: Measurement<UnitPressure>, at date: Date = .now) throws -> PressureTrend {
        let hPa = pressure.converted(to: .hectopascals).value
        return try record(pressureHPa: hPa, at: date)
    }

    /// Current trend based on cached readings, without adding a new one.
    func currentTrend(at date: Date = .now) -> PressureTrend {
        computeTrend(loadReadings(), at: date)
    }

    /// Returns cached readings, most recent first.
    func allReadings() -> [PressureReading] {
        loadReadings().sorted { $0.timestamp > $1.timestamp }
    }

    /// Clears cached readings — useful when the user moves to a new fishing spot.
    func reset() throws {
        try saveReadings([])
    }

    // MARK: - Private

    private func computeTrend(_ readings: [PressureReading], at date: Date) -> PressureTrend {
        let windowStart = date.addingTimeInterval(-windowHours)
        let inWindow = readings.filter { $0.timestamp >= windowStart }

        guard
            let earliest = inWindow.min(by: { $0.timestamp < $1.timestamp }),
            let latest   = inWindow.max(by: { $0.timestamp < $1.timestamp }),
            earliest.timestamp != latest.timestamp
        else {
            return .steady
        }

        let delta = latest.pressure - earliest.pressure
        let magnitude = abs(delta)

        if magnitude <= 1 { return .steady }
        let rising = delta > 0
        if magnitude > 3 { return rising ? .rapidRise : .rapidFall }
        return rising ? .slowRise : .slowFall
    }

    private func loadReadings() -> [PressureReading] {
        guard let data = defaults.data(forKey: cacheKey) else { return [] }
        return (try? JSONDecoder().decode([PressureReading].self, from: data)) ?? []
    }

    private func saveReadings(_ readings: [PressureReading]) throws {
        do {
            let data = try JSONEncoder().encode(readings)
            defaults.set(data, forKey: cacheKey)
        } catch {
            throw AppError.pressureCacheFailed(underlying: error)
        }
    }
}
