import SwiftUI

/// Base card container. Wrap any content that should appear on a navy card surface.
struct FishCastCard<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(Layout.cardPadding)
            .background(Color.secondaryBackground)
            .clipShape(RoundedRectangle(cornerRadius: Layout.radiusMd))
            .overlay(
                RoundedRectangle(cornerRadius: Layout.radiusMd)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
    }
}

#Preview {
    FishCastCard {
        Text("Card content")
            .foregroundStyle(Color.textPrimary)
    }
    .padding()
    .background(Color.primaryBackground)
}
