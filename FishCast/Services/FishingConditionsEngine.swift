import Foundation

/// Pure scoring engine that fuses current weather + 3h pressure trend into a
/// `FishingScore`. Stateless — no UI, no I/O, fully unit-testable.
///
/// The baseline is 50 (neutral); each factor nudges the total up or down and
/// the final value is clamped to 0...100. Weights follow common angling
/// heuristics — adjust in one place if the model evolves.
struct FishingConditionsEngine {

    /// Point deltas for each scoring factor. Exposed internally so tests can
    /// reason about expected bounds without duplicating magic numbers.
    enum Weights {
        static let baseline = 50

        // Pressure trend
        static let slowRiseFromLow = 20   // climbing out of a trough — prime window
        static let slowRise        = 10
        static let slowFall        =  5   // fish often feed before a front
        static let steady          =  2
        static let rapidRise       = -15
        static let rapidFall       = -20

        // Absolute pressure (hPa)
        static let pressureIdeal   = 15
        static let pressureNear    =  5
        static let pressureFar     = -10

        // Wind (mph)
        static let windLight       = 15
        static let windModerate    =  0
        static let windStrong      = -10
        static let windHigh        = -20

        // Temperature (°F)
        static let tempComfort     = 10
        static let tempEdge        =  0
        static let tempExtreme     = -5

        // Golden hours
        static let goldenHour      = 10
        static let middayLull      = -3

        // Cloud cover
        static let partlyCloudy    = 10
        static let overcast        =  5
        static let clearMidday     = -5

        // Precipitation
        static let lightRain       =  5
        static let heavyRain       = -10
    }

    static func computeScore(weather: CurrentWeather, trend: PressureTrend, date: Date) -> FishingScore {
        var total = Weights.baseline
        var factors: [ConditionFactor] = []

        let pressureHPa = weather.pressure.converted(to: .hectopascals).value

        let entries: [(Int, ConditionFactor)] = [
            pressureTrendFactor(trend: trend, currentHPa: pressureHPa),
            absolutePressureFactor(hPa: pressureHPa),
            windFactor(weather.windSpeed),
            temperatureFactor(weather.temperature),
            timeOfDayFactor(date: date),
            cloudCoverFactor(conditionDescription: weather.conditionDescription, date: date),
            precipitationFactor(chance: weather.precipitationChance, conditionDescription: weather.conditionDescription),
        ]

        for (delta, factor) in entries {
            total += delta
            factors.append(factor)
        }

        let clamped = max(0, min(100, total))
        let rating = FishingScore.Rating(score: clamped)
        let summary = buildSummary(rating: rating, trend: trend)

        return FishingScore(score: clamped, rating: rating, factors: factors, summary: summary)
    }

    // MARK: - Factor evaluators

    private static func pressureTrendFactor(trend: PressureTrend, currentHPa: Double) -> (Int, ConditionFactor) {
        switch trend {
        case .rapidFall:
            return (Weights.rapidFall, ConditionFactor(
                name: "Pressure Trend",
                impact: .negative,
                explanation: "Pressure is falling rapidly — fish often shut down before major storms."
            ))
        case .rapidRise:
            return (Weights.rapidRise, ConditionFactor(
                name: "Pressure Trend",
                impact: .negative,
                explanation: "Pressure is surging upward — unstable conditions make fish cautious."
            ))
        case .slowFall:
            return (Weights.slowFall, ConditionFactor(
                name: "Pressure Trend",
                impact: .positive,
                explanation: "A slow pressure drop can trigger a feeding push ahead of a front."
            ))
        case .steady:
            return (Weights.steady, ConditionFactor(
                name: "Pressure Trend",
                impact: .neutral,
                explanation: "Stable pressure keeps feeding patterns consistent."
            ))
        case .slowRise:
            // Rising from a low pressure system is the classic "prime window".
            if currentHPa < 1013 {
                return (Weights.slowRiseFromLow, ConditionFactor(
                    name: "Pressure Trend",
                    impact: .positive,
                    explanation: "Pressure is climbing out of a low — a prime feeding window."
                ))
            }
            return (Weights.slowRise, ConditionFactor(
                name: "Pressure Trend",
                impact: .positive,
                explanation: "A slow, steady rise supports active feeding."
            ))
        }
    }

    private static func absolutePressureFactor(hPa: Double) -> (Int, ConditionFactor) {
        switch hPa {
        case 1013 ... 1023:
            return (Weights.pressureIdeal, ConditionFactor(
                name: "Barometric Pressure",
                impact: .positive,
                explanation: "Pressure is in the sweet spot for active fish."
            ))
        case 1005 ..< 1013, 1023 ... 1030:
            return (Weights.pressureNear, ConditionFactor(
                name: "Barometric Pressure",
                impact: .neutral,
                explanation: "Pressure is close to ideal — workable conditions."
            ))
        default:
            return (Weights.pressureFar, ConditionFactor(
                name: "Barometric Pressure",
                impact: .negative,
                explanation: "Pressure is outside the typical feeding range."
            ))
        }
    }

    private static func windFactor(_ wind: Measurement<UnitSpeed>) -> (Int, ConditionFactor) {
        let mph = wind.converted(to: .milesPerHour).value
        switch mph {
        case ..<10:
            return (Weights.windLight, ConditionFactor(
                name: "Wind",
                impact: .positive,
                explanation: "Light wind keeps the surface fishable and comfortable."
            ))
        case 10 ..< 15:
            return (Weights.windModerate, ConditionFactor(
                name: "Wind",
                impact: .neutral,
                explanation: "Moderate wind — still manageable for most setups."
            ))
        case 15 ..< 20:
            return (Weights.windStrong, ConditionFactor(
                name: "Wind",
                impact: .negative,
                explanation: "Strong wind will make casting and boat control tough."
            ))
        default:
            return (Weights.windHigh, ConditionFactor(
                name: "Wind",
                impact: .negative,
                explanation: "High wind — consider postponing for safety and accuracy."
            ))
        }
    }

