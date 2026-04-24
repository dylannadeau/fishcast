import SwiftUI

/// Consistent section label with optional "See All" action.
struct SectionHeader: View {
    let title: String
    var showSeeAll: Bool = false
    var onSeeAll: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title.uppercased())
                .font(.appCaption)
                .foregroundStyle(Color.textSecondary)
                .tracking(1.5)

            Spacer()

            if showSeeAll {
                Button("See All") { onSeeAll?() }
                    .font(.appCallout)
                    .foregroundStyle(Color.accentGold)
            }
        }
    }
}

#Preview {
    VStack(spacing: Spacing.lg) {
        SectionHeader(title: "Current Conditions")
        SectionHeader(title: "Bite Windows", showSeeAll: true)
    }
    .padding(Layout.screenEdge)
    .background(Color.primaryBackground)
}
