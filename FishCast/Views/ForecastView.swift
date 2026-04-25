import SwiftUI

struct ForecastView: View {
    @State private var viewModel = ForecastViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient.gradientPrimary.ignoresSafeArea()

                ScrollView {
                    content
                        .padding(.vertical, Spacing.lg)
                }
                .refreshable {
                    await viewModel.load()
                }
            }
            .navigationTitle("Forecast")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(Color.primaryBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .task {
                if viewModel.loadState == .idle {
                    await viewModel.load()
                }
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.loadState {
        case .idle, .loading:
            if viewModel.dailyEntries.isEmpty {
                loadingState
            } else {
                loadedContent
            }
        case .failed(let message):
            errorState(message: message)
                .padding(.horizontal, Layout.screenEdge)
        case .loaded:
            loadedContent
        }
    }

    // MARK: - States

    private var loadingState: some View {
        VStack(spacing: Spacing.md) {
            ForEach(0 ..< 5, id: \.self) { _ in
                FishCastCard {
                    SkeletonBlock(height: 56, cornerRadius: Layout.radiusSm)
                }
            }
        }
        .padding(.horizontal, Layout.screenEdge)
    }

    private func errorState(message: String) -> some View {
        ErrorBanner(
            title: "Couldn't load forecast",
            message: message,
            systemImage: "wifi.slash"
        ) {
            Task { await viewModel.load() }
        }
    }

    @ViewBuilder
    private var loadedContent: some View {
        VStack(spacing: Spacing.lg) {
            if !viewModel.dailyEntries.isEmpty {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    SectionHeader(title: "7-Day Outlook")
                        .padding(.horizontal, Layout.screenEdge)

                    VStack(spacing: Spacing.sm) {
                        ForEach(viewModel.dailyEntries) { entry in
                            DailyForecastCard(entry: entry)
                        }
                    }
                    .padding(.horizontal, Layout.screenEdge)
                }
            }

            if let moon = viewModel.moon {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    SectionHeader(title: "Moon")
                        .padding(.horizontal, Layout.screenEdge)
                    MoonSection(info: moon)
                        .padding(.horizontal, Layout.screenEdge)
                }
            }

            if let tide = viewModel.tide {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    SectionHeader(title: "Tides")
                        .padding(.horizontal, Layout.screenEdge)
                    TideSection(forecast: tide)
                        .padding(.horizontal, Layout.screenEdge)
                }
            }
        }
    }
}

#Preview {
    ForecastView()
}
