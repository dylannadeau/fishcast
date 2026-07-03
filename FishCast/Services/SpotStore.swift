import Foundation
import os.log

/// JSON-backed persistence for saved fishing spots.
/// Single-writer on the main actor; reads the file once at init and flushes
/// synchronously on every mutation — fine for the small list sizes expected.
@MainActor
final class SpotStore: ObservableObject {
    static let shared = SpotStore()

    @Published private(set) var spots: [FishingSpot] = []

    private let fileURL: URL
    private let logger = Logger(subsystem: "com.fishcast", category: "SpotStore")

    init(filename: String = "spots.json") {
        let documents = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.fileURL = documents.appendingPathComponent(filename)
        load()
    }

    // MARK: - CRUD

    func addSpot(_ spot: FishingSpot) {
        spots.append(spot)
        save()
    }

    func deleteSpot(_ spot: FishingSpot) {
        spots.removeAll { $0.id == spot.id }
        save()
    }

    func updateSpot(_ spot: FishingSpot) {
        guard let index = spots.firstIndex(where: { $0.id == spot.id }) else { return }
        spots[index] = spot
        save()
    }

    // MARK: - Persistence

    private func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            spots = try decoder.decode([FishingSpot].self, from: data)
        } catch {
            logger.error("Failed to load spots: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func save() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(spots)
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            logger.error("Failed to save spots: \(error.localizedDescription, privacy: .public)")
        }
    }
}

// MARK: - Conditions cache

/// Last successful `SpotConditions` per spot, persisted to
/// `Caches/spot_conditions.json` so the Dashboard isn't blank when a
/// refresh fails or the app cold-starts offline. Best-effort: I/O errors
/// are logged and swallowed — the worst case is a re-fetch.
@MainActor
final class SpotConditionsCache {
    static let shared = SpotConditionsCache()

    private var conditionsBySpot: [UUID: SpotConditions] = [:]
    private let fileURL: URL
    private let logger = Logger(subsystem: "com.fishcast", category: "SpotConditionsCache")

    init(filename: String = "spot_conditions.json") {
        let caches = FileManager.default
            .urls(for: .cachesDirectory, in: .userDomainMask)[0]
        self.fileURL = caches.appendingPathComponent(filename)
        load()
    }

    func conditions(for spotId: UUID) -> SpotConditions? {
        conditionsBySpot[spotId]
    }

    func save(_ conditions: SpotConditions) {
        conditionsBySpot[conditions.spotId] = conditions
        flush()
    }

    /// Drops cache entries for spots that no longer exist.
    func prune(keeping spotIds: Set<UUID>) {
        let before = conditionsBySpot.count
        conditionsBySpot = conditionsBySpot.filter { spotIds.contains($0.key) }
        if conditionsBySpot.count != before { flush() }
    }

    // MARK: - Persistence

    private func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            conditionsBySpot = try decoder.decode([UUID: SpotConditions].self, from: data)
        } catch {
            logger.error("Failed to load conditions cache: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func flush() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(conditionsBySpot)
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            logger.error("Failed to save conditions cache: \(error.localizedDescription, privacy: .public)")
        }
    }
}
