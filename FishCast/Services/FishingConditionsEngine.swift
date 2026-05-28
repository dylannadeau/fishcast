import Foundation

/// Species-aware fishing-conditions scorer for the Northeast / New England.
///
/// Stateless, pure. Seven weighted environmental factors fold into a
/// 0–100 score, after which the engine projects the next good window
/// (when available) and ranks the most likely species to bite.
///
/// Factor weights (positive maxes) sum to 100; penalties can pull the
/// raw total below zero before clamping.
///   • Barometric trend + absolute  …  25 + 5
///   • Air temperature              …  20 (+3 seasonal trend bonus)
///   • Time of day / solunar        …  20
///   • Moon phase                   …  10
///   • Wind                         …  10
///   • Cloud cover                  …   8
///   • Precipitation                …   7
///
/// Science notes (kept here so the rationale travels with the code):
///   • Swim-bladder anatomy gates how fast a species recovers from a
///     pressure swing — physoclistous fish need 24–48h, physostomous
///     fish vent gas via the pneumatic duct in minutes.
///   • Golden-hour and solunar overlap is the single most reliable
///     window across temperate freshwater species.
///   • USFWS HSI bulletins back the per-species temperature ranges.
struct FishingConditionsEngine {

    // MARK: - Entry point

    static func computeScore(
        weather: CurrentWeather,
        trend: PressureTrend,
        date: Date,
        targetSpecies: [TargetSpecies] = TargetSpecies.allCases,
        hourlyForecast: [HourlyForecast] = [],
        moonInfo: MoonInfo? = nil,
        sunrise: Date? = nil,
        sunset: Date? = nil,
        recentPrecipitation: Bool = false
    ) -> FishingScore {
        let context = Context(
            weather: weather,
            trend: trend,
            date: date,
            targetSpecies: targetSpecies.isEmpty
                ? TargetSpecies.allCases
                : targetSpecies,
            moon: moonInfo,
            sunrise: sunrise,
            sunset: sunset,
            recentPrecipitation: recentPrecipitation
        )

        var factors: [ConditionFactor] = []
        var total = 0

        let pressureScore = pressureFactor(context: context)
        total += pressureScore.delta
        factors.append(pressureScore.factor)

        if let absolute = absolutePressureFactor(context: context) {
            total += absolute.delta
            factors.append(absolute.factor)
        }

        let tempScore = temperatureFactor(context: context)
        total += tempScore.delta
        factors.append(tempScore.factor)

        let timeScore = timeOfDayFactor(context: context)
        total += timeScore.delta
        factors.append(timeScore.factor)

        let moonScore = moonFactor(context: context)
        total += moonScore.delta
        factors.append(moonScore.factor)

        let windScore = windFactor(context: context)
        total += windScore.delta
        factors.append(windScore.factor)

        let cloudScore = cloudCoverFactor(context: context)
        total += cloudScore.delta
        factors.append(cloudScore.factor)

        let precipScore = precipitationFactor(context: context)
        total += precipScore.delta
        factors.append(precipScore.factor)

        let clamped = max(0, min(100, total))
        let rating = FishingScore.Rating(score: clamped)

        let topSpecies = rankSpecies(context: context, environmentalScore: clamped)
        let nextWindow = clamped < 60
            ? nextBestWindow(context: context, hourly: hourlyForecast)
            : nil
        let avoid = clamped < 40
            ? buildAvoidReason(context: context, factors: factors)
            : nil
        let summary = buildSummary(
            score: clamped,
            rating: rating,
            factors: factors,
            context: context,
            nextWindow: nextWindow
        )

        return FishingScore(
            score: clamped,
            rating: rating,
            factors: factors,
            summary: summary,
            topSpecies: Array(topSpecies.prefix(3)),
            nextBestWindow: nextWindow,
            avoidReason: avoid
        )
    }

    // MARK: - Full per-species ranking

