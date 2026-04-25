import SwiftUI

/// Gold circular marker with a fish glyph — used for saved spots.
struct SpotMarker: View {
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack {
                Circle()
                    .fill(Color.accentGold)
                    .frame(width: 38, height: 38)
                    .overlay(Circle().stroke(Color.primaryBackground, lineWidth: 2))
                    .shadow(color: .black.opacity(0.4), radius: 4, x: 0, y: 2)

                Image(systemName: "fish")
                    .foregroundStyle(Color.primaryBackground)
                    .font(.system(size: 18, weight: .semibold))
            }
        }
        .buttonStyle(.plain)
    }
}

/// Teal marker shown while the user is drafting a new spot from a long-press.
struct DraftMarker: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.accentTeal)
                .frame(width: 38, height: 38)
                .overlay(Circle().stroke(Color.textPrimary, lineWidth: 2))
                .shadow(color: .black.opacity(0.4), radius: 4, x: 0, y: 2)

            Image(systemName: "plus")
                .foregroundStyle(Color.textPrimary)
                .font(.system(size: 18, weight: .bold))
        }
    }
}
