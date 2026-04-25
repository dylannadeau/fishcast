import SwiftUI

/// Hero stats strip at the top of the Log tab: total this month, top species,
/// and personal best (heaviest weight ever logged).
struct CatchStatsCard: View {
    let monthCount: Int
    let topSpecies: String?
    let personalBest: CatchEntry?

    var body: some View {
        FishCastCard {
            HStack(alignment: .top, spacing: 0) {
                stat(
                    value: "\(monthCount)",
                    label: "This Month",
                    icon: "calendar"
                )
                divider
                stat(
                    value: topSpecies ?? "—",
                    label: "Top Species",
                    icon: AppIcons.fish
                )
                divider
                stat(
                    value: personalBest.map { String(format: "%.1f lb", $0.weight ?? 0) } ?? "—",
                    label: "Personal Best",
                    icon: "trophy.fill"
                )
            }
        }
    }

    private func stat(value: String, label: String, icon: String) -> some View {
        VStack(spacing: Spacing.xxs) {
            Image(systemName: icon)
                .font(.system(size: IconSize.card))
                .foregroundStyle(Color.accentGold)

            Text(value)
                .font(.appHeadline)
                .foregroundStyle(Color.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(label.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .tracking(1.0)
                .foregroundStyle(Color.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.06))
            .frame(width: 1, height: 48)
    }
}