    /// Like the `topSpecies` slice on a `FishingScore`, but returns the
    /// complete ranked list. The detail view uses this to render every
    /// Northeast species, not just the top 3.
    static func allSpeciesPredictions(
        weather: CurrentWeather,
        trend: PressureTrend,
        date: Date,
        targetSpecies: [TargetSpecies] = TargetSpecies.allCases,
        moonInfo: MoonInfo? = nil,
        sunrise: Date? = nil,
        sunset: Date? = nil
    ) -> [SpeciesPrediction] {
        let score = computeScore(
            weather: weather,
            trend: trend,
            date: date,
            targetSpecies: targetSpecies,
            moonInfo: moonInfo,
            sunrise: sunrise,
            sunset: sunset
        )
        let context = Context(
            weather: weather, trend: trend, date: date,
            targetSpecies: targetSpecies.isEmpty ? TargetSpecies.allCases : targetSpecies,
            moon: moonInfo, sunrise: sunrise, sunset: sunset,
            recentPrecipitation: false
        )
        return rankSpecies(context: context, environmentalScore: score.score)
    }

    /// Lightweight per-species fit summary — surfaced in the species detail
    /// list so the user can see *why* a fish is/isn't on the board.
    enum TemperatureFit: Sendable {
        case inPeakRange, inToleranceRange, outOfRange
    }

    static func temperatureFit(
        for species: TargetSpecies, currentTempF tempF: Double
    ) -> TemperatureFit {
        let profile = species.profile
        if profile.peakTempF.contains(tempF) { return .inPeakRange }
        if profile.toleranceTempF.contains(tempF) { return .inToleranceRange }
        return .outOfRange
    }

    static func isInPeakSeason(_ species: TargetSpecies, date: Date) -> Bool {
        species.profile.peakSeasons.contains(Season.current(for: date))
    }

    // MARK: - Shared context

    /// Pre-converted, derived values that every factor needs. Computed once
    /// per call to avoid redoing the same `Measurement` conversions inside
    /// each of the seven factor functions.
    fileprivate struct Context {
        let weather: CurrentWeather
        let trend: PressureTrend
        let date: Date
        let targetSpecies: [TargetSpecies]
        let moon: MoonInfo?
        let sunrise: Date?
        let sunset: Date?
        let recentPrecipitation: Bool

        let tempF: Double
        let pressureInHg: Double
        let pressureHPa: Double
        let windMph: Double
        let cloudBucket: CloudBucket
        let precipBucket: PrecipBucket
        let hour: Int
        let season: Season

        init(
            weather: CurrentWeather, trend: PressureTrend, date: Date,
            targetSpecies: [TargetSpecies], moon: MoonInfo?,
            sunrise: Date?, sunset: Date?, recentPrecipitation: Bool
        ) {
            self.weather = weather
            self.trend = trend
            self.date = date
            self.targetSpecies = targetSpecies
            self.moon = moon
            self.sunrise = sunrise
            self.sunset = sunset
            self.recentPrecipitation = recentPrecipitation

            self.tempF = weather.temperature.converted(to: .fahrenheit).value
            self.pressureHPa = weather.pressure.converted(to: .hectopascals).value
            self.pressureInHg = pressureHPa / 33.8639
            self.windMph = weather.windSpeed.converted(to: .milesPerHour).value
            self.cloudBucket = CloudBucket.from(description: weather.conditionDescription)
            self.precipBucket = PrecipBucket.from(
                chance: weather.precipitationChance,
                description: weather.conditionDescription
            )
            self.hour = Calendar.current.component(.hour, from: date)
            self.season = Season.current(for: date)
        }

        var profiles: [SpeciesProfile] { targetSpecies.map(\.profile) }

        /// Weighted average of the target set's tolerance and peak temperature
        /// ranges — used as the environmental temperature target so the score
        /// adapts to whoever the user is fishing for.
        var averagedTempTarget: (peak: ClosedRange<Double>, tolerance: ClosedRange<Double>) {
            let profiles = self.profiles
            guard !profiles.isEmpty else {
                return (peak: 60...75, tolerance: 50...80)
            }
            let peakLow  = profiles.map(\.peakTempF.lowerBound).reduce(0, +) / Double(profiles.count)
            let peakHigh = profiles.map(\.peakTempF.upperBound).reduce(0, +) / Double(profiles.count)
            let tolLow   = profiles.map(\.toleranceTempF.lowerBound).reduce(0, +) / Double(profiles.count)
            let tolHigh  = profiles.map(\.toleranceTempF.upperBound).reduce(0, +) / Double(profiles.count)
            return (peak: peakLow...peakHigh, tolerance: tolLow...tolHigh)
        }
    }

    private struct Scored {
        let delta: Int
        let factor: ConditionFactor
    }

    // MARK: - 1. Pressure (trend + absolute)

