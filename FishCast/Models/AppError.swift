import Foundation

enum AppError: LocalizedError {
    case locationPermissionDenied
    case locationServicesDisabled
    case locationUnavailable
    case weatherFetchFailed(underlying: Error)
    case weatherUnavailable
    case pressureDataUnavailable
    case pressureCacheFailed(underlying: Error)
    case missingEntitlement(String)

    var errorDescription: String? {
        switch self {
        case .locationPermissionDenied:
            return "Location permission is required to fetch local fishing conditions."
        case .locationServicesDisabled:
            return "Location services are disabled. Enable them in Settings."
        case .locationUnavailable:
            return "Unable to determine your current location."
        case .weatherFetchFailed(let underlying):
            return "Weather fetch failed: \(underlying.localizedDescription)"
        case .weatherUnavailable:
            return "Weather data is not available for this location."
        case .pressureDataUnavailable:
            return "Barometric pressure data is not available."
        case .pressureCacheFailed(let underlying):
            return "Failed to cache pressure readings: \(underlying.localizedDescription)"
        case .missingEntitlement(let name):
            return "Missing required entitlement: \(name). Enable it in Signing & Capabilities."
        }
    }
}
