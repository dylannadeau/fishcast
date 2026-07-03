import Foundation

enum PressureTrend: String, Codable, Sendable {
    case rapidRise
    case slowRise
    case steady
    case slowFall
    case rapidFall

    var description: String {
        switch self {
        case .rapidRise: return "Rapidly rising"
        case .slowRise:  return "Slowly rising"
        case .steady:    return "Steady"
        case .slowFall:  return "Slowly falling"
        case .rapidFall: return "Rapidly falling"
        }
    }

    var symbolName: String {
        switch self {
        case .rapidRise: return "arrow.up"
        case .slowRise:  return "arrow.up.right"
        case .steady:    return "arrow.right"
        case .slowFall:  return "arrow.down.right"
        case .rapidFall: return "arrow.down"
        }
    }

    /// Standard meteorological classification of a pressure change over a
    /// 3-hour window. Single source of truth for the thresholds used by both
    /// `BarometricService` (device history) and the per-spot dashboard
    /// (WeatherKit hourly history):
    ///
    /// - |Δ| > 3 hPa → rapid rise/fall
    /// - 1 < |Δ| ≤ 3 → slow rise/fall
    /// - |Δ| ≤ 1     → steady
    static func fromThreeHourDelta(hPa delta: Double) -> PressureTrend {
        let magnitude = abs(delta)
        if magnitude <= 1 { return .steady }
        let rising = delta > 0
        if magnitude > 3 { return rising ? .rapidRise : .rapidFall }
        return rising ? .slowRise : .slowFall
    }
}

struct PressureReading: Codable, Sendable {
    let pressure: Double   // hectopascals / millibars (1 hPa == 1 mb)
    let timestamp: Date
}
