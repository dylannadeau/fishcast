import Charts
import SwiftUI

/// Station name + sine-curve chart + hi/lo readout. Hidden entirely when the
/// `ForecastViewModel.tide` is nil (inland location).
struct TideSection: View {
    let forecast: TideForecast

    var body: some View {
        FishCastCard {
            VStack(alignment: .leading, spacing: Spacing.md) {
                stationHeader

                if forecast.predictions.count >= 2 {
                    TideChart(events: forecast.predictions)
                } else {
                    placeholder
                }

                eventsRow
            }
        }
    }

    private var stationHeader: some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: "water.waves")
                .foregroundStyle(Color.accentTeal)
            Text(forecast.station.name)
                .font(.appHeadline)
                .foregroundStyle(Color.textPrimary)
                .lineLimit(2)
            Spacer()
        }
    }

    private var placeholder: some View {
        Text("No tide events available for today.")
            .font(.appCallout)
            .foregroundStyle(Color.textSecondary)
            .frame(maxWidth: .infinity, minHeight: 120, alignment: .center)
    }

    @ViewBuilder
    private var eventsRow: some View {
        if !forecast.predictions.isEmpty {
            HStack(spacing: Spacing.sm) {
                ForEach(forecast.predictions) { event in
                    TideEventCell(event: event)
                }
            }
        }
    }
}

// MARK: - Chart

struct TideChart: View {
    let events: [TidePrediction]

    private var sortedEvents: [TidePrediction] {
        events.sorted { $0.time < $1.time }
    }

    /// 30-minute samples interpolated between hi/lo events using a half-cosine
    /// (smooth sine-shaped curve) — matches how tides actually swell.
    private var samples: [TideSample] {
        guard let first = sortedEvents.first,
              let last = sortedEvents.last else { return [] }

        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: first.time)
        let dayEnd = dayStart.addingTimeInterval(24 * 3600)
        let step: TimeInterval = 30 * 60

        var output: [TideSample] = []
        var cursor = dayStart
        while cursor <= dayEnd {
            let height = interpolatedHeight(at: cursor, first: first, last: last)
            output.append(TideSample(time: cursor, heightFeet: height))
            cursor.addTimeInterval(step)
        }
        return output
    }

    private func interpolatedHeight(
        at time: Date,
        first: TidePrediction,
        last: TidePrediction
    ) -> Double {
        // Find bracketing pair
        for i in 0 ..< (sortedEvents.count - 1) {
            let a = sortedEvents[i]
            let b = sortedEvents[i + 1]
            if time >= a.time && time <= b.time {
                let span = b.time.timeIntervalSince(a.time)
                guard span > 0 else { return a.heightFeet }
                let phase = (time.timeIntervalSince(a.time) / span) * .pi
                return a.heightFeet + (b.heightFeet - a.heightFeet) * (1 - cos(phase)) / 2
            }
        }
        // Outside the event range — clamp to nearest endpoint
        if time < first.time { return first.heightFeet }
        return last.heightFeet
    }

    var body: some View {
        Chart {
            ForEach(samples) { sample in
                AreaMark(
                    x: .value("Time", sample.time),
                    y: .value("Feet", sample.heightFeet)
                )
                .interpolationMethod(.monotone)
                .foregroundStyle(LinearGradient(
                    colors: [Color.accentTeal.opacity(0.45), Color.accentTeal.opacity(0.0)],
                    startPoint: .top,
                    endPoint: .bottom
                ))
            }

            ForEach(samples) { sample in
                LineMark(
                    x: .value("Time", sample.time),
                    y: .value("Feet", sample.heightFeet)
                )
                .interpolationMethod(.monotone)
                .foregroundStyle(Color.accentTeal)
                .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round))
            }

            ForEach(sortedEvents) { event in
                PointMark(
                    x: .value("Time", event.time),
                    y: .value("Feet", event.heightFeet)
                )
                .symbolSize(80)
                .foregroundStyle(event.type == .high ? Color.accentGold : Color.accentGoldLight)
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .hour, count: 6)) { _ in
                AxisGridLine().foregroundStyle(Color.textTertiary.opacity(0.3))
                AxisValueLabel(format: .dateTime.hour(.defaultDigits(amPM: .abbreviated)))
                    .foregroundStyle(Color.textSecondary)
            }
        }
        .chartYAxis {
            AxisMarks(values: .automatic(desiredCount: 3)) { _ in
                AxisGridLine().foregroundStyle(Color.textTertiary.opacity(0.3))
                AxisValueLabel().foregroundStyle(Color.textSecondary)
            }
        }
        .frame(height: 160)
    }
}

struct TideSample: Identifiable, Sendable {
    var id: Date { time }
    let time: Date
    let heightFeet: Double
}

// MARK: - Event cell

private struct TideEventCell: View {
    let event: TidePrediction

    private var icon: String {
        event.type == .high ? "arrow.up.to.line" : "arrow.down.to.line"
    }

    private var iconColor: Color {
        event.type == .high ? Color.accentGold : Color.accentTeal
    }

    private var label: String {
        event.type == .high ? "High" : "Low"
    }

    var body: some View {
        VStack(spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                Text(label.uppercased())
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(1.0)
            }
            .foregroundStyle(iconColor)

            Text(event.time.formatted(.dateTime.hour().minute()))
                .font(.appCallout)
                .foregroundStyle(Color.textPrimary)
                .monospacedDigit()

            Text(String(format: "%.1f ft", event.heightFeet))
                .font(.appCaption)
                .foregroundStyle(Color.textSecondary)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.xs)
        .background(Color.tertiaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: Layout.radiusSm))
    }
}
