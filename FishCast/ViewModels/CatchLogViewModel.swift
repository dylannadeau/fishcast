import CoreLocation
import Foundation

/// Drives the Log tab: filtering, sorting, and (for new entries) the
/// best-effort weather snapshot capture at log time.
@MainActor
@Observable
final class CatchLogViewModel {

    enum SortOrder: String, CaseIterable, Identifiable {
        case newest, oldest, heaviest
        var id: String { rawValue }
        var label: String {
            switch self {
            case .newest:   return "Newest"
            case .oldest:   return "Oldest"
            case .heaviest: return "Heaviest"
            }
        }
    }

    // MARK: Filters

    var speciesFilter: String?            // nil = all species
    var spotFilter: UUID?                 // nil = all spots
    var sortOrder: SortOrder = .newest

    // MARK: Dependencies

    private let weatherService: WeatherService
    private let locationService: LocationService
    private let moonService: MoonPhaseService

    init(
        weatherService: WeatherService = .shared,
        locationService: LocationService = .shared,
        moonService: MoonPhaseService = .shared
    ) {
        self.weatherService = weatherService
        self.locationService = locationService
        self.moonService = moonService
    }

    // MARK: Filtered + sorted output

    func displayedCatches(from catches: [CatchEntry]) -> [CatchEntry] {
        var filtered = catches
        if let species = speciesFilter {
            filtered = filtered.filter { $0.species == species }
        }
        if let spotId = spotFilter {
            filtered = filtered.filter { $0.spotId == spotId }
        }
        switch sortOrder {
        case .newest:   filtered.sort { $0.date > $1.date }
        case .oldest:   filtered.sort { $0.date < $1.date }
        case .heaviest: filtered.sort { ($0.weight ?? 0) > ($1.weight ?? 0) }
        }
        return filtered
    }

    /// Distinct species names in the catch log — used to populate the filter chips.
    func availableSpecies(from catches: [CatchEntry]) -> [String] {
        Array(Set(catches.map { $0.species })).sorted()
    }

    func resetFilters() {
        speciesFilter = nil
        spotFilter = nil
        sortOrder = .newest
    }

    // MARK: Weather snapshot capture

    /// Best-effort snapshot of conditions at the given location (or device
    /// location if none is provided). Returns nil silently on any failure —
    /// the user can still log the catch without weather data.
    func captureWeatherSnapshot(at coordinate: CLLocationCoordinate2D? = nil) async -> WeatherSnapshot? {
        let location: CLLocation
        if let coordinate {
            location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        } else if let current = try? await locationService.requestCurrentLocation() {
            location = current
        } else {
            return nil
        }

        guard let current = try? await weatherService.currentConditions(for: location) else {
            return nil
        }
        let moon = moonService.info(for: .now, at: location.coordinate).phase
        return WeatherSnapshot(from: current, moonPhase: moon)
    }
}
