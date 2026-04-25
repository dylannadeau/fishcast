import SwiftUI

/// Phase glyph + illumination + moonrise/set + angler-facing impact note.
struct MoonSection: View {
    let info: MoonInfo

    private var illuminationLabel: String {
        "\(Int((info.illumination * 100).rounded()))% illumination"
    }

    var body: some View {
        FishCastCard {
            VStack(alignment: .leading, spacing: Spacing.md) {
                HStack(spacing: Spacing.md) {
                    Image(systemName: info.phase.symbolName)
                        .font(.system(size: 56))
                        .foregroundStyle(Color.accentGoldLight)
                        .symbolRenderingMode(.hierarchical)

                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        Text(info.phase.label)
                            .font(.appTitle2)
                            .foregroundStyle(Color.textPrimary)
                        Text(illuminationLabel)
                            .font(.appCallout)
                            .foregroundStyle(Color.textSecondary)
                    }

                    Spacer()
                }

                Divider().overlay(Color.white.opacity(0.06))

                HStack(spacing: Spacing.lg) {
                    riseSetRow(
                        label: "Moonrise",
                        date: info.moonrise,
                        icon: "moon.stars"
                    )
                    riseSetRow(
                        label: "Moonset",
                        date: info.moonset,
                        icon: "moon"
                    )
                }

                Text(info.phase.fishingImpact)
                    .font(.appBody)
                    .foregroundStyle(Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func riseSetRow(label: String, date: Date?, icon: String) -> some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: icon)
                .foregroundStyle(Color.accentGold)

            VStack(alignment: .leading, spacing: 2) {
                Text(label.uppercased())
                    .font(.appCaption)
                    .foregroundStyle(Color.textSecondary)
                    .tracking(1.5)

                Text(date?.formatted(.dateTime.hour().minute()) ?? "—")
                    .font(.appCallout)
                    .foregroundStyle(Color.textPrimary)
                    .monospacedDigit()
            }
        }
    }
}
