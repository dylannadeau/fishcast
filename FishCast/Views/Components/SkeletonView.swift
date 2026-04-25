import SwiftUI

/// Shimmer-style placeholder used while data is fetching. The animation
/// loops forever — caller is responsible for unmounting once content lands.
struct SkeletonBlock: View {
    var height: CGFloat = 16
    var cornerRadius: CGFloat = Layout.radiusSm

    @State private var isAnimating = false

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(LinearGradient(
                colors: [
                    Color.tertiaryBackground.opacity(0.6),
                    Color.tertiaryBackground.opacity(0.9),
                    Color.tertiaryBackground.opacity(0.6),
                ],
                startPoint: isAnimating ? .leading : .trailing,
                endPoint: isAnimating ? .trailing : .leading
            ))
            .frame(height: height)
            .onAppear {
                withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) {
                    isAnimating = true
                }
            }
    }
}

/// Pre-composed Dashboard loading layout — score ring + chips + chart strip.
struct DashboardSkeleton: View {
    var body: some View {
        VStack(spacing: Spacing.lg) {
            FishCastCard {
                HStack(spacing: Spacing.md) {
                    Circle()
                        .fill(Color.tertiaryBackground)
                        .frame(width: 120, height: 120)
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        SkeletonBlock(height: 18)
                        SkeletonBlock(height: 14)
                        SkeletonBlock(height: 14)
                    }
                }
            }
            FishCastCard {
                VStack(spacing: Spacing.xs) {
                    SkeletonBlock(height: 12)
                    SkeletonBlock(height: 12)
                    SkeletonBlock(height: 12)
                }
            }
            FishCastCard {
                SkeletonBlock(height: 120, cornerRadius: Layout.radiusMd)
            }
        }
        .padding(.horizontal, Layout.screenEdge)
    }
}