    private static func pressureFactor(context: Context) -> Scored {
        let (delta, name, explanation, impact): (Int, String, String, ConditionFactor.Impact)
        switch context.trend {
        case .rapidFall:
            (delta, name, explanation, impact) = (
                25, "Pressure Trend",
                "Pressure is falling fast — fish often feed aggressively just ahead of a front.",
                .positive
            )
        case .slowFall:
            (delta, name, explanation, impact) = (
                20, "Pressure Trend",
                "A slow pressure drop tends to spark a steady, reliable bite.",
                .positive
            )
        case .steady:
            (delta, name, explanation, impact) = (
                15, "Pressure Trend",
                "Steady pressure keeps feeding patterns predictable.",
                .positive
            )
        case .slowRise:
            (delta, name, explanation, impact) = (
                8, "Pressure Trend",
                "A slow rise — fish are still adjusting, but trout and pike stay active.",
                .neutral
            )
        case .rapidRise:
            (delta, name, explanation, impact) = (
                3, "Pressure Trend",
                "A surge has bass and walleye lethargic while their swim bladders equalize.",
                .negative
            )
        }
        return Scored(
            delta: delta,
            factor: ConditionFactor(name: name, impact: impact, explanation: explanation, delta: delta)
        )
    }

    private static func absolutePressureFactor(context: Context) -> Scored? {
        let inHg = context.pressureInHg
        switch inHg {
        case 29.80...30.20:
            return Scored(
                delta: 5,
                factor: ConditionFactor(
                    name: "Barometric Level",
                    impact: .positive,
                    explanation: "Pressure is sitting in the ideal 29.8–30.2 inHg band.",
                    delta: 5
                )
            )
        case ..<29.60:
            return Scored(
                delta: -5,
                factor: ConditionFactor(
                    name: "Barometric Level",
                    impact: .negative,
                    explanation: "Very low pressure — storm-front conditions are suppressing the bite.",
                    delta: -5
                )
            )
        case 30.50...:
            return Scored(
                delta: -5,
                factor: ConditionFactor(
                    name: "Barometric Level",
                    impact: .negative,
                    explanation: "High-pressure lockjaw — fish hold deep with compressed bladders.",
                    delta: -5
                )
            )
        default:
            return nil
        }
    }

    // MARK: - 2. Temperature (species-weighted target)

    private static func temperatureFactor(context: Context) -> Scored {
        let target = context.averagedTempTarget
        let tempF = context.tempF

        var delta: Int
        var explanation: String
        var impact: ConditionFactor.Impact

        if target.peak.contains(tempF) {
            delta = 20
            explanation = "Air temperature is dialed in to the peak range for your target species."
            impact = .positive
        } else if target.tolerance.contains(tempF) {
            delta = 12
            explanation = "Temperature is workable — inside the tolerance range for most targets."
            impact = .neutral
        } else if distance(from: tempF, to: target.tolerance) <= 5 {
            delta = 6
            explanation = "Temperature is on the edge of the comfort zone."
            impact = .neutral
        } else if distance(from: tempF, to: target.tolerance) > 10 {
            delta = 0
            explanation = "Air temp is well outside the productive range — fish are seeking thermal refuge."
            impact = .negative
        } else {
            delta = 3
            explanation = "Temperature is outside the strike zone but within recovery distance."
            impact = .negative
        }

        // Seasonal trend bonus: warming in spring / cooling in fall both
        // historically drive feeding pushes.
        if context.season == .spring, tempF >= target.tolerance.lowerBound {
            delta += 3
            explanation += " Warming spring conditions are putting fish on the feed."
        } else if context.season == .fall, tempF <= target.peak.upperBound {
            delta += 3
            explanation += " Cooling fall conditions trigger pre-winter feeding."
        }

        return Scored(
            delta: delta,
            factor: ConditionFactor(
                name: "Temperature",
                impact: impact,
                explanation: explanation,
                delta: delta
            )
        )
    }

    /// Shortest distance between `value` and `range` (0 when inside).
    private static func distance(from value: Double, to range: ClosedRange<Double>) -> Double {
        if range.contains(value) { return 0 }
        if value < range.lowerBound { return range.lowerBound - value }
        return value - range.upperBound
    }

    // MARK: - 3. Time of day / solunar

