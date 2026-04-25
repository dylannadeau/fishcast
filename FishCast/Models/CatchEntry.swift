import Foundation

/// A logged catch. Persisted by `CatchStore`; the optional `spotId` links it
/// back to a saved `FishingSpot` (the spot itself does not embed catches —
/// `CatchStore` is the single source of truth).
struct CatchEntry: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    var date: Date
    var spotId: UUID?
    var species: String
    var weight: Double?         // pounds
    var length: Double?         // inches
    var lure: String?
    var notes: String
    var weatherSnapshot: WeatherSnapshot?
    var photo: Data?            // JPEG-encoded thumbnail

    init(
        id: UUID = UUID(),
        date: Date = .now,
        spotId: UUID? = nil,
        species: String,
        weight: Double? = nil,
        length: Double? = nil,
        lure: String? = nil,
        notes: String = "",
        weatherSnapshot: WeatherSnapshot? = nil,
        photo: Data? = nil
    ) {
        self.id = id
        self.date = date
        self.spotId = spotId
        self.species = species
        self.weight = weight
        self.length = length
        self.lure = lure
        self.notes = notes
        self.weatherSnapshot = weatherSnapshot
        self.photo = photo
    }
}
