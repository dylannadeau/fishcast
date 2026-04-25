import CoreLocation
import Foundation
import os.log

/// NOAA Tides & Currents wrapper.
///
/// Two endpoints:
///   • Station metadata (cached on disk indefinitely — list rarely changes)
///   • Hi/lo predictions for a given station + day
///
/// Inland locations return `nil` from `forecast(near:)` — caller should hide
/// the tide UI gracefully.
actor TideService {
    static let shared = TideService()

    /// Default radius beyond which we consider the location inland.
    static let defaultMaxMiles: Double = 75

    // MARK: Endpoints

    private static let stationsURL = URL(
        string: "https://api.tidesandcurrents.noaa.gov/mdapi/prod/webapi/stations.json?type=tidepredictions"
    )!
    private static let datagetterBase =
        "https://api.tidesandcurrents.noaa.gov/api/prod/datagetter"

    // MARK: State

    private let session: URLSession
    private let cacheURL: URL
    private var stations: [TideStation]?
    private let logger = Logger(subsystem: "com.fishcast", category: "TideService")

    init(session: URLSession = .shared) {
        self.session = session
        let caches = FileManager.default
            .urls(for: .cachesDirectory, in: .userDomainMask)[0]
        self.cacheURL = caches.appendingPathComponent("noaa_tide_stations.json")
    }

    // MARK: Public

    /// Tide forecast for the day containing `date` at the nearest station.
    /// Returns `nil` if no station is within `maxMiles` (likely inland).
    func forecast(
        near coordinate: CLLocationCoordinate2D,
        on date: Date = .now,
        maxMiles: Double = TideService.defaultMaxMiles
    ) async throws -> TideForecast? {
        guard let station = try await nearestStation(to: coordinate, maxMiles: maxMiles) else {
            return nil
        }
        let predictions = try await fetchPredictions(for: station, on: date)
        return TideForecast(station: station, predictions: predictions)
    }

    func nearestStation(
        to coordinate: CLLocationCoordinate2D,
        maxMiles: Double
    ) async throws -> TideStation? {
        let stations = try await loadStations()
        let target = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)

        var bestStation: TideStation?
        var bestMiles = Double.infinity
        for station in stations {
            let location = CLLocation(latitude: station.latitude, longitude: station.longitude)
            let miles = target.distance(from: location) / 1609.344
            if miles < bestMiles {
                bestMiles = miles
                bestStation = station
            }
        }
        return bestMiles <= maxMiles ? bestStation : nil
    }

    // MARK: Stations

    private func loadStations() async throws -> [TideStation] {
        if let stations { return stations }

        if let data = try? Data(contentsOf: cacheURL),
           let decoded = try? JSONDecoder().decode([TideStation].self, from: data),
           !decoded.isEmpty {
            self.stations = decoded
            return decoded
        }

        let fetched = try await fetchStations()
        self.stations = fetched
        if let data = try? JSONEncoder().encode(fetched) {
            try? data.write(to: cacheURL, options: .atomic)
        }
        return fetched
    }

    private func fetchStations() async throws -> [TideStation] {
        do {
            let (data, response) = try await session.data(from: TideService.stationsURL)
            try validate(response: response)
            let payload = try JSONDecoder().decode(NOAAStationsResponse.self, from: data)
            return payload.stations.map { raw in
                TideStation(
                    id: raw.id,
                    name: raw.name,
                    latitude: raw.lat,
                    longitude: raw.lng
                )
            }
        } catch let error as AppError {
            throw error
        } catch {
            logger.error("Stations fetch failed: \(error.localizedDescription, privacy: .public)")
            throw AppError.tideFetchFailed(underlying: error)
        }
    }

    // MARK: Predictions

    private func fetchPredictions(
        for station: TideStation,
        on date: Date
    ) async throws -> [TidePrediction] {
        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "yyyyMMdd"
        dayFormatter.timeZone = TimeZone.current
        let dateStr = dayFormatter.string(from: date)

        var components = URLComponents(string: TideService.datagetterBase)!
        components.queryItems = [
            URLQueryItem(name: "product",     value: "predictions"),
            URLQueryItem(name: "application", value: "FishCast"),
            URLQueryItem(name: "begin_date",  value: dateStr),
            URLQueryItem(name: "end_date",    value: dateStr),
            URLQueryItem(name: "datum",       value: "MLLW"),
            URLQueryItem(name: "station",     value: station.id),
            URLQueryItem(name: "time_zone",   value: "lst_ldt"),
            URLQueryItem(name: "units",       value: "english"),
            URLQueryItem(name: "interval",    value: "hilo"),
            URLQueryItem(name: "format",      value: "json"),
        ]
        guard let url = components.url else {
            throw AppError.tideFetchFailed(underlying: nil)
        }

        do {
            let (data, response) = try await session.data(from: url)
            try validate(response: response)

            let payload = try JSONDecoder().decode(NOAAPredictionsResponse.self, from: data)

            let parser = DateFormatter()
            parser.dateFormat = "yyyy-MM-dd HH:mm"
            parser.timeZone = TimeZone.current   // lst_ldt = local time at station

            return payload.predictions.compactMap { entry in
                guard let time = parser.date(from: entry.t),
                      let value = Double(entry.v) else { return nil }
                let type: TideType = (entry.type == "H") ? .high : .low
                return TidePrediction(time: time, heightFeet: value, type: type)
            }
        } catch let error as AppError {
            throw error
        } catch {
            logger.error("Predictions fetch failed: \(error.localizedDescription, privacy: .public)")
            throw AppError.tideFetchFailed(underlying: error)
        }
    }

    // MARK: HTTP helpers

    private func validate(response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse,
              (200 ..< 300).contains(http.statusCode) else {
            throw AppError.tideFetchFailed(underlying: nil)
        }
    }
}

// MARK: - Wire formats

private struct NOAAStationsResponse: Decodable {
    struct Station: Decodable {
        let id: String
        let name: String
        let lat: Double
        let lng: Double
    }
    let stations: [Station]
}

private struct NOAAPredictionsResponse: Decodable {
    struct Prediction: Decodable {
        let t: String
        let v: String
        let type: String
    }
    let predictions: [Prediction]
}