    private static func timeOfDayFactor(context: Context) -> Scored {
        let isGolden = isGoldenHour(context: context)
        let solunar = solunarBucket(context: context)
        let hour = context.hour
        let isMidday = (10...14).contains(hour)
        let isNight = hour < 5 || hour >= 21

        var delta = 0
        var bits: [String] = []
        var name = "Time of Day"
        var impact: ConditionFactor.Impact = .neutral

        if isGolden && solunar == .major {
            delta = 20
            name = "Peak Feeding Window"
            bits.append("golden hour and a solunar major period are overlapping right now")
            impact = .positive
        } else if isGolden {
            delta = 20
            bits.append("inside golden hour — peak light-change feeding")
            impact = .positive
        } else if solunar == .major {
            delta = 15
            bits.append("solunar major period — moon overhead/underfoot triggers activity")
            impact = .positive
        } else if solunar == .minor {
            delta = 10
            bits.append("solunar minor period — moonrise/moonset bump")
            impact = .positive
        }

        if isMidday && context.season == .summer {
            delta -= 5
            bits.append("bright summer midday is suppressing surface activity")
            if impact == .neutral { impact = .negative }
        }

        if isNight, let moon = context.moon {
            switch moon.phase {
            case .fullMoon:
                delta += 8
                bits.append("full-moon night — bass and walleye stay on the prowl")
                if impact != .positive { impact = .positive }
            case .newMoon:
                delta += 3
                bits.append("new-moon darkness keeps cautious fish moving")
            default:
                break
            }
        }

        let explanation = bits.isEmpty
            ? "Off-peak hour — between the main feeding windows."
            : bits.joined(separator: "; ").capitalizedFirst + "."

        return Scored(
            delta: delta,
            factor: ConditionFactor(
                name: name,
                impact: impact,
                explanation: explanation,
                delta: delta
            )
        )
    }

    private static func isGoldenHour(context: Context) -> Bool {
        if let sunrise = context.sunrise, let sunset = context.sunset {
            let dawnEnd = sunrise.addingTimeInterval(3600)
            let duskStart = sunset.addingTimeInterval(-3600)
            return (sunrise...dawnEnd).contains(context.date)
                || (duskStart...sunset).contains(context.date)
        }
        // Fallback clock heuristic for the Northeast — close enough when
        // sunrise/sunset weren't passed in.
        return (5...7).contains(context.hour) || (18...20).contains(context.hour)
    }

    private enum Solunar { case major, minor, none }

    /// Maps moonrise/moonset and their ±12h "underfoot" companions to the
    /// classic John Alden Knight solunar windows. Without `MoonInfo`
    /// rise/set times we can't compute this so we return `.none`.
    private static func solunarBucket(context: Context) -> Solunar {
        guard let moon = context.moon else { return .none }
        let date = context.date

        let majorWindows: [Date] = [moon.moonrise, moon.moonset]
            .compactMap { $0 }
            .flatMap { [$0, $0.addingTimeInterval(12 * 3600), $0.addingTimeInterval(-12 * 3600)] }

        if majorWindows.contains(where: { abs(date.timeIntervalSince($0)) <= 3600 }) {
            return .major
        }

        let minorWindows: [Date] = [moon.moonrise, moon.moonset].compactMap { $0 }
        if minorWindows.contains(where: { abs(date.timeIntervalSince($0)) <= 1800 }) {
            return .minor
        }
        return .none
    }

    // MARK: - 4. Moon phase

    private static func moonFactor(context: Context) -> Scored {
        guard let moon = context.moon else {
            return Scored(
                delta: 5,
                factor: ConditionFactor(
                    name: "Moon Phase",
                    impact: .neutral,
                    explanation: "Lunar data unavailable — assuming a neutral phase contribution.",
                    delta: 5
                )
            )
        }

        let delta: Int
        let blurb: String
        let impact: ConditionFactor.Impact
        switch moon.phase {
        case .newMoon:
            delta = 10
            blurb = "New moon — strongest tidal pull, fish most active."
            impact = .positive
        case .fullMoon:
            delta = 10
            blurb = "Full moon — strong tides and bright nights extend feeding into darkness."
            impact = .positive
        case .waxingGibbous, .waningGibbous:
            delta = 7
            blurb = "Gibbous phase — solid lunar pull on feeding rhythms."
            impact = .positive
        case .firstQuarter, .lastQuarter:
            delta = 5
            blurb = "Quarter moon — moderate lunar influence."
            impact = .neutral
        case .waxingCrescent, .waningCrescent:
            delta = 3
            blurb = "Crescent phase — quietest lunar window of the cycle."
            impact = .neutral
        }
        return Scored(
            delta: delta,
            factor: ConditionFactor(
                name: "Moon Phase",
                impact: impact,
                explanation: blurb,
                delta: delta
            )
        )
    }

