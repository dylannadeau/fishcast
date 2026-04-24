import SwiftUI

/// Gold-filled primary CTA.
struct PrimaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.appHeadline)
                .foregroundStyle(Color.primaryBackground)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(Color.accentGold)
                .clipShape(RoundedRectangle(cornerRadius: Layout.radiusMd))
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

/// Outlined secondary action; same sizing as PrimaryButton.
struct GhostButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.appHeadline)
                .foregroundStyle(Color.accentGold)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .overlay(
                    RoundedRectangle(cornerRadius: Layout.radiusMd)
                        .stroke(Color.accentGold, lineWidth: 1)
                )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// scaleEffect(0.97) spring-back on press, shared by both button styles.
private struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.appEaseOut, value: configuration.isPressed)
    }
}

#Preview {
    VStack(spacing: Spacing.md) {
        PrimaryButton(title: "Find Fishing Spots") {}
        GhostButton(title: "View Forecast") {}
    }
    .padding(Layout.screenEdge)
    .background(Color.primaryBackground)
}
