import SwiftUI

struct DashboardView: View {
    @State private var viewModel = DashboardViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient.gradientPrimary.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: Spacing.lg) {
                        DashboardHeaderView(
                            locationName: viewModel.locationName,
                            date: Date()
                        )
                        .padding(.horizontal, Layout.screenEdge)

                        content
                    }
                    .padding(.vertical, Spacing.lg)
                }
                .refreshable {
                    await viewModel.load()
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .task {
                if viewModel.loadState == .idle {
                    await viewModel.load()
                }
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.fishingScore != nil {
            loadedContent
        } else if case .failed(let message) = viewModel.loadState {
            errorState(message: message)
                .padding(.horizontal, Layout.screenEdge)
        } else {
            loadingState
        }
    }

    // MARK: - States

    private var loadingState: some View {
        VStack(spacing: Spacing.md) {
            ProgressView()
                .tint(Color.accentGold)
                .scaleEffect(1.2)
            Text("Gathering conditions…")
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

                Text("Couldn't load conditions")
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
        if let score = viewModel.fishingScore {
            FishingScoreCard(score: score)
                .padding(.horizontal, Layout.screenEdge)
        }

        if let current = viewModel.weather?.current {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                SectionHeader(title: "Current Conditions")
                    .padding(.horizontal, Layout.screenEdge)
                ConditionsRow(current: current, trend: viewModel.pressureTrend)
            }
        }

        VStack(alignment: .leading, spacing: Spacing.sm) {
            SectionHeader(title: "Pressure Trend")
                .padding(.horizontal, Layout.screenEdge)
            PressureTrendChart(
                readings: viewModel.pressureReadings,
                trend: viewModel.pressureTrend
            )
            .padding(.horizontal, Layout.screenEdge)
        }

        if !viewModel.hourlyScores.isEmpty {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                SectionHeader(title: "Best Times Today")
                    .padding(.horizontal, Layout.screenEdge)
                BestTimesTimelineView(scores: viewModel.hourlyScores)
                    .padding(.horizontal, Layout.screenEdge)
            }
        }

        if !viewModel.speciesPredictions.isEmpty {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                SectionHeader(title: "Best Bets Today")
                    .padding(.horizontal, Layout.screenEdge)
                BestBetsView(predictions: viewModel.speciesPredictions)
            }
        }
    }
}

#Preview {
    DashboardView()
}