    // MARK: - 5. Wind

    private static func windFactor(context: Context) -> Scored {
        let mph = context.windMph
        let delta: Int
        let explanation: String
        let impact: ConditionFactor.Impact
        switch mph {
        case ..<8:
            delta = 10
            explanation = "Calm to light breeze — easy casting and clean presentations."
            impact = .positive
        case 8..<15:
            delta = 7
            explanation = "Light chop disguises your silhouette and stirs bait — productive wind."
            impact = .positive
        case 15..<20:
            delta = 4
            explanation = "Moderate wind — workable but will affect boat control."
            impact = .neutral
        case 20..<25:
            delta = 1
            explanation = "High wind — fish are pushed to leeward structure; tough day for casting."
            impact = .negative
        default:
            delta = 0
            explanation = "Very high wind — unsafe on open water and fish go deep for shelter."
            impact = .negative
        }
        return Scored(
            delta: delta,
            factor: ConditionFactor(
                name: "Wind",
                impact: impact,
                explanation: explanation,
                delta: delta
            )
        )
    }

    // MARK: - 6. Cloud cover

    fileprivate enum CloudBucket {
        case clear, partly, overcast, fullOvercast, unknown

        static func from(description raw: String) -> CloudBucket {
            let s = raw.lowercased()
            if s.contains("partly cloudy") || s.contains("mostly clear") {
                return .partly
            }
            if s.contains("mostly cloudy") {
                return .overcast
            }
            if s.contains("overcast") || s.contains("foggy") {
                return .fullOvercast
            }
            if s.contains("cloudy") {
                return .overcast
            }
            if s.contains("clear") || s.contains("sunny") || s.contains("fair") {
                return .clear
            }
            return .unknown
        }
    }

    private static func cloudCoverFactor(context: Context) -> Scored {
        let bucket = context.cloudBucket
        let (delta, explanation, impact): (Int, String, ConditionFactor.Impact)
        switch bucket {
        case .partly:
            (delta, explanation, impact) = (
                8, "Partly cloudy — diffused light keeps fish less wary and active near cover.",
                .positive
            )
        case .overcast:
            (delta, explanation, impact) = (
                6, "Overcast skies suppress the surface glare and extend the feeding window.",
                .positive
            )
        case .fullOvercast:
            (delta, explanation, impact) = (
                4, "Full overcast — low light helps walleye, perch, and any sight-feeders.",
                .positive
            )
        case .clear:
            (delta, explanation, impact) = (
                2, "Bright sun — fish retreat to shaded structure and depth.",
                .neutral
            )
        case .unknown:
            (delta, explanation, impact) = (
                3, "Cloud cover unclear — assuming neutral light conditions.",
                .neutral
            )
        }
        return Scored(
            delta: delta,
            factor: ConditionFactor(
                name: "Cloud Cover",
                impact: impact,
                explanation: explanation,
                delta: delta
            )
        )
    }

    // MARK: - 7. Precipitation

    fileprivate enum PrecipBucket {
        case none, light, moderate, heavy

        static func from(chance: Double, description raw: String) -> PrecipBucket {
            let s = raw.lowercased()
            let heavy = s.contains("heavy rain")
                || s.contains("thunder") || s.contains("storm")
                || s.contains("downpour")
            if heavy { return .heavy }
            if s.contains("drizzle") || s.contains("light rain") { return .light }
            if s.contains("shower") || s.contains("rain") {
                return chance > 0.6 ? .moderate : .light
            }
            return .none
        }
    }

    private static func precipitationFactor(context: Context) -> Scored {
        let bucket = context.precipBucket
        let (delta, explanation, impact): (Int, String, ConditionFactor.Impact)
        switch bucket {
        case .light:
            (delta, explanation, impact) = (
                7, "Light rain washes insects and worms into the water — surface bite turns on.",
                .positive
            )
        case .moderate:
            (delta, explanation, impact) = (
                3, "Moderate rain — visibility drops but fish still feed around inflows.",
                .neutral
            )
        case .heavy:
            (delta, explanation, impact) = (
                0, "Heavy rain muddies the water and shuts the bite down.",
                .negative
            )
        case .none:
            if context.recentPrecipitation {
                (delta, explanation, impact) = (
                    5, "Rain has just cleared — fish are active in the post-front window.",
                    .positive
                )
            } else {
                (delta, explanation, impact) = (
                    5, "Stable, dry conditions — predictable feeding patterns.",
                    .positive
                )
            }
        }
        return Scored(
            delta: delta,
            factor: ConditionFactor(
                name: "Precipitation",
                impact: impact,
                explanation: explanation,
                delta: delta
            )
        )
    }

