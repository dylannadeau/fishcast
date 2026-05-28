import Charts
import SwiftUI

/// Drill-down sheet pushed from the Dashboard's hero score card.
/// Five sections: factor breakdown, 6-hour pressure chart, full species
/// ranking, solunar periods, and the next-48h hourly score list.
struct ConditionsDetailView: View {
    let snapshot: ConditionsSnapshot

    /// Bundles everything the detail view needs in one shot — the parent
    /// (DashboardView) snapshots its current view-model state when the user
    /// taps the score card, so the detail view doesn't depend on the live
    /// observable and can't tear if the dashboard refreshes underneath it.
    struct ConditionsSnapshot {
        let score: FishingScore
        let weather: CurrentWeather
        let trend: PressureTrend
        let pressureReadings: [PressureReading]
        let hourlyScores: [DashboardViewModel.HourlyScore]
        let moon: MoonInfo?
        let sunrise: Date?
        let sunset: Date?
    }

    var body: some View {
        ZStack {
            LinearGradient.gradientPrimary.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    scoreBreakdownSection
                    pressureChartSection
                    speciesSection
                    solunarSection
                    nextHoursSection
                }
                .padding(Layout.screenEdge)
            }
        }
        .navigationTitle("Conditions Detail")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.primaryBackground, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }

    // MARK: - 1. Score breakdown

    private var scoreBreakdownSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            SectionHeader(title: "Score Breakdown")

            FishCastCard {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    ForEach(snapshot.score.conditionFactors) { factor in
                        FactorRow(factor: factor)
                        if factor.id != snapshot.score.conditionFactors.last?.id {
                            Divider().background(Color.white.opacity(0.05))
                        }
                    }

                    HStack {
                        Text("TOTAL")
                            .font(.appCallout)
                            .foregroundStyle(Color.textSecondary)
                            .tracking(1.5)
                        Spacer()
                        Text("\(snapshot.score.overallScore) / 100")
                            .font(.appTitle2)
                            .foregroundStyle(Color.accentGold)
                            .monospacedDigit()
                    }
                    .padding(.top, Spacing.xs)
                }
            }
        }
    }

    // MARK: - 2. Historical pressure chart

    private var pressureChartSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            SectionHeader(title: "Pressure — Last 6 Hours")
            PressureTrendChart(
                readings: snapshot.pressureReadings,
                trend: snapshot.trend
            )
        }
    }

    // MARK: - 3. Species detail

    private var speciesSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            SectionHeader(title: "Species Outlook")

            FishCastCard {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    ForEach(rankedSpeciesPredictions, id: \.species) { prediction in
                        if let target = matchTarget(name: prediction.species) {
                            SpeciesDetailRow(
                                prediction: prediction,
                                target: target,
                                airTempF: snapshot.weather.temperature.converted(to: .fahrenheit).value,
                                date: snapshot.weather.date
                            )
                            if prediction.species != rankedSpeciesPredictions.last?.species {
                                Divider().background(Color.white.opacity(0.05))
                            }
                        }
                    }
                }
            }
        }
    }

    private var rankedSpeciesPredictions: [SpeciesPrediction] {
        FishingConditionsEngine.allSpeciesPredictions(
            weather: snapshot.weather,
            trend: snapshot.trend,
            date: snapshot.weather.date,
            moonInfo: snapshot.moon,
            sunrise: snapshot.sunrise,
            sunset: snapshot.sunset
        )
    }

    private func matchTarget(name: String) -> TargetSpecies? {
        TargetSpecies(rawValue: name)
    }

    // MARK: - 4. Solunar detail

    private var solunarSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            SectionHeader(title: "Solunar Periods")

            FishCastCard {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    if let moon = snapshot.moon {
                        HStack(spacing: Spacing.md) {
                            Image(systemName: moon.phase.symbolName)
                                .font(.system(size: 36))
                                .foregroundStyle(Color.accentGoldLight)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(moon.phase.label)
                                    .font(.appHeadline)
                                    .foregroundStyle(Color.textPrimary)
                                Text("\(Int((moon.illumination * 100).rounded()))% illuminated")
                                    .font(.appCaption)
                                    .foregroundStyle(Color.textSecondary)
                            }
                            Spacer()
                        }

                        Divider().background(Color.white.opacity(0.06))

                        ForEach(solunarPeriods(for: moon)) { period in
                            SolunarPeriodRow(period: period)
                        }
                    } else {
                        Text("Lunar data unavailable.")
                            .font(.appBody)
                            .foregroundStyle(Color.textTertiary)
                    }
                }
            }

            Text("Major periods (2hr windows) line up with the moon directly overhead or underfoot — historically the most productive feeding windows of the day. Minor periods (1hr windows) sit around moonrise and moonset.")
                .font(.appCaption)
                .foregroundStyle(Color.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - 5. Next 48 hours

    private var nextHoursSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            SectionHeader(title: "Next 48 Hours")

            FishCastCard {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(next48Hours) { hour in
                        NextHoursRow(
                            entry: hour,
                            isInWindow: snapshot.score.nextBestWindow?.contains(hour.hour.date) ?? false
                        )
                        if hour.id != next48Hours.last?.id {
                            Divider().background(Color.white.opacity(0.04))
                        }
                    }

                    if next48Hours.isEmpty {
                        Text("No forecast data available.")
                            .font(.appBody)
                            .foregroundStyle(Color.textTertiary)
                            .padding(.vertical, Spacing.md)
                    }
                }
            }
        }
    }

    private var next48Hours: [DashboardViewModel.HourlyScore] {
        let now = Date()
        return snapshot.hourlyScores
            .filter { $0.hour.date >= now.addingTimeInterval(-3600) }
            .prefix(48)
            .map { $0 }
    }

    // MARK: - Solunar window math

    private func solunarPeriods(for moon: MoonInfo) -> [SolunarPeriod] {
        var periods: [SolunarPeriod] = []
        if let rise = moon.moonrise {
            periods.append(SolunarPeriod(
                kind: .minor,
                start: rise.addingTimeInterval(-30 * 60),
                end:   rise.addingTimeInterval( 30 * 60),
                label: "Moonrise"
            ))
        }
        if let set = moon.moonset {
            periods.append(SolunarPeriod(
                kind: .minor,
                start: set.addingTimeInterval(-30 * 60),
                end:   set.addingTimeInterval( 30 * 60),
                label: "Moonset"
            ))
        }
        // Major windows: moon directly overhead (rise + 6h) and underfoot
        // (rise - 6h). Approximation good enough for an angler-facing UI.
        if let rise = moon.moonrise {
            let overhead = rise.addingTimeInterval(6 * 3600)
            periods.append(SolunarPeriod(
                kind: .major,
                start: overhead.addingTimeInterval(-3600),
                end:   overhead.addingTimeInterval( 3600),
                label: "Overhead"
            ))
            let underfoot = rise.addingTimeInterval(-6 * 3600)
            periods.append(SolunarPeriod(
                kind: .major,
                start: underfoot.addingTimeInterval(-3600),
                end:   underfoot.addingTimeInterval( 3600),
                label: "Underfoot"
            ))
        }
        return periods.sorted { $0.start < $1.start }
    }
}

