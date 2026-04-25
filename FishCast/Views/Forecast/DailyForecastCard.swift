import SwiftUI

/// Single row in the 7-day forecast list.
struct DailyForecastCard: View {
    let entry: ForecastViewModel.DailyEntry

    private var weekday: String {
        if Calendar.current.isDateInToday(entry.day.date) { return "Today" }
        return entry.day.date.formatted(.dateTime.weekday(.wide))
    }

    private var dateLabel: String {
        entry.day.date.formatted(.dateTime.month(.abbreviated).day())
    }

    private var highText: String {
        "\(Int(entry.day.highTemperature.converted(to: .fahrenheit).value.rounded()))°"
    }

    private var lowText: String {
        "\(Int(entry.day.lowTemperature.converted(to: .fahrenheit).value.rounded()))°"
    }

    private var ratingColor: Color {
        switch entry.score.rating {
        case .excellent: return .scoreExcellent
        case .good:      return .scoreGood
        case .fair:      return .scoreFair
        case .poor:      return .scorePoor
        }
    }

    var body: some View {
        FishCastCard {
            HStack(spacing: Spacing.md) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(weekday)
                        .font(.appHeadline)
                        .foregroundStyle(Color.textPrimary)
                        .lineLimit(1)
                    Text(dateLabel)
                        .font(.appCaption)
                        .foregroundStyle(Color.textSecondary)
                }
                .frame(width: 84, alignment: .leading)

                Image(systemName: entry.day.symbolName)
                    .font(.system(size: 22))
                    .foregroundStyle(Color.accentGold)
                    .frame(width: 32)
                    .symbolRenderingMode(.hierarchical)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Image(systemName: "thermometer.high")
                            .font(.caption2)
                            .foregroundStyle(Color.scoreFair)
                        Text(highText)
                            .font(.appCallout)
                            .foregroundStyle(Color.textPrimary)
                    }
                    HStack(spacing: 4) {
                        Image(systemName: "thermometer.low")
                            .font(.caption2)
                            .foregroundStyle(Color.accentTeal)
                        Text(lowText)
                            .font(.appCallout)
                            .foregroundStyle(Color.textSecondary)
                    }
                }

                Spacer()

                VStack(spacing: 0) {
                    Text("\(entry.score.score)")
                        .font(.appTitle2)
                        .fontWeight(.bold)
                        .foregroundStyle(ratingColor)
                    Text(entry.score.rating.label.uppercased())
                        .font(.system(size: 9))
                        .foregroundStyle(Color.textSecondary)
                        .tracking(1.0)
                }
                .frame(width: 60)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(weekday) \(dateLabel): high \(highText), low \(lowText), score \(entry.score.score), \(entry.score.rating.label)"
        )
    }
}
