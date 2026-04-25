import SwiftUI

/// Horizontal 24-hour timeline of fishing-quality scores.
/// Peak windows (rating >= good) surface their numeric score above the bar.
struct BestTimesTimelineView: View {
    let scores: [DashboardViewModel.HourlyScore]

    var body: some View {
        FishCastCard {
            VStack(alignment: .leading, spacing: Spacing.md) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .bottom, spacing: 6) {
                        ForEach(scores) { entry in
                            HourBar(entry: entry)
                        }
                    }
                    .padding(.vertical, Spacing.xs)
                }

                HStack(spacing: Spacing.md) {
                    legendItem(color: .scoreExcellent, label: "Excellent")
                    legendItem(color: .scoreGood,      label: "Good")
                    legendItem(color: .scoreFair,      label: "Fair")
                    legendItem(color: .scorePoor,      label: "Poor")
                }
                .font(.appCaption)
                .foregroundStyle(Color.textSecondary)
            }
        }
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
        }
    }
}

private struct HourBar: View {
    let entry: DashboardViewModel.HourlyScore

    private let maxBarHeight: CGFloat = 90

    private var barHeight: CGFloat {
        max(6, CGFloat(entry.score.score) / 100 * maxBarHeight)
    }

    private var isPeak: Bool { entry.score.score >= 70 }

    private var barColor: Color {
        switch entry.score.rating {
        case .excellent: return .scoreExcellent
        case .good:      return .scoreGood
        case .fair:      return .scoreFair
        case .poor:      return .scorePoor
        }
    }

    private var hourLabel: String {
        entry.hour.date.formatted(.dateTime.hour(.defaultDigits(amPM: .abbreviated)))
    }

    var body: some View {
        VStack(spacing: 4) {
            Text(isPeak ? "\(entry.score.score)" : " ")
                .font(.appCaption)
                .foregroundStyle(isPeak ? Color.accentGold : Color.clear)
                .fontWeight(isPeak ? .semibold : .regular)

            RoundedRectangle(cornerRadius: 4)
                .fill(LinearGradient(
                    colors: [barColor, barColor.opacity(0.5)],
                    startPoint: .top,
                    endPoint: .bottom
                ))
                .frame(width: 16, height: barHeight)

            Text(hourLabel)
                .font(.system(size: 10))
                .foregroundStyle(Color.textTertiary)
                .fixedSize()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(hourLabel): score \(entry.score.score), \(entry.score.rating.label)")
    }
}
