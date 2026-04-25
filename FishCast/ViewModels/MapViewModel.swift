import CoreLocation
import MapKit
import SwiftUI

/// Owns all Map-tab UI state: camera, search, active selection, and the
/// long-press draft coordinate. Scoring for a tapped spot is fetched
/// on demand since WeatherKit is per-request billed.
@MainActor
@Observable
final class MapViewModel {

    /// Identifiable wrapper so `.sheet(item:)` can bind to a coordinate.
    struct DraftCoordinate: Identifiable {
        let id = UUID()
        let coordinate: CLLocationCoordinate2D
    }

    // MARK: State

    var cameraPosition: MapCameraPosition = .userLocation(fallback: .automatic)
    var searchQuery: String = ""
    var selectedSpot: FishingSpot?
    var draftCoordinate: DraftCoordinate?

    // MARK: Dependencies

    private let weatherService: WeatherService
    private let barometricService: BarometricService

    init(
        weatherService: WeatherService = .shared,
        barometricService: BarometricService = .shared
    ) {
        self.weatherService = weatherService
        self.barometricService = barometricService
    }

    // MARK: Filtering

    func filteredSpots(from spots: [FishingSpot]) -> [FishingSpot] {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return spots }
        return spots.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }

    // MARK: Actions

    func focus(on spot: FishingSpot) {
        withAnimation(.appSpring) {
            cameraPosition = .region(
                MKCoordinateRegion(
                    center: spot.coordinate,
                    latitudinalMeters: 3_000,
                    longitudinalMeters: 3_000
                )
            )
        }
        searchQuery = ""
    }

    func startDraft(at coordinate: CLLocationCoordinate2D) {
        draftCoordinate = DraftCoordinate(coordinate: coordinate)
    }

    // MARK: Per-spot score

    /// Computes the current fishing score at a given coordinate. Uses the
    /// cached 3h pressure trend — we don't record a new reading here because
    /// the user isn't necessarily at that spot.
    func fishingScore(for coordinate: CLLocationCoordinate2D) async -> FishingScore? {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        do {
            let current = try await weatherService.currentConditions(for: location)
            let trend = await barometricService.currentTrend()
            return FishingConditionsEngine.computeScore(
                weather: current, trend: trend, date: .now
            )
        } catch {
            return nil
        }
    }
}
