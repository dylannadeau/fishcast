import Foundation

/// Generates a CSV export of the catch log. Returns the file URL of a
/// temp-directory file the caller hands to a share sheet.
enum CatchExporter {

    /// Produces a CSV file in the caller's tmp directory. Throws if the
    /// file can't be written. Caller is responsible for cleanup, though
    /// the OS prunes tmp on its own schedule.
    static func writeCSV(
        catches: [CatchEntry],
        spots: [FishingSpot],
        filename: String = "fishcast_catches.csv"
    ) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        let csv = makeCSV(catches: catches, spots: spots)
        try csv.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    static func makeCSV(catches: [CatchEntry], spots: [FishingSpot]) -> String {
        var rows: [String] = []
        rows.append([
            "date", "species", "weight_lb", "length_in", "lure",
            "spot_name", "latitude", "longitude",
            "temp_f", "pressure_hpa", "wind_mph", "moon_phase", "conditions",
            "notes",
        ].joined(separator: ","))

        let isoFormatter = ISO8601DateFormatter()
        let spotsById = Dictionary(uniqueKeysWithValues: spots.map { ($0.id, $0) })

        for entry in catches {
            let spot = entry.spotId.flatMap { spotsById[$0] }
            let snapshot = entry.weatherSnapshot

            let columns: [String] = [
                isoFormatter.string(from: entry.date),
                entry.species,
                entry.weight.map { String(format: "%.2f", $0) } ?? "",
                entry.length.map { String(format: "%.1f", $0) } ?? "",
                entry.lure ?? "",
                spot?.name ?? "",
                spot.map { String(format: "%.6f", $0.latitude) } ?? "",
                spot.map { String(format: "%.6f", $0.longitude) } ?? "",
                snapshot.map { String(format: "%.1f", $0.temperatureF) } ?? "",
                snapshot.map { String(format: "%.1f", $0.pressureHPa) } ?? "",
                snapshot.map { String(format: "%.1f", $0.windMph) } ?? "",
                snapshot?.moonPhase ?? "",
                snapshot?.conditionDescription ?? "",
                entry.notes,
            ]
            rows.append(columns.map(escape).joined(separator: ","))
        }
        return rows.joined(separator: "\n")
    }

    /// Quote-wrap any field containing commas, quotes, or newlines —
    /// minimum RFC 4180 compliance for spreadsheet imports.
    private static func escape(_ field: String) -> String {
        guard field.contains(",") || field.contains("\"") || field.contains("\n") else {
            return field
        }
        let escaped = field.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escaped)\""
    }
}