// MARK: - Factor row

private struct FactorRow: View {
    let factor: ConditionFactor

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            Image(systemName: impactIcon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(impactColor)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(factor.name)
                        .font(.appHeadline)
                        .foregroundStyle(Color.textPrimary)
                    Spacer()
                    Text(deltaLabel)
                        .font(.appCallout.monospacedDigit())
                        .foregroundStyle(impactColor)
                }
                Text(factor.explanation)
                    .font(.appCaption)
                    .foregroundStyle(Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var impactIcon: String {
        switch factor.impact {
        case .positive: return "triangle.fill"
        case .neutral:  return "arrow.right"
        case .negative: return "triangle.fill"
        }
    }

    private var impactColor: Color {
        switch factor.impact {
        case .positive: return .scoreExcellent
        case .neutral:  return .textSecondary
        case .negative: return .scorePoor
        }
    }

    private var deltaLabel: String {
        let sign = factor.delta > 0 ? "+" : ""
        return "\(sign)\(factor.delta) pts"
    }
}

// MARK: - Species row

private struct SpeciesDetailRow: View {
    let prediction: SpeciesPrediction
    let target: TargetSpecies
    let airTempF: Double
    let date: Date

    private var fit: FishingConditionsEngine.TemperatureFit {
        FishingConditionsEngine.temperatureFit(for: target, currentTempF: airTempF)
    }

    private var inPeakSeason: Bool {
        FishingConditionsEngine.isInPeakSeason(target, date: date)
    }

    private var likelihoodColor: Color {
        switch prediction.likelihood {
        case 75...:      return .scoreExcellent
        case 55..<75:    return .scoreGood
        case 35..<55:    return .scoreFair
        default:         return .scorePoor
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(prediction.species)
                    .font(.appHeadline)
                    .foregroundStyle(Color.textPrimary)
                Spacer()
                Text("\(prediction.likelihood)%")
                    .font(.appHeadline.monospacedDigit())
                    .foregroundStyle(likelihoodColor)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.tertiaryBackground)
                        .frame(height: 5)
                    Capsule()
                        .fill(likelihoodColor)
                        .frame(
                            width: geometry.size.width * CGFloat(prediction.likelihood) / 100,
                            height: 5
                        )
                }
            }
            .frame(height: 5)

