import SwiftUI

/// Compact weather-condition tile for horizontal scrolling rows.
struct ConditionChip: View {
    let icon: String
    let value: String
    let unit: String

    var body: some View {
        VStack(spacing: Spacing.xxs) {
            Image(systemName: icon)
                .font(.system(size: IconSize.card))
                .foregroundStyle(Color.accentGold)

            Text(value)
                .font(.appHeadline)
                .foregroundStyle(Color.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Text(unit)
                .font(.appCaption)
                .foregroundStyle(Color.textSecondary)
        }
        .frame(width: 90)
        .padding(.vertical, Spacing.sm)
        .background(Color.tertiaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: Layout.radiusSm))
        .dynamicTypeSize(.medium ... .xxxLarge)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(unit): \(value)")
    }
}

#Preview {
    ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: Spacing.sm) {
            ConditionChip(icon: AppIcons.wind,        value: "12",   unit: "mph")
            ConditionChip(icon: AppIcons.barometer,   value: "1012", unit: "hPa")
            ConditionChip(icon: AppIcons.temperature, value: "68°",  unit: "Feels")
            ConditionChip(icon: AppIcons.tide,        value: "↑2.1", unit: "ft")
            ConditionChip(icon: AppIcons.moon,        value: "72%",  unit: "Lunar")
        }
        .padding(.horizontal, Layout.screenEdge)
    }
    .padding(.vertical, Spacing.md)
    .background(Color.primaryBackground)
}
