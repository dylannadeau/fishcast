import SwiftUI

/// Slim banner used by Dashboard/Forecast when load fails — offers a
/// retry CTA and a recoverable hint message.
struct ErrorBanner: View {
    let title: String
    let message: String
    var systemImage: String = "exclamationmark.triangle.fill"
    var retryTitle: String = "Retry"
    let onRetry: () -> Void

    var body: some View {
        FishCastCard {
            HStack(spacing: Spacing.sm) {
                Image(systemName: systemImage)
                    .font(.system(size: IconSize.card))
                    .foregroundStyle(Color.scoreFair)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.appHeadline)
                        .foregroundStyle(Color.textPrimary)
                    Text(message)
                        .font(.appCaption)
                        .foregroundStyle(Color.textSecondary)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                Button(retryTitle) {
                    Haptics.selection()
                    onRetry()
                }
                .font(.appCallout)
                .foregroundStyle(Color.accentGold)
            }
        }
    }
}

/// Composed empty state — a stacked SF Symbol illustration + headline + body
/// + optional CTA. Used by Map and Log when no spots/catches exist yet.
struct EmptyStateView: View {
    let symbol: String
    var accentSymbol: String?       // smaller secondary symbol for layered look
    let title: String
    let message: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: Spacing.md) {
            ZStack {
                Circle()
                    .fill(Color.accentGold.opacity(0.12))
                    .frame(width: 140, height: 140)

                Image(systemName: symbol)
                    .font(.system(size: 60, weight: .regular))
                    .foregroundStyle(Color.accentGold)
                    .symbolRenderingMode(.hierarchical)

                if let accentSymbol {
                    Image(systemName: accentSymbol)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(Color.accentTeal)
                        .offset(x: 42, y: 42)
                }
            }

            VStack(spacing: Spacing.xs) {
                Text(title)
                    .font(.appTitle2)
                    .foregroundStyle(Color.textPrimary)
                Text(message)
                    .font(.appBody)
                    .foregroundStyle(Color.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, Layout.screenEdge)

            if let actionTitle, let action {
                PrimaryButton(title: actionTitle, action: action)
                    .padding(.horizontal, Spacing.xl)
                    .padding(.top, Spacing.xs)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
