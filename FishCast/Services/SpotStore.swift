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
