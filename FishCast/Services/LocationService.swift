import CoreLocation
import Combine

@MainActor
final class LocationService: NSObject, ObservableObject {
    static let shared = LocationService()

    @Published private(set) var currentLocation: CLLocation?
    @Published private(set) var permissionStatus: LocationPermissionStatus = .notDetermined

    private let manager = CLLocationManager()
    private var locationContinuations: [CheckedContinuation<CLLocation, Error>] = []
    private var permissionContinuations: [CheckedContinuation<LocationPermissionStatus, Never>] = []

    private override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        permissionStatus = LocationPermissionStatus(manager.authorizationStatus)
    }

    /// Prompts for When-In-Use authorization. Returns immediately if already determined.
    @discardableResult
    func requestWhenInUseAuthorization() async -> LocationPermissionStatus {
        if permissionStatus != .notDetermined { return permissionStatus }
        return await withCheckedContinuation { continuation in
            permissionContinuations.append(continuation)
            manager.requestWhenInUseAuthorization()
        }
    }

    /// Prompts for Always authorization. Must usually be preceded by When-In-Use.
    @discardableResult
    func requestAlwaysAuthorization() async -> LocationPermissionStatus {
        if permissionStatus == .authorizedAlways { return permissionStatus }
        return await withCheckedContinuation { continuation in
            permissionContinuations.append(continuation)
            manager.requestAlwaysAuthorization()
        }
    }

    /// One-shot current location. Throws `AppError.locationPermissionDenied` without permission.
    func requestCurrentLocation() async throws -> CLLocation {
        guard permissionStatus.isAuthorized else { throw AppError.locationPermissionDenied }
        return try await withCheckedThrowingContinuation { continuation in
            locationContinuations.append(continuation)
            manager.requestLocation()
        }
    }

    func startUpdatingLocation() throws {
        guard permissionStatus.isAuthorized else { throw AppError.locationPermissionDenied }
        manager.startUpdatingLocation()
    }

    func stopUpdatingLocation() {
        manager.stopUpdatingLocation()
    }
}

// MARK: - CLLocationManagerDelegate
// Delegate callbacks are nonisolated and hop to the main actor to mutate state.

extension LocationService: CLLocationManagerDelegate {

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let newStatus = LocationPermissionStatus(manager.authorizationStatus)
        Task { @MainActor in
            self.permissionStatus = newStatus
            let waiting = self.permissionContinuations
            self.permissionContinuations.removeAll()
            waiting.forEach { $0.resume(returning: newStatus) }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let latest = locations.last else { return }
        Task { @MainActor in
            self.currentLocation = latest
            let waiting = self.locationContinuations
            self.locationContinuations.removeAll()
            waiting.forEach { $0.resume(returning: latest) }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            let waiting = self.locationContinuations
            self.locationContinuations.removeAll()
            waiting.forEach { $0.resume(throwing: AppError.locationUnavailable) }
        }
    }
}