    // MARK: - Species ranking

    private static func rankSpecies(
        context: Context,
        environmentalScore: Int
    ) -> [SpeciesPrediction] {
        context.targetSpecies.map { species -> SpeciesPrediction in
            let profile = species.profile
            var score = environmentalScore

            // Bladder-driven pressure modifier.
            if context.trend == .rapidRise {
                score += profile.bladderType == .physoclistous ? -15 : -5
            }
            if context.trend == .rapidFall {
                score += profile.bladderType == .physostomous ? 3 : 0
            }

            // Per-species temperature fit.
            if profile.peakTempF.contains(context.tempF) {
                score += 5
            } else if profile.toleranceTempF.contains(context.tempF) {
                // tolerance only — no bump
            } else {
                score -= 10
            }

            // Season fit.
            if profile.peakSeasons.contains(context.season) {
                score += 10
            }

            // Behavioural time-of-day adjustments.
            score += behaviouralTimeBonus(species: species, context: context)

            // Species-specific temperature ceilings.
            score = applyTemperatureCeilings(score: score, species: species, tempF: context.tempF)

            let clamped = max(0, min(100, score))
            return SpeciesPrediction(
                species: profile.name,
                likelihood: clamped,
                tip: tip(for: species, context: context),
                symbolName: profile.symbolName
            )
        }
        .sorted { $0.likelihood > $1.likelihood }
    }

    private static func behaviouralTimeBonus(
        species: TargetSpecies,
        context: Context
    ) -> Int {
        let hour = context.hour
        let isDawn = (5...7).contains(hour)
        let isDusk = (18...20).contains(hour)
        let isMidday = (10...14).contains(hour)
        let isNight = hour < 5 || hour >= 21
        let isOvercast = context.cloudBucket == .overcast
            || context.cloudBucket == .fullOvercast
        let isLightRain = context.precipBucket == .light

        switch species {
        case .walleye, .yellowPerch:
            // Tapetum lucidum gives them a low-light vision edge.
            return (isDawn || isDusk) ? 5 : 0
        case .largemouthBass, .smallmouthBass:
            var bump = 0
            if isDawn { bump += 5 }
            if isMidday && context.cloudBucket == .clear { bump -= 5 }
            return bump
        case .brookTrout, .brownTrout, .rainbowTrout, .lakeTrout:
            return (isOvercast || isLightRain) ? 5 : 0
        case .channelCatfish:
            return isNight ? 5 : 0
        case .blackCrappie:
            return (isDawn || isDusk || isOvercast) ? 5 : 0
        case .northernPike, .chainPickerel, .bluegill:
            return 0
        }
    }

    private static func applyTemperatureCeilings(
        score: Int, species: TargetSpecies, tempF: Double
    ) -> Int {
        // Trout suffer above 70°F — capped at 30% of normal to reflect
        // thermal stress and the conservation case for leaving them alone.
        let trout: Set<TargetSpecies> = [.brookTrout, .brownTrout, .rainbowTrout, .lakeTrout]
        if trout.contains(species), tempF > 70 {
            return min(score, Int(Double(score) * 0.3))
        }
        // Warmwater species shut down below 40°F.
        let warmwater: Set<TargetSpecies> = [.largemouthBass, .smallmouthBass, .blackCrappie, .bluegill]
        if warmwater.contains(species), tempF < 40 {
            return min(score, Int(Double(score) * 0.2))
        }
        return score
    }

