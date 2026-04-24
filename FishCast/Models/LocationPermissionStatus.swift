import CoreLocation

enum LocationPermissionStatus: Sendable {
    case notDetermined
    case restricted
    case denied
    case authorizedWhenInUse
    case authorizedAlways

    init(_ status: CLAuthorizationStatus) {
        switch status {
        case .notDetermined:       self = .notDetermined
        case .restricted:          self = .restricted
        case .denied:              self = .denied
        case .authorizedWhenInUse: self = .authorizedWhenInUse
        case .authorizedAlways:    self = .authorizedAlways
        @unknown default:          self = .notDetermined
        }
    }

    var isAuthorized: Bool {
        self == .authorizedAlways || self == .authorizedWhenInUse
    }
}