    private static func temperatureFactor(_ temperature: Measurement<UnitTemperature>) -> (Int, ConditionFactor) {
        let f = temperature.converted(to: .fahrenheit).value
        switch f {
        case 55 ... 75:
            return (Weights.tempComfort, ConditionFactor(
                name: "Air Temperature",
                impact: .positive,
                explanation: "Temps are in the comfort zone for most species."
            ))
        case 45 ..< 55, 75 ..< 85:
            return (Weights.tempEdge, ConditionFactor(
                name: "Air Temperature",
                impact: .neutral,
                explanation: "Temps are on the edge of the active feeding range."
            ))
        default:
            return (Weights.tempExtreme, ConditionFactor(
                name: "Air Temperature",
                impact: .negative,
                explanation: "Extreme temps push fish away from the surface."
            ))
        }
    }

    /// Approximates golden-hour/midday windows from clock time.
    /// `CurrentWeather` doesn't carry sunrise/sunset, so this is an
    /// intentional heuristic — refine once daily forecast data is wired in.
    private static func timeOfDayFactor(date: Date) -> (Int, ConditionFactor) {
        let hour = Calendar.current.component(.hour, from: date)
        switch hour {
        case 5 ... 7, 17 ... 20:
            return (Weights.goldenHour, ConditionFactor(
                name: "Time of Day",
                impact: .positive,
                explanation: "Golden hour — peak surface feeding activity."
            ))
        case 10 ... 14:
            return (Weights.middayLull, ConditionFactor(
                name: "Time of Day",
                impact: .negative,
                explanation: "Midday lull — fish often hold deeper to avoid bright light."
            ))
        default:
            return (0, ConditionFactor(
                name: "Time of Day",
                impact: .neutral,
                explanation: "Outside the most productive feeding windows."
            ))
        }
    }

    private static func cloudCoverFactor(conditionDescription: String, date: Date) -> (Int, ConditionFactor) {
        let condition = conditionDescription.lowercased()
        let hour = Calendar.current.component(.hour, from: date)
        let isMidday = (10 ... 14).contains(hour)

        if condition.contains("partly cloudy") || condition.contains("mostly cloudy") {
            return (Weights.partlyCloudy, ConditionFactor(
                name: "Cloud Cover",
                impact: .positive,
                explanation: "Broken clouds soften the light and keep fish moving."
            ))
        }
        if condition.contains("cloudy") || condition.contains("overcast") {
            return (Weights.overcast, ConditionFactor(
                name: "Cloud Cover",
                impact: .positive,
                explanation: "Overcast skies give consistent, even light at the surface."
            ))
        }
        if (condition.contains("clear") || condition.contains("sunny")) && isMidday {
            return (Weights.clearMidday, ConditionFactor(
                name: "Cloud Cover",
                impact: .negative,
                explanation: "Bright midday sun pushes fish into deeper, shaded water."
            ))
        }
        return (0, ConditionFactor(
            name: "Cloud Cover",
            impact: .neutral,
            explanation: "Cloud cover isn't a strong factor right now."
        ))
    }

    private static func precipitationFactor(chance: Double, conditionDescription: String) -> (Int, ConditionFactor) {
        let condition = conditionDescription.lowercased()
        let heavy = condition.contains("heavy rain")
            || condition.contains("thunder")
            || condition.contains("storm")

        if heavy || chance > 0.8 {
            return (Weights.heavyRain, ConditionFactor(
                name: "Precipitation",
                impact: .negative,
                explanation: "Heavy rain or storms disrupt feeding and pose safety risks."
            ))
        }

        let lightByDescription = condition.contains("drizzle")
            || condition.contains("light rain")
            || condition.contains("shower")
        if lightByDescription || (chance >= 0.2 && chance <= 0.6) {
            return (Weights.lightRain, ConditionFactor(
                name: "Precipitation",
                impact: .positive,
                explanation: "Light rain stirs surface insects and masks angler silhouettes."
            ))
        }

        return (0, ConditionFactor(
            name: "Precipitation",
            impact: .neutral,
            explanation: "Little to no precipitation affecting the bite."
        ))
    }

    // MARK: - Summary

    private static func buildSummary(rating: FishingScore.Rating, trend: PressureTrend) -> String {
        let lead: String
        switch trend {
        case .slowRise:
            lead = "Pressure has been rising slowly — fish are likely feeding near the surface."
        case .rapidRise:
            lead = "Pressure is rising rapidly — expect cautious, erratic fish behavior."
        case .slowFall:
            lead = "Pressure is slowly falling — fish may push hard to feed before the front arrives."
        case .rapidFall:
            lead = "Pressure is crashing — the bite often shuts down ahead of major storms."
        case .steady:
            lead = "Pressure is holding steady — consistent conditions for consistent feeding."
        }

        let outlook: String
        switch rating {
        case .excellent: outlook = "Everything lines up — get on the water."
        case .good:      outlook = "A solid window for a trip."
        case .fair:      outlook = "Mixed signals, but fish are catchable with the right approach."
        case .poor:      outlook = "Tough conditions — better to wait this one out."
        }

        return "\(lead) \(outlook)"
    }
}
