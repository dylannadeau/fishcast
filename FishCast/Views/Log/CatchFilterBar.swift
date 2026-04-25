import SwiftUI

/// Horizontal scrolling chips for species + spot filters and a sort menu.
struct CatchFilterBar: View {
    @Bindable var viewModel: CatchLogViewModel
    let species: [String]
    let spots: [FishingSpot]

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(spacing: Spacing.xs) {
                Text("Sort")
                    .font(.appCaption)
                    .foregroundStyle(Color.textSecondary)
                Menu {
                    ForEach(CatchLogViewModel.SortOrder.allCases) { order in
                        Button(order.label) { viewModel.sortOrder = order }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(viewModel.sortOrder.label)
                        Image(systemName: "chevron.down")
                    }
                    .font(.appCallout)
                    .foregroundStyle(Color.accentGold)
                }
                Spacer()
                if viewModel.speciesFilter != nil || viewModel.spotFilter != nil {
                    Button("Clear") { viewModel.resetFilters() }
                        .font(.appCaption)
                        .foregroundStyle(Color.accentTeal)
                }
            }
            .padding(.horizontal, Layout.screenEdge)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.xs) {
                    ForEach(species, id: \.self) { name in
                        chip(
                            label: name,
                            isOn: viewModel.speciesFilter == name,
                            icon: AppIcons.fish
                        ) {
                            viewModel.speciesFilter = (viewModel.speciesFilter == name) ? nil : name
                        }
                    }
                    ForEach(spots) { spot in
                        chip(
                            label: spot.name,
                            isOn: viewModel.spotFilter == spot.id,
                            icon: AppIcons.location
                        ) {
                            viewModel.spotFilter = (viewModel.spotFilter == spot.id) ? nil : spot.id
                        }
                    }
                }
                .padding(.horizontal, Layout.screenEdge)
            }
        }
    }

    private func chip(label: String, isOn: Bool, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                Text(label)
                    .font(.appCaption)
                    .lineLimit(1)
            }
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, 6)
            .background(isOn ? Color.accentGold.opacity(0.2) : Color.tertiaryBackground)
            .foregroundStyle(isOn ? Color.accentGold : Color.textSecondary)
            .clipShape(Capsule())
        }
    }
}
