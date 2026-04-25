import SwiftUI

/// Horizontal "Best Bets Today" carousel — top species predictions from
/// `FishingConditionsEngine.speciesRecommendations`.
struct BestBetsView: View {
    let predictions: [SpeciesPrediction]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.sm) {
                ForEach(predictions) { prediction in
                    BestBetCard(prediction: prediction)
                        .frame(width: 240)
                }
            }
            .padding(.horizontal, Layout.screenEdge)
        }
    }
}

private struct BestBetCard: View {
    let prediction: SpeciesPrediction

    private var likelihoodColor: Color {
        switch prediction.likelihood {
        case 75...:    return .scoreExcellent
        case 55 ..< 75: return .scoreGood
        case 35 ..< 55: return .scoreFair
        default:       return .scorePoor
        }
    }

    var body: some View {
        FishCastCard {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: prediction.symbolName)
                        .font(.system(size: 26))
                        .foregroundStyle(Color.accentGold)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(prediction.species)
                            .font(.appHeadline)
                            .foregroundStyle(Color.textPrimary)
                            .lineLimit(1)
                        Text("\(prediction.likelihood)% likelihood")
                            .font(.appCaption)
                            .foregroundStyle(likelihoodColor)
                    }
                    Spacer()
                }

                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.tertiaryBackground)
                            .frame(height: 6)
                        Capsule()
                            .fill(likelihoodColor)
                            .frame(
                                width: geometry.size.width * CGFloat(prediction.likelihood) / 100,
                                height: 6
                            )
                    }
                }
                .frame(height: 6)

                Text(prediction.tip)
                    .font(.appCaption)
                    .foregroundStyle(Color.textSecondary)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
