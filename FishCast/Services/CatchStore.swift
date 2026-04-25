import Foundation
import os.log

/// JSON-backed persistence for logged catches. Single source of truth — the
/// Map tab queries `catches(for spotId:)` rather than embedding catches on
/// `FishingSpot`. Stats are computed on demand from the in-memory list.
@MainActor
final class CatchStore: ObservableObject {
    static let shared = CatchStore()

    @Published private(set) var catches: [CatchEntry] = []

    private let fileURL: URL
    private let logger = Logger(subsystem: "com.fishcast", category: "CatchStore")

    init(filename: String = "catches.json") {
        let documents = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.fileURL = documents.appendingPathComponent(filename)
        load()
    }

    // MARK: - CRUD

    func addCatch(_ entry: CatchEntry) {
        catches.append(entry)
        save()
    }

    func deleteCatch(_ entry: CatchEntry) {
        catches.removeAll { $0.id == entry.id }
        save()
    }

    func updateCatch(_ entry: CatchEntry) {
        guard let index = catches.firstIndex(where: { $0.id == entry.id }) else { return }
        catches[index] = entry
        save()
    }

    // MARK: - Queries

    func catches(for spotId: UUID) -> [CatchEntry] {
        catches.filter { $0.spotId == spotId }
    }

    func lastCatch(for spotId: UUID) -> CatchEntry? {
        catches(for: spotId).max(by: { $0.date < $1.date })
    }

    // MARK: - Stats

    var totalCatches: Int { catches.count }

    /// Map of species → catch count, ordered most → least.
    var catchesBySpecies: [(species: String, count: Int)] {
        Dictionary(grouping: catches, by: { $0.species })
            .map { ($0.key, $0.value.count) }
            .sorted { $0.count > $1.count }
    }

    /// Catches recorded in the current calendar month.
    var thisMonthCount: Int {
        let calendar = Calendar.current
        let now = Date()
        guard let monthStart = calendar.date(
            from: calendar.dateComponents([.year, .month], from: now)
        ) else { return 0 }
        return catches.filter { $0.date >= monthStart }.count
    }

    var topSpecies: String? {
        catchesBySpecies.first?.species
    }

    /// Heaviest catch on record (or nil if no weight has been logged).
    var personalBest: CatchEntry? {
        catches
            .filter { $0.weight != nil }
            .max { ($0.weight ?? 0) < ($1.weight ?? 0) }
    }

    /// Average conditions across all catches that recorded a weather
    /// snapshot — a coarse proxy for "what's worked for me".
    var bestConditions: BestConditions? {
        let snapshots = catches.compactMap { $0.weatherSnapshot }
        guard !snapshots.isEmpty else { return nil }
        let count = Double(snapshots.count)
        return BestConditions(
            avgTemperatureF: snapshots.map(\.temperatureF).reduce(0, +) / count,
            avgPressureHPa:  snapshots.map(\.pressureHPa).reduce(0, +) / count,
            avgWindMph:      snapshots.map(\.windMph).reduce(0, +) / count,
            sampleSize:      snapshots.count
        )
    }

    // MARK: - Persistence

    private func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            catches = try decoder.decode([CatchEntry].self, from: data)
        } catch {
            logger.error("Failed to load catches: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func save() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(catches)
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            logger.error("Failed to save catches: \(error.localizedDescription, privacy: .public)")
        }
    }
}

/// Aggregated weather across all logged catches — useful for "you tend to
/// do well around 1015 hPa, 68°F" style insights.
struct BestConditions: Sendable {
    let avgTemperatureF: Double
    let avgPressureHPa: Double
    let avgWindMph: Double
    let sampleSize: Int
}
