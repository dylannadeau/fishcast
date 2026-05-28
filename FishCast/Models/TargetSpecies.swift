import Foundation

/// Northeast / New England freshwater species the engine can score for.
/// The raw value is the human-readable name so it can drive UI labels and
/// match against the user's free-text catch log entries without an extra map.
enum TargetSpecies: String, CaseIterable, Hashable, Sendable {
    case largemouthBass = "Largemouth Bass"
    case smallmouthBass = "Smallmouth Bass"
    case brookTrout     = "Brook Trout"
    case brownTrout     = "Brown Trout"
    case rainbowTrout   = "Rainbow Trout"
    case lakeTrout      = "Lake Trout"
    case walleye        = "Walleye"
    case yellowPerch    = "Yellow Perch"
    case chainPickerel  = "Chain Pickerel"
    case northernPike   = "Northern Pike"
    case blackCrappie   = "Black Crappie"
    case bluegill       = "Bluegill"
    case channelCatfish = "Channel Catfish"

    var profile: SpeciesProfile { SpeciesDatabase.profile(for: self) }
}

/// Swim-bladder anatomy drives how quickly a species can tolerate a
/// barometric swing — the single biggest behavioural divider in the lineup.
enum BladderType: Sendable {
    /// Closed bladder, no pneumatic duct. Needs 24–48h to equalize after
    /// large pressure changes (bass, walleye, perch, panfish, pickerel).
    case physoclistous
    /// Open bladder connected to the gut. Vents/refills via the pneumatic
    /// duct in minutes (trout, pike, catfish).
    case physostomous
}

enum Season: Sendable, Hashable {
    case spring, summer, fall, winter

    /// Crude Northeast calendar — astronomical seasons would be more
    /// precise, but bite patterns track these meteorological months
    /// closely enough that the extra precision isn't worth the code.
    static func current(for date: Date, calendar: Calendar = .current) -> Season {
        let month = calendar.component(.month, from: date)
        switch month {
        case 3...5:   return .spring
        case 6...8:   return .summer
        case 9...11:  return .fall
        default:      return .winter
        }
    }
}

/// Static per-species data the engine consults when ranking the top
/// candidates for a given moment. Temperature ranges are degrees F (air,
/// used as a proxy for shallow-water temp) and peak ranges sit inside the
/// broader tolerance range.
struct SpeciesProfile: Sendable {
    let species: TargetSpecies
    let name: String
    let bladderType: BladderType
    let toleranceTempF: ClosedRange<Double>
    let peakTempF: ClosedRange<Double>
    let peakSeasons: Set<Season>
    let symbolName: String
}

/// Northeast-tuned profiles. Tolerance ranges follow USFWS Habitat
/// Suitability Index publications (Stuber 1982 for bass, Raleigh for
/// trout, Hokanson 1977 for walleye, Casselman 1978 for pike, etc.);
/// peak ranges are the narrower windows where growth and feeding peak.
enum SpeciesDatabase {
    static let all: [SpeciesProfile] = [
        SpeciesProfile(
            species: .largemouthBass, name: "Largemouth Bass",
            bladderType: .physoclistous,
            toleranceTempF: 65...85, peakTempF: 68...78,
            peakSeasons: [.spring, .summer], symbolName: "fish.fill"
        ),
        SpeciesProfile(
            species: .smallmouthBass, name: "Smallmouth Bass",
            bladderType: .physoclistous,
            toleranceTempF: 60...75, peakTempF: 65...72,
            peakSeasons: [.spring, .fall], symbolName: "fish.fill"
        ),
        SpeciesProfile(
            species: .brookTrout, name: "Brook Trout",
            bladderType: .physostomous,
            toleranceTempF: 45...65, peakTempF: 52...60,
            peakSeasons: [.spring, .fall], symbolName: "fish"
        ),
        SpeciesProfile(
            species: .brownTrout, name: "Brown Trout",
            bladderType: .physostomous,
            toleranceTempF: 50...68, peakTempF: 56...65,
            peakSeasons: [.spring, .fall], symbolName: "fish"
        ),
        SpeciesProfile(
            species: .rainbowTrout, name: "Rainbow Trout",
            bladderType: .physostomous,
            toleranceTempF: 52...68, peakTempF: 60...65,
            peakSeasons: [.spring, .fall], symbolName: "fish"
        ),
        SpeciesProfile(
            species: .lakeTrout, name: "Lake Trout",
            bladderType: .physostomous,
            toleranceTempF: 40...58, peakTempF: 46...55,
            peakSeasons: [.spring, .fall], symbolName: "fish"
        ),
        SpeciesProfile(
            species: .walleye, name: "Walleye",
            bladderType: .physoclistous,
            toleranceTempF: 55...72, peakTempF: 62...68,
            peakSeasons: [.spring, .fall], symbolName: "fish.fill"
        ),
        SpeciesProfile(
            species: .yellowPerch, name: "Yellow Perch",
            bladderType: .physoclistous,
            toleranceTempF: 58...72, peakTempF: 65...70,
            peakSeasons: [.spring, .fall], symbolName: "fish"
        ),
        SpeciesProfile(
            species: .chainPickerel, name: "Chain Pickerel",
            bladderType: .physoclistous,
            toleranceTempF: 55...75, peakTempF: 60...70,
            peakSeasons: [.spring, .fall, .winter], symbolName: "fish.fill"
        ),
        SpeciesProfile(
            species: .northernPike, name: "Northern Pike",
            bladderType: .physostomous,
            toleranceTempF: 50...70, peakTempF: 55...65,
            peakSeasons: [.spring, .fall], symbolName: "fish.fill"
        ),
        SpeciesProfile(
            species: .blackCrappie, name: "Black Crappie",
            bladderType: .physoclistous,
            toleranceTempF: 62...75, peakTempF: 68...72,
            peakSeasons: [.spring], symbolName: "fish"
        ),
        SpeciesProfile(
            species: .bluegill, name: "Bluegill",
            bladderType: .physoclistous,
            toleranceTempF: 65...80, peakTempF: 70...75,
            peakSeasons: [.spring, .summer], symbolName: "fish"
        ),
        SpeciesProfile(
            species: .channelCatfish, name: "Channel Catfish",
            bladderType: .physostomous,
            toleranceTempF: 72...86, peakTempF: 78...84,
            peakSeasons: [.summer, .fall], symbolName: "fish"
        ),
    ]

    static func profile(for species: TargetSpecies) -> SpeciesProfile {
        // Force-unwrap is safe — every enum case is represented in `all`.
        all.first(where: { $0.species == species })!
    }
}
