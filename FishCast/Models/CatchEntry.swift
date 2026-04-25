import Foundation

/// Minimal catch log entry — expanded when the Log tab is implemented.
struct CatchEntry: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    var species: String
    var weightLbs: Double?
    var lengthInches: Double?
    var notes: String
    let recordedAt: Date

    init(
        id: UUID = UUID(),
        species: String,
        weightLbs: Double? = nil,
        lengthInches: Double? = nil,
        notes: String = "",
        recordedAt: Date = .now
    ) {
        self.id = id
        self.species = species
        self.weightLbs = weightLbs
        self.lengthInches = lengthInches
        self.notes = notes
        self.recordedAt = recordedAt
    }
}
