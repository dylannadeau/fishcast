import SwiftUI

/// One row in the catch list — thumbnail (or species icon), species name,
/// date, spot name, and weight readout.
struct CatchEntryRow: View {
    let entry: CatchEntry
    let spotName: String?

    var body: some View {
        FishCastCard {
            HStack(spacing: Spacing.sm) {
                thumbnail

                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.species)
                        .font(.appHeadline)
                        .foregroundStyle(Color.textPrimary)
                        .lineLimit(1)

                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "calendar")
                        Text(entry.date.formatted(.dateTime.month(.abbreviated).day().year()))
                    }
                    .font(.appCaption)
                    .foregroundStyle(Color.textSecondary)

                    if let spotName {
                        HStack(spacing: Spacing.xs) {
                            Image(systemName: AppIcons.location)
                            Text(spotName).lineLimit(1)
                        }
                        .font(.appCaption)
                        .foregroundStyle(Color.textSecondary)
                    }
                }

                Spacer()

                if let weight = entry.weight {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(String(format: "%.1f", weight))
                            .font(.appTitle2)
                            .foregroundStyle(Color.accentGold)
                            .monospacedDigit()
                        Text("LB")
                            .font(.system(size: 10, weight: .semibold))
                            .tracking(1.0)
                            .foregroundStyle(Color.textSecondary)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let data = entry.photo, let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: Layout.radiusSm))
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: Layout.radiusSm)
                    .fill(Color.tertiaryBackground)
                Image(systemName: AppIcons.fish)
                    .font(.system(size: 22))
                    .foregroundStyle(Color.accentGold)
            }
            .frame(width: 56, height: 56)
        }
    }
}
