import Charts
import SwiftUI

/// 2×2 grid of "at a glance" condition cards: moon phase + illumination,
/// sun rise/set, moon rise/set, and a 3-hour pressure sparkline.
struct ConditionsSnapshotGrid: View {
    let moon: MoonInfo?
    let sunrise: Date?
    let sunset: Date?
    let pressureReadings: [PressureReading]
    let trend: PressureTrend

    private let columns = [
        GridItem(.flexible(), spacing: Spacing.sm),
        GridItem(.flexible(), spacing: Spacing.sm),
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: Spacing.sm) {
            moonPhaseCard
            sunTimesCard
            moonTimesCard
            pressureSparklineCard
        }
    }

    // MARK: - Cards

    private var moonPhaseCard: some View {
        SnapshotCard(title: "Moon Phase") {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: moon?.phase.symbolName ?? AppIcons.moon)
                        .font(.system(size: 28))
                        .foregroundStyle(Color.accentGoldLight)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(moon?.phase.label ?? "—")
                            .font(.appHeadline)
                            .foregroundStyle(Color.textPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        Text(illuminationLabel)
                            .font(.appCaption)
                            .foregroundStyle(Color.textSecondary)
                    }
                }
            }
        }
    }

    private var sunTimesCard: some View {
        SnapshotCard(title: "Sun") {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                timeRow(icon: "sunrise.fill", label: "Rise", date: sunrise, color: .accentGold)
                timeRow(icon: "sunset.fill",  label: "Set",  date: sunset,  color: .accentGoldLight)
            }
        }
    }

    private var moonTimesCard: some View {
        SnapshotCard(title: "Moon Times") {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                timeRow(icon: "moon.fill",          label: "Rise", date: moon?.moonrise, color: .accentTeal)
                timeRow(icon: "moon.zzz.fill",      label: "Set",  date: moon?.moonset,  color: .textSecondary)
            }
        }
    }

    private var pressureSparklineCard: some View {
        SnapshotCard(title: "Pressure (3h)") {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                if sparklineReadings.count >= 2 {
                    Chart(sparklineReadings, id: \.timestamp) { reading in
                        LineMark(
                            x: .value("t", reading.timestamp),
                            y: .value("mb", reading.pressure)
                        )
                        .interpolationMethod(.monotone)
                        .foregroundStyle(sparklineColor)
                        .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round))
                    }
                    .chartYScale(domain: sparklineDomain)
                    .chartXAxis(.hidden)
                    .chartYAxis(.hidden)
                    .frame(height: 36)
                } else {
                    Text("Collecting…")
                        .font(.appCaption)
                        .foregroundStyle(Color.textTertiary)
                        .frame(height: 36, alignment: .center)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                Text(trendDescription)
                    .font(.appCaption)
                    .foregroundStyle(Color.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
        }
    }

    // MARK: - Subviews

    private func timeRow(icon: String, label: String, date: Date?, color: Color) -> some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 18)
            Text(label.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .tracking(1.0)
                .foregroundStyle(Color.textSecondary)
            Spacer(minLength: 0)
            Text(date.map(Self.timeFormatter.string(from:)) ?? "—")
                .font(.appCallout.monospacedDigit())
                .foregroundStyle(Color.textPrimary)
        }
    }

    // MARK: - Helpers

    private var illuminationLabel: String {
        guard let illumination = moon?.illumination else { return "—" }
        return "\(Int((illumination * 100).rounded()))% lit"
    }

    private var sparklineReadings: [PressureReading] {
        let cutoff = Date().addingTimeInterval(-3 * 3600)
        return pressureReadings
            .filter { $0.timestamp >= cutoff }
            .sorted { $0.timestamp < $1.timestamp }
    }

    private var sparklineDomain: ClosedRange<Double> {
        guard let min = sparklineReadings.map(\.pressure).min(),
              let max = sparklineReadings.map(\.pressure).max()
        else { return 1000...1025 }
        let pad = Swift.max((max - min) * 0.3, 0.5)
        return (min - pad)...(max + pad)
    }

    private var sparklineColor: Color {
        switch trend {
        case .rapidFall, .slowFall: return .scoreExcellent
        case .steady:               return .accentGold
        case .slowRise:             return .scoreFair
        case .rapidRise:            return .scorePoor
        }
    }

    private var trendDescription: String { trend.description }

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f
    }()
}

/// Square grid card with a uniform header/body layout.
private struct SnapshotCard<Content: View>: View {
    let title: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        FishCastCard {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(title.uppercased())
                    .font(.appCaption)
                    .foregroundStyle(Color.textSecondary)
                    .tracking(1.5)
                content()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
