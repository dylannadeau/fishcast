import Foundation

enum TideType: String, Codable, Sendable {
    case high
    case low
}

struct TideStation: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let latitude: Double
    let longitude: Double
}

/// One predicted high or low water event.
struct TidePrediction: Identifiable, Sendable, Hashable {
    var id: Date { time }
    let time: Date
    let heightFeet: Double
    let type: TideType
}

/// Hi/lo events for a single day at a given NOAA station.
struct TideForecast: Sendable {
    let station: TideStation
    let predictions: [TidePrediction]
}
