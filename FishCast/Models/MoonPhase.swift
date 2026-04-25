import Foundation

enum MoonPhase: String, Codable, Sendable, CaseIterable {
    case newMoon
    case waxingCrescent
    case firstQuarter
    case waxingGibbous
    case fullMoon
    case waningGibbous
    case lastQuarter
    case waningCrescent

    var label: String {
        switch self {
        case .newMoon:         return "New Moon"
        case .waxingCrescent:  return "Waxing Crescent"
        case .firstQuarter:    return "First Quarter"
        case .waxingGibbous:   return "Waxing Gibbous"
        case .fullMoon:        return "Full Moon"
        case .waningGibbous:   return "Waning Gibbous"
        case .lastQuarter:     return "Last Quarter"
        case .waningCrescent:  return "Waning Crescent"
        }
    }

    /// Northern-hemisphere SF Symbols. Apple flips these automatically
    /// when the locale is in the southern hemisphere if you ask for the
    /// localized variant — for now we render the canonical glyph.
    var symbolName: String {
        switch self {
        case .newMoon:         return "moonphase.new.moon"
        case .waxingCrescent:  return "moonphase.waxing.crescent"
        case .firstQuarter:    return "moonphase.first.quarter"
        case .waxingGibbous:   return "moonphase.waxing.gibbous"
        case .fullMoon:        return "moonphase.full.moon"
        case .waningGibbous:   return "moonphase.waning.gibbous"
        case .lastQuarter:     return "moonphase.last.quarter"
        case .waningCrescent:  return "moonphase.waning.crescent"
        }
    }

    /// Angler-facing impact note shown in the Forecast tab.
    var fishingImpact: String {
        switch self {
        case .newMoon:
            return "New moon nights are dark — fish rely on smell and vibration. Strong tides amplify the bite around dawn and dusk."
        case .waxingCrescent:
            return "Building light starts to draw fish toward shallows after dusk. A solid window for evening surface action."
        case .firstQuarter:
            return "Moderate tides and reasonable light — a balanced phase for most species during the day."
        case .waxingGibbous:
            return "Increasing brightness extends feeding into the night. Watch for late-evening surface activity."
        case .fullMoon:
            return "Full moon periods often trigger night feeding activity, with strong tides and bright surface light."
        case .waningGibbous:
            return "Late-night and pre-dawn windows shine here — fish that fed under the bright moon often keep going."
        case .lastQuarter:
            return "Tide range eases. Mid-morning and late-afternoon windows tend to fish best."
        case .waningCrescent:
            return "Darker pre-dawn skies and gentler tides — focus on first light and structure."
        }
    }
}

/// Single-shot snapshot of moon-related info for a given date + (optional) location.
struct MoonInfo: Sendable {
    let date: Date
    let phase: MoonPhase
    let ageDays: Double          // 0 ... ~29.53
    let illumination: Double     // 0 ... 1
    let moonrise: Date?
    let moonset: Date?
}
