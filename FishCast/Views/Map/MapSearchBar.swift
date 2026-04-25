import SwiftUI

/// Translucent search field that floats above the map.
struct MapSearchBar: View {
    @Binding var text: String

    var body: some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Color.textSecondary)

            TextField("Search saved spots…", text: $text)
                .foregroundStyle(Color.textPrimary)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .submitLabel(.search)

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color.textTertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, 10)
        .background(Color.secondaryBackground.opacity(0.95))
        .clipShape(RoundedRectangle(cornerRadius: Layout.radiusMd))
        .overlay(
            RoundedRectangle(cornerRadius: Layout.radiusMd)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 2)
    }
}

/// Dropdown list of spots matching the current query.
struct SearchResultsList: View {
    let spots: [FishingSpot]
    let onTap: (FishingSpot) -> Void

    var body: some View {
        Group {
            if spots.isEmpty {
                Text("No matching spots")
                    .font(.appCallout)
                    .foregroundStyle(Color.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(Spacing.sm)
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(spots) { spot in
                        Button {
                            onTap(spot)
                        } label: {
                            row(for: spot)
                        }
                        .buttonStyle(.plain)

                        if spot.id != spots.last?.id {
                            Divider().overlay(Color.white.opacity(0.06))
                        }
                    }
                }
            }
        }
        .background(Color.secondaryBackground.opacity(0.95))
        .clipShape(RoundedRectangle(cornerRadius: Layout.radiusMd))
        .overlay(
            RoundedRectangle(cornerRadius: Layout.radiusMd)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 2)
    }

    private func row(for spot: FishingSpot) -> some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "fish")
                .foregroundStyle(Color.accentGold)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(spot.name)
                    .font(.appHeadline)
                    .foregroundStyle(Color.textPrimary)

                if !spot.notes.isEmpty {
                    Text(spot.notes)
                        .font(.appCaption)
                        .foregroundStyle(Color.textSecondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(Color.textTertiary)
        }
        .padding(Spacing.sm)
    }
}
