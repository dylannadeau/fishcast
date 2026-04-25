import Foundation

/// Per-species bite predictor.
///
/// Each profile encodes published warm/coldwater preferences and crepuscular
/// activity windows from freshwater fisheries biology:
///   • Largemouth bass — Stuber et al. (1982) USFWS HSI: optimal 65–85°F.
///   • Brown/Rainbow trout — Raleigh et al. HSI: 50–65°F, low-light feeders.
///   • Walleye — Hokanson (1977): crepuscular, optimal growth 65–75°F.
///   • Northern pike — Casselman (1978): cool-water preference 55–65°F.
///   • Channel catfish — Brown et al.: warm-water 70–85°F, nocturnal.
///   • Black crappie — Edwards et al. HSI: 55–70°F, schooled in cover.
///   • Yellow perch — Krieger et al.: 60–70°F, daylight feeder.
///
/// The numbers below are intentionally compact heuristics — refine the
/// profiles in one place if the model grows.
extension FishingConditionsEngine {

    private struct SpeciesProfile {
        let name: String
        let symbolName: String
        let optimalTemp: ClosedRange<Double>     // °F — peak bite
        let tolerantTemp: ClosedRange<Double>    // °F — workable
        let bestHours: Set<Int>                  // 0...23
        let pressureBoost: Set<PressureTrend>
        let pressurePenalty: Set<PressureTrend>
        let likesOvercast: Bool
        let likesLightWind: Bool
        let tip: String
    }

    private static let speciesProfiles: [SpeciesProfile] = [
        SpeciesProfile(
            name: "Largemouth Bass",
            symbolName: "fish.fill",
            optimalTemp: 65 ... 80,
            tolerantTemp: 55 ... 88,
            bestHours: [5, 6, 7, 8, 18, 19, 20],
            pressureBoost: [.slowRise, .steady],
            pressurePenalty: [.rapidFall, .rapidRise],
            likesOvercast: true,
            likesLightWind: true,
            tip: "Work topwater along shallow cover — laydowns, weed edges, and docks during golden hour."
        ),
        SpeciesProfile(
            name: "Trout",
            symbolName: "fish",
            optimalTemp: 50 ... 65,
            tolerantTemp: 42 ... 68,
            bestHours: [5, 6, 7, 8, 17, 18, 19, 20],
            pressureBoost: [.slowFall, .steady],
            pressurePenalty: [.rapidRise, .rapidFall],
            likesOvercast: true,
            likesLightWind: false,
            tip: "Drift small spinners or wet flies through riffles and seams at first light."
        ),
        SpeciesProfile(
            name: "Walleye",
            symbolName: "fish.fill",
            optimalTemp: 65 ... 75,
            tolerantTemp: 55 ... 78,
            bestHours: [5, 6, 19, 20, 21, 22],
            pressureBoost: [.slowFall, .steady],
            pressurePenalty: [.rapidRise],
            likesOvercast: true,
            likesLightWind: true,
            tip: "Work jigs along structure during dusk — a light walleye chop is your friend."
        ),
        SpeciesProfile(
            name: "Northern Pike",
            symbolName: "fish.fill",
            optimalTemp: 55 ... 65,
            tolerantTemp: 48 ... 72,
            bestHours: [8, 9, 10, 11, 16, 17, 18],
            pressureBoost: [.slowFall, .slowRise],
            pressurePenalty: [.rapidFall, .rapidRise],
            likesOvercast: true,
            likesLightWind: true,
            tip: "Throw large spoons or spinnerbaits along weed edges — pike feed hard before fronts."
        ),
        SpeciesProfile(
            name: "Catfish",
            symbolName: "fish",
            optimalTemp: 70 ... 85,
            tolerantTemp: 60 ... 90,
            bestHours: [19, 20, 21, 22, 23, 0, 1, 2, 3, 4],
            pressureBoost: [.steady, .slowRise],
            pressurePenalty: [.rapidFall],
            likesOvercast: false,
            likesLightWind: false,
            tip: "Anchor near drop-offs after dark with cut bait or stinkbait — stained water helps."
        ),
        SpeciesProfile(
            name: "Crappie",
            symbolName: "fish",
            optimalTemp: 55 ... 70,
            tolerantTemp: 48 ... 75,
            bestHours: [5, 6, 7, 17, 18, 19],
            pressureBoost: [.steady, .slowRise],
            pressurePenalty: [.rapidFall, .rapidRise],
            likesOvercast: true,
            likesLightWind: false,
            tip: "Vertical-jig minnows or small tubes over brush piles and submerged timber."
        ),
        SpeciesProfile(
            name: "Yellow Perch",
            symbolName: "fish",
            optimalTemp: 60 ... 70,
            tolerantTemp: 50 ... 75,
            bestHours: [7, 8, 9, 10, 14, 15, 16, 17],
            pressureBoost: [.steady, .slowRise],
            pressurePenalty: [.rapidFall, .rapidRise],
            likesOvercast: false,
            likesLightWind: true,
            tip: "Bottom-bounce small jigs tipped with worm over sandy flats and weed lines."
        ),
    ]

    /// Top species likely biting given current conditions, sorted by likelihood.
    /// Pass `topN` to limit (e.g. Dashboard "Best Bets Today" shows top 3).
    static func speciesRecommendations(
        weather: CurrentWeather,
        trend: PressureTrend,
        date: Date,
        topN: Int? = nil
    ) -> [SpeciesPrediction] {
        let tempF = weather.temperature.converted(to: .fahrenheit).value
        let windMph = weather.windSpeed.converted(to: .milesPerHour).value
        let condition = weather.conditionDescription.lowercased()
        let isOvercast = condition.contains("cloudy") || condition.contains("overcast")
        let hour = Calendar.current.component(.hour, from: date)

        let predictions = speciesProfiles.map { profile -> SpeciesPrediction in
            var likelihood = 50

            // Temperature match — biggest single driver.
            if profile.optimalTemp.contains(tempF) {
                likelihood += 25
            } else if profile.tolerantTemp.contains(tempF) {
                likelihood += 8
            } else {
                likelihood -= 25
            }

            // Time of day — crepuscular vs daylight species.
            if profile.bestHours.contains(hour) {
                likelihood += 15
            } else if (10 ... 14).contains(hour) {
                likelihood -= 8
            }

            // Pressure trend.
            if profile.pressureBoost.contains(trend) {
                likelihood += 12
            } else if profile.pressurePenalty.contains(trend) {
                likelihood -= 18
            }

            // Wind — light chop helps some species, hurts others.
            if profile.likesLightWind, windMph >= 4, windMph < 12 {
                likelihood += 5
            } else if windMph > 18 {
                likelihood -= 8
            }

            // Cloud cover.
            if profile.likesOvercast, isOvercast {
                likelihood += 8
            }

            let clamped = max(0, min(100, likelihood))
            return SpeciesPrediction(
                species: profile.name,
                likelihood: clamped,
                tip: profile.tip,
                symbolName: profile.symbolName
            )
        }

        let ranked = predictions.sorted { $0.likelihood > $1.likelihood }
        if let topN { return Array(ranked.prefix(topN)) }
        return ranked
    }
}
