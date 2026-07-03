import Foundation

/// One species the engine thinks should bite right now. `id` is the species
/// name so SwiftUI list animations are stable across recomputations.
/// Codable so `SpotConditions` snapshots can be cached to disk.
struct SpeciesPrediction: Identifiable, Sendable, Hashable, Codable {
    var id: String { species }
    let species: String
    let likelihood: Int        // 0 ... 100
    let tip: String
    let symbolName: String
}
