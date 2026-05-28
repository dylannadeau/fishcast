import Charts
import SwiftUI

/// Hour-by-hour fishing-quality bars for the current day. Golden hours and
/// solunar major windows are flagged with inline glyphs above the bars and a
/// vertical rule marks the current time.
struct TodaysWindowsChart: View {
    let scores: [DashboardViewModel.HourlyScore]

    @State private var now: Date = .now
    private let tickTimer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    var body: some View {
        FishCastCard {
            VStack(alignment: .leading, spacing: Spacing.md) {
                if scores.isEmpty {
                    placeholder
                } else {
                    chart
                    legend
                }
            }
        }
    }

    // MARK: - Chart

    private var chart: some View {
        Chart {
            ForEach(scores) { entry in
                BarMark(
                    x: .value("Hour", entry.hour.date, unit: .hour),
                    y: .value("Score", entry.score.score),
                    width: .ratio(0.6)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [color(for: entry).opacity(0.85), color(for: entry).opacity(0.45)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .cornerRadius(4)
                .annotation(position: .top, alignment: .center, spacing: 2) {
                    annotationGlyphs(for: entry)
                }
            }

            // Current-time indicator.
            if let bounds = chartBounds, bounds.contains(now) {
                RuleMark(x: .value("Now", now))
                    .foregroundStyle(Color.accentGold.opacity(0.9))
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
                    .annotation(position: .top, alignment: .center) {
                        Text("Now")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(Color.accentGold)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.primaryBackground)
                            .clipShape(Capsule())
                    }
            }
        }
        .chartYScale(domain: 0...100)
        .chartYAxis {
            AxisMarks(values: [0, 50, 100]) { _ in
                AxisGridLine().foregroundStyle(Color.textTertiary.opacity(0.25))
                AxisValueLabel().foregroundStyle(Color.textSecondary)
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .hour, count: 3)) { _ in
                AxisGridLine().foregroundStyle(Color.textTertiary.opacity(0.2))
                AxisValueLabel(format: .dateTime.hour(.defaultDigits(amPM: .narrow)))
                    .foregroundStyle(Color.textSecondary)
            }
        }
        .frame(height: 170)
        .onReceive(tickTimer) { now = $0 }
    }

    @ViewBuilder
    private func annotationGlyphs(for entry: DashboardViewModel.HourlyScore) -> some View {
        if entry.isGoldenHour || entry.isSolunarMajor {
            HStack(spacing: 2) {
                if entry.isGoldenHour {
                    Image(systemName: "sun.max.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(Color.accentGoldLight)
                }
                if entry.isSolunarMajor {
                    Image(systemName: "moon.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(Color.accentTeal)
                }
            }
        }
    }

    private var chartBounds: ClosedRange<Date>? {
        guard let first = scores.first?.hour.date,
              let last = scores.last?.hour.date
        else { return nil }
        return first...last.addingTimeInterval(3600)
    }

    private func color(for entry: DashboardViewModel.HourlyScore) -> Color {
        switch entry.score.rating {
        case .excellent: return .scoreExcellent
        case .good:      return .scoreGood
        case .fair:      return .scoreFair
        case .poor:      return .scorePoor
        }
    }

    // MARK: - Legend + placeholder

    private var legend: some View {
        HStack(spacing: Spacing.md) {
            legendDot(color: .scoreExcellent, label: "Excellent")
            legendDot(color: .scoreGood,      label: "Good")
            legendDot(color: .scoreFair,      label: "Fair")
            legendDot(color: .scorePoor,      label: "Poor")
            Spacer(minLength: 0)
            HStack(spacing: 4) {
                Image(systemName: "sun.max.fill").foregroundStyle(Color.accentGoldLight)
                Text("Golden")
            }
            HStack(spacing: 4) {
                Image(systemName: "moon.fill").foregroundStyle(Color.accentTeal)
                Text("Solunar")
            }
        }
        .font(.appCaption)
        .foregroundStyle(Color.textSecondary)
    }

    private func legendDot(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label)
        }
    }

    private var placeholder: some View {
        VStack(spacing: Spacing.xs) {
            Image(systemName: "chart.bar.fill")
                .font(.system(size: IconSize.hero))
                .foregroundStyle(Color.textTertiary)
            Text("No hourly data available yet.")
                .font(.appCallout)
                .foregroundStyle(Color.textSecondary)
        }
        .frame(maxWidth: .infinity, minHeight: 140)
    }
}
