import Foundation

enum AppError: LocalizedError {
    case locationPermissionDenied
    case locationServicesDisabled
    case locationUnavailable
    case weatherFetchFailed(underlying: Error)
    case weatherKitNotAuthorized
    case weatherUnavailable
    case pressureDataUnavailable
    case pressureCacheFailed(underlying: Error)
    case missingEntitlement(String)
    case tideFetchFailed(underlying: Error?)
    case tideStationUnavailable

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
        case .weatherKitNotAuthorized:
            return "Apple hasn't authorized this app for WeatherKit yet. Verify the WeatherKit capability is enabled for the App ID in the Developer portal, then wait up to 30 minutes for tokens to propagate."
        case .weatherUnavailable:
            return "Weather data is not available for this location."
        case .pressureDataUnavailable:
            return "Barometric pressure data is not available."
        case .pressureCacheFailed(let underlying):
            return "Failed to cache pressure readings: \(underlying.localizedDescription)"
        case .missingEntitlement(let name):
            return "Missing required entitlement: \(name). Enable it in Signing & Capabilities."
        case .tideFetchFailed(let underlying):
            if let underlying { return "Tide fetch failed: \(underlying.localizedDescription)" }
            return "Tide data is currently unavailable."
        case .tideStationUnavailable:
            return "No NOAA tide station is close enough for tide predictions here."
        }
    }
}