    private static func tip(for species: TargetSpecies, context: Context) -> String {
        let pressureDropping = context.trend == .rapidFall || context.trend == .slowFall
        let season = context.season

        switch species {
        case .largemouthBass:
            if season == .spring { return "Bass are pre-spawn — target shallow structure with crankbaits." }
            if pressureDropping { return "Falling pressure has bass moving — burn a spinnerbait along weed edges." }
            return "Work soft plastics around docks and laydowns; topwater early and late."
        case .smallmouthBass:
            return "Drag tubes or Ned rigs over rocky points — smallies key on current breaks."
        case .brookTrout:
            return "Drift small dries or beadhead nymphs through cold riffles — long, light leaders."
        case .brownTrout:
            if pressureDropping { return "Pressure drop has browns feeding near the surface — try streamers in low light." }
            return "Swing a wet fly or strip a streamer through deep pools at dawn."
        case .rainbowTrout:
            return "Suspend a small spinner or egg pattern under an indicator in soft seams."
        case .lakeTrout:
            return "Jig white tubes or troll spoons over deep points — lakers hunt the thermocline."
        case .walleye:
            return "Walleye vision peaks at dusk — fish rocky points with jigs tipped with minnows."
        case .yellowPerch:
            return "Bottom-bounce small jigs tipped with worm over sandy flats and weed lines."
        case .chainPickerel:
            return "Throw flashy spoons over shallow weed flats — pickerel ambush from cover."
        case .northernPike:
            return "Pike are aggressive in cool temps — use large spinnerbaits or jerkbaits along weed lines."
        case .blackCrappie:
            return "Vertical-jig minnows over brush piles in 8–15 ft — slow and steady draws strikes."
        case .bluegill:
            return "Drop a small popper or worm-and-bobber along docks and shoreline cover."
        case .channelCatfish:
            return "Anchor near drop-offs after dark with cut bait or stinkbait — stained water helps."
        }
    }

    // MARK: - Next best window

    private static func nextBestWindow(
        context: Context,
        hourly: [HourlyForecast]
    ) -> DateInterval? {
        guard !hourly.isEmpty else { return nil }
        let window = hourly.prefix(48)

        let scored: [(date: Date, score: Int)] = window.map { hour in
            (hour.date, simplifiedHourlyScore(hour: hour, context: context))
        }

        // Find first contiguous block of >= 2 hours scoring >= 65.
        var blockStart: Date?
        var blockEnd: Date?
        for (i, point) in scored.enumerated() {
            if point.score >= 65 {
                if blockStart == nil { blockStart = point.date }
                blockEnd = scored[safe: i + 1]?.date ?? point.date.addingTimeInterval(3600)
            } else if let start = blockStart, let end = blockEnd {
                if end.timeIntervalSince(start) >= 2 * 3600 {
                    return DateInterval(start: start, end: end)
                }
                blockStart = nil
                blockEnd = nil
            }
        }
        if let start = blockStart, let end = blockEnd,
           end.timeIntervalSince(start) >= 2 * 3600 {
            return DateInterval(start: start, end: end)
        }

        // Fallback: surface the single best hour available.
        if let best = scored.max(by: { $0.score < $1.score }) {
            return DateInterval(
                start: best.date,
                end: best.date.addingTimeInterval(3600)
            )
        }
        return nil
    }

    /// Cheap per-hour score used purely for finding the next bright window.
    /// Extrapolates the current pressure trend and reuses the constant moon
    /// info (it doesn't change meaningfully across 48h).
    private static func simplifiedHourlyScore(
        hour: HourlyForecast, context: Context
    ) -> Int {
        var score = 30

        // Trend persists with diminishing weight over the next ~12h, then fades.
        let hoursAhead = max(0, hour.date.timeIntervalSince(context.date) / 3600)
        let trendWeight = max(0.0, 1.0 - hoursAhead / 24.0)
        let trendBaseline: Int
        switch context.trend {
        case .rapidFall: trendBaseline = 25
        case .slowFall:  trendBaseline = 20
        case .steady:    trendBaseline = 15
        case .slowRise:  trendBaseline = 8
        case .rapidRise: trendBaseline = 3
        }
        score += Int(Double(trendBaseline) * trendWeight)
        score += Int(15 * (1 - trendWeight))   // pressure neutralizes over time

        // Temperature
        let tempF = hour.temperature.converted(to: .fahrenheit).value
        let target = context.averagedTempTarget
        if target.peak.contains(tempF)        { score += 20 }
        else if target.tolerance.contains(tempF) { score += 12 }
        else if distance(from: tempF, to: target.tolerance) <= 5 { score += 6 }

        // Time of day
        let hourOfDay = Calendar.current.component(.hour, from: hour.date)
        if (5...7).contains(hourOfDay) || (18...20).contains(hourOfDay) {
            score += 15
        } else if (10...14).contains(hourOfDay) && context.season == .summer {
            score -= 5
        }

        // Moon (constant within the 48h window)
        if let phase = context.moon?.phase {
            switch phase {
            case .newMoon, .fullMoon: score += 10
            case .waxingGibbous, .waningGibbous: score += 7
            case .firstQuarter, .lastQuarter: score += 5
            case .waxingCrescent, .waningCrescent: score += 3
            }
        } else {
            score += 5
        }

        // Wind
        let mph = hour.windSpeed.converted(to: .milesPerHour).value
        switch mph {
        case ..<8:    score += 10
        case 8..<15:  score += 7
        case 15..<20: score += 4
        case 20..<25: score += 1
        default:      break
        }

        // Precipitation (chance as a proxy for intensity)
        if hour.precipitationChance >= 0.6 { score += 0 }
        else if hour.precipitationChance >= 0.2 { score += 7 }
        else { score += 5 }

        // Cloud cover
        switch CloudBucket.from(description: hour.conditionDescription) {
        case .partly:       score += 8
        case .overcast:     score += 6
        case .fullOvercast: score += 4
        case .clear:        score += 2
        case .unknown:      score += 3
        }

        return max(0, min(100, score))
    }

