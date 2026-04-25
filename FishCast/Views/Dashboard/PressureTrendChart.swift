import Charts
import SwiftUI

/// 6-hour barometric pressure line chart backed by `BarometricService` cache.
/// Renders a placeholder until at least two readings have been recorded.
struct PressureTrendChart: View {
    let readings: [PressureReading]
    let trend: PressureTrend

    private let windowHours: Double = 6

    private var windowed: [PressureReading] {
        let cutoff = Date().addingTimeInterval(-windowHours * 3600)
        return readings
            .filter { $0.timestamp >= cutoff }
            .sorted { $0.timestamp < $1.timestamp }
    }

    private var yDomain: ClosedRange<Double> {
        guard let min = windowed.map(\.pressure).min(),
              let max = windowed.map(\.pressure).max()
        else {
            return 1000 ... 1025
        }
        let pad = Swift.max((max - min) * 0.25, 1.0)
        return (min - pad) ... (max + pad)
    }

    var body: some View {
        FishCastCard {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack {
                    Text("Pressure (last 6h)")
                        .font(.appHeadline)
                        .foregroundStyle(Color.textPrimary)

                    Spacer()

                    Label(trend.description, systemImage: trend.symbolName)
                        .font(.appCallout)
                        .foregroundStyle(Color.accentGold)
                        .labelStyle(.titleAndIcon)
                }

                if windowed.count < 2 {
                    placeholder
                } else {
                    chart
                }
            }
        }
    }

    private var placeholder: some View {
        VStack(spacing: Spacing.xs) {
            Image(systemName: AppIcons.barometer)
                .font(.system(size: IconSize.hero))
                .foregroundStyle(Color.textTertiary)
            Text("Collecting readings…")
                .font(.appCallout)
                .foregroundStyle(Color.textSecondary)
            Text("Come back after an hour or two on the water — we cache readings locally to build the trend.")
                .font(.appCaption)
                .foregroundStyle(Color.textTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 140)
    }

    private var chart: some View {
        Chart(windowed, id: \.timestamp) { reading in
            AreaMark(
                x: .value("Time", reading.timestamp),
                y: .value("hPa", reading.pressure)
            )
            .interpolationMethod(.monotone)
            .foregroundStyle(LinearGradient(
                colors: [Color.accentGold.opacity(0.35), Color.accentGold.opacity(0.0)],
                startPoint: .top,
                endPoint: .bottom
            ))

            LineMark(
                x: .value("Time", reading.timestamp),
                y: .value("hPa", reading.pressure)
            )
            .interpolationMethod(.monotone)
            .foregroundStyle(Color.accentGold)
            .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round))
        }
        .chartYScale(domain: yDomain)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                AxisGridLine().foregroundStyle(Color.textTertiary.opacity(0.3))
                AxisValueLabel(format: .dateTime.hour(.defaultDigits(amPM: .abbreviated)))
                    .foregroundStyle(Color.textSecondary)
            }
        }
        .chartYAxis {
            AxisMarks(values: .automatic(desiredCount: 3)) { _ in
                AxisGridLine().foregroundStyle(Color.textTertiary.opacity(0.3))
                AxisValueLabel()
                    .foregroundStyle(Color.textSecondary)
            }
        }
        .frame(height: 140)
    }
}
