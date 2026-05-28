import SwiftUI

/// Hero card: large score ring + rating label + plain-English summary.
/// When `interactive` is true a "Tap for full breakdown →" hint appears at
/// the bottom — the surrounding `NavigationLink` provides the actual push.
struct FishingScoreCard: View {
    let score: FishingScore
    var interactive: Bool = false

    var body: some View {
        FishCastCard {
            VStack(spacing: Spacing.md) {
                ScoreRingView(score: score.score, ringDiameter: 180, lineWidth: 12)

                Text(score.rating.label.uppercased())
                    .font(.appTitle2)
                    .foregroundStyle(ratingColor)
                    .tracking(1.5)

                Text(score.summaryText)
                    .font(.appBody)
                    .foregroundStyle(Color.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, Spacing.xs)

                if interactive {
                    HStack(spacing: 4) {
                        Text("Tap for full breakdown")
                        Image(systemName: "chevron.right")
                    }
                    .font(.appCaption)
                    .foregroundStyle(Color.textTertiary)
                    .padding(.top, Spacing.xxs)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var ratingColor: Color {
        switch score.rating {
        case .excellent: return .scoreExcellent
        case .good:      return .scoreGood
        case .fair:      return .scoreFair
        case .poor:      return .scorePoor
        }
    }
}

#Preview {
    FishingScoreCard(
        score: FishingScore(
            score: 82,
            rating: .excellent,
            factors: [],
            summary: "Pressure is dropping steadily — fish are on a pre-front feeding push. This is one of the best windows you'll see this week."
        ),
        interactive: true
    )
    .padding(Layout.screenEdge)
    .background(Color.primaryBackground)
}