            HStack(spacing: Spacing.sm) {
                Label {
                    Text(inPeakSeason ? "Peak season" : "Off season")
                } icon: {
                    Image(systemName: inPeakSeason ? "leaf.fill" : "leaf")
                }
                .font(.appCaption)
                .foregroundStyle(inPeakSeason ? Color.scoreGood : Color.textTertiary)

                Label {
                    Text(fitLabel)
                } icon: {
                    Image(systemName: fitIcon)
                }
                .font(.appCaption)
                .foregroundStyle(fitColor)
            }
        }
        .padding(.vertical, 4)
    }

    private var fitLabel: String {
        switch fit {
        case .inPeakRange:      return "Peak temp"
        case .inToleranceRange: return "Tolerable"
        case .outOfRange:       return "Out of range"
        }
    }

    private var fitIcon: String {
        switch fit {
        case .inPeakRange:      return "checkmark.circle.fill"
        case .inToleranceRange: return "exclamationmark.triangle.fill"
        case .outOfRange:       return "xmark.circle.fill"
        }
    }

    private var fitColor: Color {
        switch fit {
        case .inPeakRange:      return .scoreExcellent
        case .inToleranceRange: return .scoreFair
        case .outOfRange:       return .scorePoor
        }
    }
}

// MARK: - Solunar models + rows

private struct SolunarPeriod: Identifiable {
    enum Kind { case major, minor }
    let id = UUID()
    let kind: Kind
    let start: Date
    let end: Date
    let label: String
}

private struct SolunarPeriodRow: View {
    let period: SolunarPeriod

    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f
    }()

    private var kindColor: Color {
        period.kind == .major ? .accentGold : .accentTeal
    }

    private var kindLabel: String {
        period.kind == .major ? "MAJOR" : "MINOR"
    }

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Text(kindLabel)
                .font(.system(size: 10, weight: .bold))
                .tracking(1.2)
                .foregroundStyle(kindColor)
                .frame(width: 50, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                Text(period.label)
                    .font(.appCallout)
                    .foregroundStyle(Color.textPrimary)
                Text("\(Self.formatter.string(from: period.start))–\(Self.formatter.string(from: period.end))")
                    .font(.appCaption.monospacedDigit())
                    .foregroundStyle(Color.textSecondary)
            }
            Spacer()
        }
    }
}

// MARK: - Next-hours row

private struct NextHoursRow: View {
    let entry: DashboardViewModel.HourlyScore
    let isInWindow: Bool

    private var color: Color {
        switch entry.score.rating {
        case .excellent: return .scoreExcellent
        case .good:      return .scoreGood
        case .fair:      return .scoreFair
        case .poor:      return .scorePoor
        }
    }

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Text(timeLabel)
                .font(.appCallout.monospacedDigit())
                .foregroundStyle(Color.textPrimary)
                .frame(width: 90, alignment: .leading)

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.tertiaryBackground)
                    .frame(height: 6)
                Capsule()
                    .fill(color)
                    .frame(width: barWidth, height: 6)
            }

            HStack(spacing: 4) {
                if entry.isGoldenHour {
                    Image(systemName: "sun.max.fill")
                        .foregroundStyle(Color.accentGoldLight)
                }
                if entry.isSolunarMajor {
                    Image(systemName: "moon.fill")
                        .foregroundStyle(Color.accentTeal)
                }
                Text("\(entry.score.score)")
                    .font(.appCallout.monospacedDigit())
                    .foregroundStyle(color)
            }
            .frame(width: 64, alignment: .trailing)
        }
        .padding(.vertical, 6)
        .background(isInWindow ? Color.scoreExcellent.opacity(0.12) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private var barWidth: CGFloat {
        let maxWidth: CGFloat = 100
        return max(8, CGFloat(entry.score.score) / 100 * maxWidth)
    }

    private var timeLabel: String {
        let formatter = DateFormatter()
        let calendar = Calendar.current
        if calendar.isDateInToday(entry.hour.date) {
            formatter.dateFormat = "h a"
        } else if calendar.isDateInTomorrow(entry.hour.date) {
            formatter.dateFormat = "'Tom' h a"
        } else {
            formatter.dateFormat = "EEE h a"
        }
        return formatter.string(from: entry.hour.date)
    }
}
