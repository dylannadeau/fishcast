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
}

struct PressureReading: Codable, Sendable {
    let pressure: Double   // hectopascals / millibars (1 hPa == 1 mb)
    let timestamp: Date
}
