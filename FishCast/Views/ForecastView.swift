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
            ProgressView()
                .tint(Color.accentGold)
                .scaleEffect(1.2)
            Text("Loading forecast…")
                .font(.appBody)
                .foregroundStyle(Color.textSecondary)
        }
        .frame(maxWidth: .infinity, minHeight: 320)
    }

    private func errorState(message: String) -> some View {
        FishCastCard {
            VStack(spacing: Spacing.md) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: IconSize.hero))
                    .foregroundStyle(Color.scorePoor)

                Text("Couldn't load forecast")
                    .font(.appHeadline)
                    .foregroundStyle(Color.textPrimary)

                Text(message)
                    .font(.appBody)
                    .foregroundStyle(Color.textSecondary)
                    .multilineTextAlignment(.center)

                PrimaryButton(title: "Try again") {
                    Task { await viewModel.load() }
                }
                .padding(.top, Spacing.xs)
            }
            .frame(maxWidth: .infinity)
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
