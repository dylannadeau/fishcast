import SwiftUI

/// Catch log home screen. Pulls catches from `CatchStore` and spots from
/// `SpotStore`; filtering and sorting live in `CatchLogViewModel`.
struct LogView: View {
    @ObservedObject private var catchStore = CatchStore.shared
    @ObservedObject private var spotStore = SpotStore.shared
    @State private var viewModel = CatchLogViewModel()
    @State private var isPresentingNewCatch = false

    var body: some View {
        @Bindable var viewModel = viewModel

        NavigationStack {
            ZStack {
                LinearGradient.gradientPrimary.ignoresSafeArea()

                if catchStore.catches.isEmpty {
                    emptyState
                } else {
                    loadedContent
                }
            }
            .navigationTitle("Log")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isPresentingNewCatch = true
                    } label: {
                        Image(systemName: AppIcons.plus)
                            .font(.system(size: 22))
                            .foregroundStyle(Color.accentGold)
                    }
                }
            }
            .toolbarBackground(Color.primaryBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .sheet(isPresented: $isPresentingNewCatch) {
                NewCatchSheet(
                    viewModel: viewModel,
                    spots: spotStore.spots
                ) { entry in
                    catchStore.addCatch(entry)
                    Haptics.success()
                }
            }
        }
    }

    // MARK: - Loaded

    private var loadedContent: some View {
        ScrollView {
            VStack(spacing: Spacing.md) {
                CatchStatsCard(
                    monthCount: catchStore.thisMonthCount,
                    topSpecies: catchStore.topSpecies,
                    personalBest: catchStore.personalBest
                )
                .padding(.horizontal, Layout.screenEdge)

                CatchFilterBar(
                    viewModel: viewModel,
                    species: viewModel.availableSpecies(from: catchStore.catches),
                    spots: spotStore.spots
                )

                LazyVStack(spacing: Spacing.sm) {
                    ForEach(displayedCatches) { entry in
                        CatchEntryRow(
                            entry: entry,
                            spotName: spotName(for: entry.spotId)
                        )
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                catchStore.deleteCatch(entry)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
                .padding(.horizontal, Layout.screenEdge)
            }
            .padding(.vertical, Spacing.md)
        }
    }

    // MARK: - Empty

    private var emptyState: some View {
        EmptyStateView(
            symbol: AppIcons.log,
            accentSymbol: AppIcons.fish,
            title: "No catches yet",
            message: "Tap + to log your first catch — we'll capture conditions automatically.",
            actionTitle: "Log a Catch"
        ) {
            isPresentingNewCatch = true
        }
    }

    // MARK: - Helpers

    private var displayedCatches: [CatchEntry] {
        viewModel.displayedCatches(from: catchStore.catches)
    }

    private func spotName(for spotId: UUID?) -> String? {
        guard let spotId else { return nil }
        return spotStore.spots.first(where: { $0.id == spotId })?.name
    }
}

#Preview {
    LogView()
}