    // MARK: - Summary + avoid reason

    private static func buildSummary(
        score: Int,
        rating: FishingScore.Rating,
        factors: [ConditionFactor],
        context: Context,
        nextWindow: DateInterval?
    ) -> String {
        let positives = factors
            .filter { $0.impact == .positive }
            .sorted { $0.delta > $1.delta }
        let negatives = factors
            .filter { $0.impact == .negative }
            .sorted { $0.delta < $1.delta }

        var lead: String
        if score >= 80 {
            let driver = positives.first?.explanation
                ?? "Everything is lining up across the board."
            lead = driver
        } else if score >= 60 {
            let pos = positives.prefix(2).map(\.explanation).joined(separator: " ")
            lead = pos.isEmpty ? "Conditions are firmly in the productive range." : pos
        } else if score >= 40 {
            let pos = positives.first?.explanation ?? "There's enough working in your favor to fish."
            let neg = negatives.first?.explanation ?? ""
            lead = neg.isEmpty ? pos : "\(pos) That said, \(neg.lowercaseFirst)"
        } else {
            let neg = negatives.first?.explanation
                ?? "Conditions are stacked against the bite right now."
            lead = neg
        }

        let outlook: String
        switch rating {
        case .excellent:
            outlook = "This is one of the best windows you'll see this week."
        case .good:
            outlook = "A solid window — get on the water if you can."
        case .fair:
            outlook = nextWindow.map { interval in
                "Conditions improve around \(Self.formatWindow(interval)) — fishable now, better later."
            } ?? "Mixed signals, but fish are catchable with the right approach."
        case .poor:
            outlook = nextWindow.map { interval in
                "Your next good overall window opens \(Self.formatWindow(interval))."
            } ?? "Tough conditions — better to wait this one out."
        }

        return "\(lead) \(outlook)"
    }

    private static func buildAvoidReason(
        context: Context, factors: [ConditionFactor]
    ) -> String {
        let worst = factors
            .filter { $0.impact == .negative }
            .sorted { $0.delta < $1.delta }
            .first
        return worst?.explanation
            ?? "Multiple factors are working against the bite — conserve your time for a better window."
    }

    private static func formatWindow(_ interval: DateInterval) -> String {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"

        let startStr = formatter.string(from: interval.start)
        let endStr = formatter.string(from: interval.end)

        let dayDesc: String
        if calendar.isDateInToday(interval.start) {
            dayDesc = "today"
        } else if calendar.isDateInTomorrow(interval.start) {
            dayDesc = "tomorrow"
        } else {
            let dayFormatter = DateFormatter()
            dayFormatter.dateFormat = "EEEE"
            dayDesc = "on \(dayFormatter.string(from: interval.start))"
        }
        return "\(dayDesc) from \(startStr) to \(endStr)"
    }
}

// MARK: - Small helpers

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

private extension String {
    var capitalizedFirst: String {
        guard let first = first else { return self }
        return first.uppercased() + dropFirst()
    }

    var lowercaseFirst: String {
        guard let first = first else { return self }
        return first.lowercased() + dropFirst()
    }
}
