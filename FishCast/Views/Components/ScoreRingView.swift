import SwiftUI

/// Circular gauge showing the overall fishing score (0–100).
struct ScoreRingView: View {
    let score: Int
    var ringDiameter: CGFloat = 160
    var lineWidth: CGFloat = 8

    @State private var animatedProgress: CGFloat = 0

    private var progress: CGFloat { CGFloat(max(0, min(100, score))) / 100 }

    private var scoreColor: Color {
        switch score {
        case 80...100: return .scoreExcellent
        case 60..<80:  return .scoreGood
        case 40..<60:  return .scoreFair
        default:       return .scorePoor
        }
    }

    private var ratingLabel: String {
        switch score {
        case 80...100: return "Excellent"
        case 60..<80:  return "Good"
        case 40..<60:  return "Fair"
        default:       return "Poor"
        }
    }

    var body: some View {
        ZStack {
            // Track
            Circle()
                .stroke(Color.tertiaryBackground, lineWidth: lineWidth)

            // Progress arc
            Circle()
                .trim(from: 0, to: animatedProgress)
                .stroke(
                    LinearGradient(
                        colors: [scoreColor, .accentGoldLight],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            // Labels
            VStack(spacing: Spacing.xxs) {
                Text("\(score)")
                    .font(.appScore)
                    .foregroundStyle(Color.textPrimary)

                Text(ratingLabel.uppercased())
                    .font(.appCallout)
                    .foregroundStyle(Color.textSecondary)
                    .tracking(1.5)
            }
        }
        .frame(width: ringDiameter, height: ringDiameter)
        .onAppear {
            withAnimation(Animation.spring(response: 1.0, dampingFraction: 0.65).delay(0.2)) {
                animatedProgress = progress
            }
            // Tap-tap feedback when the gauge crystallises.
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 600_000_000)
                Haptics.impact(.light)
            }
        }
        .onChange(of: score) { _, _ in
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
                animatedProgress = progress
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Fishing score \(score) out of 100, rated \(ratingLabel)")
    }
}

#Preview {
    HStack(spacing: Spacing.lg) {
        ScoreRingView(score: 88)
        ScoreRingView(score: 63)
        ScoreRingView(score: 41)
        ScoreRingView(score: 18)
    }
    .padding()
    .background(Color.primaryBackground)
}
