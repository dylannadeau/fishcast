import SwiftUI

/// Compact 3-day outlook strip — today, tomorrow, day-after — with a small
/// score ring, high/low temps, condition icon, and the best window of the
/// day (when hourly data is available for that day).
struct ThreeDayOutlookView: View {
    let days: [Day]

    struct Day: Identifiable {
        var id: Date { date }
        let date: Date
        let score: Int
        let rating: FishingScore.Rating
        let highF: Double
        let lowF: Double
        let symbolName: String
        let conditionDescription: String
        let bestWindowStart: Date?
        let bestWindowEnd: Date?
    }

    var body: some View {
        HStack(spacing: Spacing.sm) {
            ForEach(days) { day in
                DayCard(day: day)
            }
        }
    }
}

private struct DayCard: View {
    let day: ThreeDayOutlookView.Day

    var body: some View {
        FishCastCard {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(dayLabel.uppercased())
                    .font(.appCaption)
                    .foregroundStyle(Color.textSecondary)
                    .tracking(1.5)

                HStack(alignment: .top, spacing: Spacing.xs) {
                    ScoreRingView(score: day.score, ringDiameter: 56, lineWidth: 5)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(day.rating.label)
                            .font(.appCallout)
                            .foregroundStyle(color)
                        HStack(spacing: 2) {
                            Image(systemName: day.symbolName)
                                .foregroundStyle(Color.accentGoldLight)
                            Text("\(Int(day.highF.rounded()))° / \(Int(day.lowF.rounded()))°")
                                .font(.appCaption.monospacedDigit())
                                .foregroundStyle(Color.textPrimary)
                        }
                    }
                }

                if let start = day.bestWindowStart, let end = day.bestWindowEnd {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Best Window".uppercased())
                            .font(.system(size: 9, weight: .semibold))
                            .tracking(1.0)
                            .foregroundStyle(Color.textTertiary)
                        Text(rangeLabel(start: start, end: end))
                            .font(.appCaption.monospacedDigit())
                            .foregroundStyle(Color.textPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    private var dayLabel: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(day.date) { return "Today" }
        if calendar.isDateInTomorrow(day.date) { return "Tomorrow" }
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: day.date)
    }

    private var color: Color {
        switch day.rating {
        case .excellent: return .scoreExcellent
        case .good:      return .scoreGood
        case .fair:      return .scoreFair
        case .poor:      return .scorePoor
        }
    }

    private func rangeLabel(start: Date, end: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return "\(formatter.string(from: start))–\(formatter.string(from: end))"
    }

    private var accessibilityLabel: String {
        var label = "\(dayLabel), score \(day.score), \(day.rating.label). High \(Int(day.highF.rounded())), low \(Int(day.lowF.rounded()))."
        if let start = day.bestWindowStart, let end = day.bestWindowEnd {
            label += " Best window \(rangeLabel(start: start, end: end))."
        }
        return label
    }
}
