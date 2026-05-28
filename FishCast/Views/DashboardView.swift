import SwiftUI

/// Comprehensive one-stop hub for the current location. Sections, top to
/// bottom: header (location + refresh), hero score card (drill-in), next-
/// best-window banner (only when current < 60), conditions chip row, best-
/// bets carousel, today's windows chart, conditions snapshot grid, and
/// a 3-day outlook strip.
struct DashboardView: View {
    @State private var viewModel = DashboardViewModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient.gradientPrimary.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: Spacing.lg) {
                        DashboardHeaderView(
                            locationName: viewModel.locationName,
                            coordinate: viewModel.coordinate,
                            date: Date(),
                            isRefreshing: viewModel.loadState == .loading,
                            onRefresh: { Task { await viewModel.refreshConditions() } }
                        )
                        .padding(.horizontal, Layout.screenEdge)

                        if let error = viewModel.lastError, viewModel.fishingScore != nil {
                            cachedErrorBanner(message: error)
                                .padding(.horizontal, Layout.screenEdge)
                        }

                        content
                    }
                    .padding(.vertical, Spacing.lg)
                }
                .refreshable {
                    await viewModel.refreshConditions()
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .task {
                if viewModel.loadState == .idle {
                    await viewModel.load()
                }
            }
            .onChange(of: scenePhase) { _, newPhase in
                guard newPhase == .active else { return }
                Task { await viewModel.refreshConditions() }
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
        DashboardSkeleton()
    }

    private func errorState(message: String) -> some View {
        ErrorBanner(
            title: "Couldn't load conditions",
            message: message,
            systemImage: errorIcon(for: message)
        ) {
            Task { await viewModel.load() }
        }
    }

    private func cachedErrorBanner(message: String) -> some View {
        HStack(alignment: .top, spacing: Spacing.xs) {
            Image(systemName: "wifi.exclamationmark")
                .foregroundStyle(Color.scoreFair)
            VStack(alignment: .leading, spacing: 2) {
                Text("Showing cached conditions")
                    .font(.appCallout)
                    .foregroundStyle(Color.textPrimary)
                Text(lastUpdatedLabel)
                    .font(.appCaption)
                    .foregroundStyle(Color.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .padding(Spacing.sm)
        .background(Color.scoreFair.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: Layout.radiusSm))
        .overlay(
            RoundedRectangle(cornerRadius: Layout.radiusSm)
                .stroke(Color.scoreFair.opacity(0.4), lineWidth: 1)
        )
        .accessibilityLabel("Refresh failed: \(message). \(lastUpdatedLabel)")
    }

    private var lastUpdatedLabel: String {
        guard let last = viewModel.lastUpdatedAt else { return "Never updated" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return "Last updated \(formatter.localizedString(for: last, relativeTo: Date()))"
    }

    private func errorIcon(for message: String) -> String {
        let lower = message.lowercased()
        if lower.contains("location") || lower.contains("permission") {
            return "location.slash"
        }
        if lower.contains("internet") || lower.contains("network") || lower.contains("offline") {
            return "wifi.slash"
        }
        return "exclamationmark.triangle.fill"
    }

    // MARK: - Loaded sections

    @ViewBuilder
    private var loadedContent: some View {
        if let score = viewModel.fishingScore {
            heroSection(score: score)
        }

        if let score = viewModel.fishingScore,
           let window = score.nextBestWindow,
           score.score < 60 {
            NextBestWindowBanner(window: window) {
                // Future: open the 48h timeline directly. For now the score
                // card link gives the user access to the same data.
            }
            .padding(.horizontal, Layout.screenEdge)
        }

        if let current = viewModel.weather?.current {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                SectionHeader(title: "Current Conditions")
                    .padding(.horizontal, Layout.screenEdge)
                ConditionsRow(current: current, trend: viewModel.pressureTrend)
            }
        }

        if !viewModel.speciesPredictions.isEmpty {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                SectionHeader(title: "Best Bets Today")
                    .padding(.horizontal, Layout.screenEdge)
                BestBetsView(predictions: viewModel.speciesPredictions)
            }
        }

        if !viewModel.todaysHourlyScores.isEmpty {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                SectionHeader(title: "Today's Windows")
                    .padding(.horizontal, Layout.screenEdge)
                TodaysWindowsChart(scores: viewModel.todaysHourlyScores)
                    .padding(.horizontal, Layout.screenEdge)
            }
        }

        VStack(alignment: .leading, spacing: Spacing.sm) {
            SectionHeader(title: "Conditions Snapshot")
                .padding(.horizontal, Layout.screenEdge)
            ConditionsSnapshotGrid(
                moon: viewModel.moon,
                sunrise: viewModel.sunrise,
                sunset: viewModel.sunset,
                pressureReadings: viewModel.pressureReadings,
                trend: viewModel.pressureTrend
            )
            .padding(.horizontal, Layout.screenEdge)
        }

        if let outlook = threeDayOutlook, !outlook.isEmpty {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                SectionHeader(title: "3-Day Outlook")
                    .padding(.horizontal, Layout.screenEdge)
                ThreeDayOutlookView(days: outlook)
                    .padding(.horizontal, Layout.screenEdge)
            }
        }
    }

    @ViewBuilder
    private func heroSection(score: FishingScore) -> some View {
        if let snapshot = detailSnapshot {
            NavigationLink(value: DetailRoute.conditions(snapshot)) {
                FishingScoreCard(score: score, interactive: true)
                    .padding(.horizontal, Layout.screenEdge)
            }
            .buttonStyle(.plain)
            .navigationDestination(for: DetailRoute.self) { route in
                switch route {
                case .conditions(let snap):
                    ConditionsDetailView(snapshot: snap)
                }
            }
        } else {
            FishingScoreCard(score: score, interactive: false)
                .padding(.horizontal, Layout.screenEdge)
        }
    }

    // MARK: - Derived data

    private enum DetailRoute: Hashable {
        case conditions(ConditionsDetailView.ConditionsSnapshot)

        // Hashable shim — snapshots are reference-equal-on-content via the
        // score timestamp; we don't need a real equality check beyond
        // distinguishing routes.
        func hash(into hasher: inout Hasher) {
            switch self {
            case .conditions(let snap):
                hasher.combine("conditions")
                hasher.combine(snap.weather.date)
            }
        }

        static func == (lhs: DetailRoute, rhs: DetailRoute) -> Bool {
            switch (lhs, rhs) {
            case (.conditions(let a), .conditions(let b)):
                return a.weather.date == b.weather.date
            }
        }
    }

    private var detailSnapshot: ConditionsDetailView.ConditionsSnapshot? {
        guard let score = viewModel.fishingScore,
              let current = viewModel.weather?.current
        else { return nil }
        return ConditionsDetailView.ConditionsSnapshot(
            score: score,
            weather: current,
            trend: viewModel.pressureTrend,
            pressureReadings: viewModel.pressureReadings,
            hourlyScores: viewModel.hourlyScores,
            moon: viewModel.moon,
            sunrise: viewModel.sunrise,
            sunset: viewModel.sunset
        )
    }

    private var threeDayOutlook: [ThreeDayOutlookView.Day]? {
        guard let daily = viewModel.weather?.daily else { return nil }
        let calendar = Calendar.current

        return daily.prefix(3).map { day -> ThreeDayOutlookView.Day in
            let scoresForDay = viewModel.hourlyScores(on: day.date, calendar: calendar)
            let bestHour = scoresForDay.max(by: { $0.score.score < $1.score.score })
            let dayScore = bestHour?.score.score
                ?? viewModel.bestHour(on: day.date)?.score.score
                ?? 50
            let rating = FishingScore.Rating(score: dayScore)
            return ThreeDayOutlookView.Day(
                date: day.date,
                score: dayScore,
                rating: rating,
                highF: day.highTemperature.converted(to: .fahrenheit).value,
                lowF: day.lowTemperature.converted(to: .fahrenheit).value,
                symbolName: day.symbolName,
                conditionDescription: day.conditionDescription,
                bestWindowStart: bestHour?.hour.date,
                bestWindowEnd: bestHour?.hour.date.addingTimeInterval(3600)
            )
        }
    }
}

#Preview {
    DashboardView()
}
