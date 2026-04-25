import SwiftUI

/// Hero card: large score ring + rating label + plain-English summary.
struct FishingScoreCard: View {
    let score: FishingScore

    var body: some View {
        FishCastCard {
            VStack(spacing: Spacing.md) {
                ScoreRingView(score: score.score, ringDiameter: 180, lineWidth: 12)

                Text(score.rating.label.uppercased())
                    .font(.appTitle2)
                    .foregroundStyle(ratingColor)
                    .tracking(1.5)

                Text(score.summary)
                    .font(.appBody)
                    .foregroundStyle(Color.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, Spacing.xs)
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
    FishingScoreCard(score: FishingScore(
        score: 82,
        rating: .excellent,
        factors: [],
        summary: "Pressure has been rising slowly — fish are likely feeding near the surface. Everything lines up — get on the water."
    ))
    .padding(Layout.screenEdge)
    .background(Color.primaryBackground)
}
