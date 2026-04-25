import CoreLocation
import Foundation

/// A saved fishing spot. `CLLocationCoordinate2D` is not `Codable`, so we
/// persist latitude/longitude as primitives and expose a computed
/// `coordinate` to callers.
struct FishingSpot: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    var name: String
    var latitude: Double
    var longitude: Double
    var notes: String
    var fishSpecies: [String]
    let createdAt: Date
    var catches: [CatchEntry]

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var lastCatch: CatchEntry? {
        catches.max(by: { $0.recordedAt < $1.recordedAt })
    }

    init(
        id: UUID = UUID(),
        name: String,
        coordinate: CLLocationCoordinate2D,
        notes: String = "",
        fishSpecies: [String] = [],
        createdAt: Date = .now,
        catches: [CatchEntry] = []
    ) {
        self.id = id
        self.name = name
        self.latitude = coordinate.latitude
        self.longitude = coordinate.longitude
        self.notes = notes
        self.fishSpecies = fishSpecies
        self.createdAt = createdAt
        self.catches = catches
    }
}
