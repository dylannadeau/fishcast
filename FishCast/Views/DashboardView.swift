import SwiftUI

/// Home hub. Sections, top to bottom: header (location + refresh), the
/// user's saved spots — each with live conditions, recent-average context,
/// pressure/temperature outlook, and most/least-likely species — then the
/// current-location score card, conditions chips, best-bets carousel,
/// today's windows chart, snapshot grid, and 3-day outlook strip.
struct DashboardView: View {
    @State private var viewModel = DashboardViewModel()
    @State private var spotsViewModel = SpotConditionsViewModel()
    @ObservedObject private var spotStore = SpotStore.shared
    @AppStorage(SettingsKey.historyWindowDays) private var historyWindowDays: Int = HistoryWindow.default
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
                            onRefresh: { Task { await refreshEverything(force: true) } }
                        )
                        .padding(.horizontal, Layout.screenEdge)

                        if let error = viewModel.lastError, viewModel.fishingScore != nil {
                            cachedErrorBanner(message: error)
                                .padding(.horizontal, Layout.screenEdge)
                        }

                        spotsSection

                        content
                    }
                    .padding(.vertical, Spacing.lg)
                }
                .refreshable {
                    await refreshEverything(force: true)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .task {
                if viewModel.loadState == .idle {
                    await viewModel.load()
                }
            }
            .task(id: spotsTaskKey) {
                await spotsViewModel.loadAll(
                    spots: spotStore.spots, historyDays: historyWindowDays
                )
            }
            .onChange(of: scenePhase) { _, newPhase in
                guard newPhase == .active else { return }
                Task { await refreshEverything(force: false) }
            }
        }
    }

    /// Re-runs the spots task when the spot list or comparison window
    /// changes; the view model's freshness guard keeps plain re-appearances
    /// from re-billing WeatherKit.
    private var spotsTaskKey: String {
        "\(historyWindowDays)|"
            + spotStore.spots.map { $0.id.uuidString }.joined(separator: ",")
    }

    private func refreshEverything(force: Bool) async {
        async let currentLocation: Void = viewModel.refreshConditions()
        async let spots: Void = spotsViewModel.loadAll(
            spots: spotStore.spots, historyDays: historyWindowDays, force: force
        )
        _ = await (currentLocation, spots)
    }

    // MARK: - Your Spots

    @ViewBuilder
    private var spotsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            SectionHeader(title: "Your Spots")
                .padding(.horizontal, Layout.screenEdge)

            if spotStore.spots.isEmpty {
                emptySpotsCard
                    .padding(.horizontal, Layout.screenEdge)
            } else {
                ForEach(spotStore.spots) { spot in
                    SpotConditionsCard(
                        spot: spot,
                        state: spotsViewModel.state(for: spot.id),
                        onRetry: {
                            Task {
                                await spotsViewModel.load(
                                    spot: spot,
                                    historyDays: historyWindowDays,
                                    force: true
                                )
                            }
                        }
                    )
                    .padding(.horizontal, Layout.screenEdge)
                }
            }
        }
    }

    private var emptySpotsCard: some View {
        FishCastCard {
            VStack(spacing: Spacing.sm) {
                Image(systemName: AppIcons.map)
                    .font(.system(size: IconSize.hero))
                    .foregroundStyle(Color.accentGold)
                    .symbolRenderingMode(.hierarchical)

                Text("No spots saved yet")
                    .font(.appHeadline)
                    .foregroundStyle(Color.textPrimary)

                Text("Save a fishing spot on the Map and it'll show up here with live conditions, trends, and today's best bets.")
                    .font(.appBody)
                    .foregroundStyle(Color.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                PrimaryButton(title: "Add Your First Spot") {
                    AppRouter.shared.selectedTab = .map
                }
                .padding(.top, Spacing.xs)
            }
            .frame(maxWidth: .infinity)
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
            VStack(alignment: .leading, spacing: Spacing.sm) {
                SectionHeader(title: "Current Location")
                    .padding(.horizontal, Layout.screenEdge)
                heroSection(score: score)
            }
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

// MARK: - Spot card

/// One saved spot's full picture: live conditions, "vs recent average"
/// context, a next-days pressure/temperature strip, and today's most / least
/// likely species. Renders whatever the `CardState` holds — cached data with
/// a stale banner when the last fetch failed, a skeleton when nothing has
/// loaded yet, and an inline error with Retry when there's no data at all.
struct SpotConditionsCard: View {
    let spot: FishingSpot
    let state: SpotConditionsViewModel.CardState
    let onRetry: () -> Void

    var body: some View {
        FishCastCard {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                header

                if let conditions = state.conditions {
                    if state.errorMessage != nil {
                        staleBanner(fetchedAt: conditions.fetchedAt)
                    }
                    currentSection(conditions)
                    if let history = conditions.history {
                        divider
                        historySection(history)
                    }
                    if !conditions.outlook.isEmpty {
                        divider
                        outlookSection(conditions.outlook)
                    }
                    if !conditions.mostLikely.isEmpty {
                        divider
                        speciesSection(conditions)
                    }
                } else if let message = state.errorMessage {
                    errorContent(message: message)
                } else {
                    // Idle or in-flight with nothing cached yet.
                    loadingSkeleton
                }
            }
        }
        .animation(.appEaseOut, value: state.isLoading)
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .center, spacing: Spacing.xs) {
            Image(systemName: AppIcons.location)
                .font(.system(size: IconSize.card))
                .foregroundStyle(Color.accentTeal)

            VStack(alignment: .leading, spacing: 1) {
                Text(spot.name)
                    .font(.appTitle2)
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(1)
                if let conditions = state.conditions {
                    Text(updatedLabel(conditions.fetchedAt))
                        .font(.appCaption)
                        .foregroundStyle(Color.textTertiary)
                }
            }

            Spacer()

            if state.isLoading {
                ProgressView()
                    .tint(Color.accentGold)
            } else if let conditions = state.conditions {
                scoreBadge(conditions.score)
            }
        }
    }

    private func scoreBadge(_ score: Int) -> some View {
        let rating = FishingScore.Rating(score: score)
        return Text("\(score) · \(rating.label)")
            .font(.appCallout)
            .foregroundStyle(Color.primaryBackground)
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xxs)
            .background(scoreColor(score))
            .clipShape(Capsule())
            .accessibilityLabel("Fishing score \(score), \(rating.label)")
    }

    private func scoreColor(_ score: Int) -> Color {
        switch score {
        case 80...:   return .scoreExcellent
        case 60...79: return .scoreGood
        case 40...59: return .scoreFair
        default:      return .scorePoor
        }
    }

    // MARK: Current conditions

    private func currentSection(_ conditions: SpotConditions) -> some View {
        let current = conditions.current
        return VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(spacing: Spacing.xs) {
                Image(systemName: current.symbolName)
                    .font(.system(size: IconSize.card))
                    .foregroundStyle(Color.accentGold)
                    .symbolRenderingMode(.multicolor)
                Text(current.conditionDescription)
                    .font(.appCallout)
                    .foregroundStyle(Color.textSecondary)
            }

            HStack(spacing: 0) {
                statCell(
                    icon: AppIcons.temperature,
                    value: "\(Int(current.tempF.rounded()))°",
                    label: "Air"
                )
                statCell(
                    icon: AppIcons.barometer,
                    value: "\(Int(current.pressureHPa.rounded()))",
                    label: "mb",
                    trailingSymbol: conditions.pressureTrend.symbolName,
                    trailingColor: trendColor(conditions.pressureTrend)
                )
                statCell(
                    icon: AppIcons.wind,
                    value: "\(Int(current.windMph.rounded()))",
                    label: "mph \(current.windCompass)"
                )
                statCell(
                    icon: "cloud.rain.fill",
                    value: "\(Int((current.precipChance * 100).rounded()))%",
                    label: "Precip"
                )
            }
        }
    }

    private func statCell(
        icon: String,
        value: String,
        label: String,
        trailingSymbol: String? = nil,
        trailingColor: Color = .textSecondary
    ) -> some View {
        VStack(spacing: 2) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(Color.accentGold)
            HStack(spacing: 2) {
                Text(value)
                    .font(.appHeadline)
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                if let trailingSymbol {
                    Image(systemName: trailingSymbol)
                        .font(.caption2.bold())
                        .foregroundStyle(trailingColor)
                }
            }
            Text(label)
                .font(.appCaption)
                .foregroundStyle(Color.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label): \(value)")
    }

    /// Falling pressure is the angler-positive direction — mirror the
    /// `TrendLabelChip` semantics.
    private func trendColor(_ trend: PressureTrend) -> Color {
        switch trend {
        case .rapidFall: return .scoreExcellent
        case .slowFall:  return .scoreGood
        case .steady:    return .accentTeal
        case .slowRise:  return .scoreFair
        case .rapidRise: return .scorePoor
        }
    }

    // MARK: Historical context

    private func historySection(_ history: SpotConditions.History) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            sectionLabel("Vs Past \(history.windowDays) Days")

            comparisonRow(
                label: "Temperature",
                delta: history.tempDeltaF,
                deltaText: signed(history.tempDeltaF, unit: "°"),
                detail: "avg \(Int(history.avgTempF.rounded()))°"
            )
            comparisonRow(
                label: "Pressure",
                delta: history.pressureDeltaHPa,
                deltaText: signed(history.pressureDeltaHPa, unit: " mb"),
                detail: "avg \(Int(history.avgPressureHPa.rounded())) mb"
            )
        }
    }

    private func comparisonRow(
        label: String, delta: Double, deltaText: String, detail: String
    ) -> some View {
        HStack(spacing: Spacing.xs) {
            Text(label)
                .font(.appBody)
                .foregroundStyle(Color.textSecondary)
            Spacer()
            Text(detail)
                .font(.appCaption)
                .foregroundStyle(Color.textTertiary)
            HStack(spacing: 2) {
                Image(systemName: deltaSymbol(delta))
                    .font(.caption2.bold())
                Text(deltaText)
                    .font(.appCallout)
                    .monospacedDigit()
            }
            .foregroundStyle(deltaColor(delta))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label) \(deltaText) versus recent average, \(detail)")
    }

    private func deltaSymbol(_ delta: Double) -> String {
        if abs(delta) < 0.5 { return "equal" }
        return delta > 0 ? "arrow.up" : "arrow.down"
    }

    private func deltaColor(_ delta: Double) -> Color {
        abs(delta) < 0.5 ? .textSecondary : (delta > 0 ? .accentGold : .accentTeal)
    }

    private func signed(_ value: Double, unit: String) -> String {
        let rounded = (value * 10).rounded() / 10
        if abs(rounded) < 0.05 { return "±0\(unit)" }
        let formatted = rounded == rounded.rounded()
            ? String(Int(rounded))
            : String(format: "%.1f", rounded)
        return (rounded > 0 ? "+" : "") + formatted + unit
    }

    // MARK: Upcoming trend

    private func outlookSection(_ outlook: [SpotConditions.OutlookDay]) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            sectionLabel("Next Days")

            HStack(spacing: 0) {
                ForEach(outlook) { day in
                    outlookCell(day)
                }
            }
        }
    }

    private func outlookCell(_ day: SpotConditions.OutlookDay) -> some View {
        VStack(spacing: 2) {
            Text(weekdayLabel(day.date))
                .font(.appCaption)
                .foregroundStyle(Color.textSecondary)

            Image(systemName: day.symbolName)
                .font(.system(size: 14))
                .foregroundStyle(Color.accentGold)
                .symbolRenderingMode(.multicolor)
                .frame(height: 18)

            Text("\(Int(day.highF.rounded()))°/\(Int(day.lowF.rounded()))°")
                .font(.appCallout)
                .foregroundStyle(Color.textPrimary)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            if let trend = day.pressureTrend, let delta = day.pressureDeltaHPa {
                HStack(spacing: 2) {
                    Image(systemName: trend.symbolName)
                        .font(.caption2.bold())
                    Text(signed(delta, unit: ""))
                        .font(.appCaption)
                        .monospacedDigit()
                }
                .foregroundStyle(trendColor(trend))
                .accessibilityLabel("Pressure \(trend.description)")
            } else {
                Text("—")
                    .font(.appCaption)
                    .foregroundStyle(Color.textTertiary)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func weekdayLabel(_ date: Date) -> String {
        if Calendar.current.isDateInToday(date) { return "Today" }
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }

    // MARK: Species

    private func speciesSection(_ conditions: SpotConditions) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            sectionLabel("Today's Bite")

            speciesRow(
                title: "Most likely",
                titleColor: .scoreExcellent,
                predictions: conditions.mostLikely,
                chipStyle: .hot
            )
            if !conditions.leastLikely.isEmpty {
                speciesRow(
                    title: "Least likely",
                    titleColor: .textTertiary,
                    predictions: conditions.leastLikely,
                    chipStyle: .slow
                )
            }
        }
    }

    private func speciesRow(
        title: String,
        titleColor: Color,
        predictions: [SpeciesPrediction],
        chipStyle: SpeciesChip.Style
    ) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text(title)
                .font(.appCaption)
                .foregroundStyle(titleColor)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.xs) {
                    ForEach(predictions) { prediction in
                        SpeciesChip(prediction: prediction, style: chipStyle)
                    }
                }
            }
        }
    }

    // MARK: States

    private var loadingSkeleton: some View {
        VStack(spacing: Spacing.xs) {
            SkeletonBlock(height: 40)
            SkeletonBlock(height: 14)
            SkeletonBlock(height: 14)
        }
    }

    private func errorContent(message: String) -> some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Color.scoreFair)
            Text(message)
                .font(.appCaption)
                .foregroundStyle(Color.textSecondary)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
            Button("Retry") {
                Haptics.selection()
                onRetry()
            }
            .font(.appCallout)
            .foregroundStyle(Color.accentGold)
        }
    }

    private func staleBanner(fetchedAt: Date) -> some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: "wifi.exclamationmark")
                .foregroundStyle(Color.scoreFair)
            Text("Refresh failed — showing data from \(updatedLabel(fetchedAt).lowercased())")
                .font(.appCaption)
                .foregroundStyle(Color.textSecondary)
                .lineLimit(2)
            Spacer(minLength: 0)
            Button("Retry") {
                Haptics.selection()
                onRetry()
            }
            .font(.appCallout)
            .foregroundStyle(Color.accentGold)
        }
        .padding(Spacing.xs)
        .background(Color.scoreFair.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: Layout.radiusSm))
    }

    // MARK: Bits

    private var divider: some View {
        Divider().overlay(Color.white.opacity(0.06))
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.appCaption)
            .foregroundStyle(Color.textTertiary)
            .tracking(1.2)
    }

    private func updatedLabel(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return "Updated \(formatter.localizedString(for: date, relativeTo: Date()))"
    }
}

/// Compact species pill — name + likelihood %. `hot` styling for best bets,
/// `slow` for the long shots.
struct SpeciesChip: View {
    enum Style { case hot, slow }

    let prediction: SpeciesPrediction
    let style: Style

    private var accent: Color {
        style == .hot ? .accentGold : .textTertiary
    }

    var body: some View {
        HStack(spacing: Spacing.xxs) {
            Image(systemName: prediction.symbolName)
                .font(.caption)
                .foregroundStyle(accent)
            Text(prediction.species)
                .font(.appCaption)
                .foregroundStyle(style == .hot ? Color.textPrimary : Color.textSecondary)
                .lineLimit(1)
            Text("\(prediction.likelihood)%")
                .font(.appCaption.bold())
                .foregroundStyle(accent)
                .monospacedDigit()
        }
        .padding(.horizontal, Spacing.xs)
        .padding(.vertical, Spacing.xxs)
        .background(Color.tertiaryBackground)
        .clipShape(Capsule())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(prediction.species), \(prediction.likelihood) percent likelihood")
    }
}

#Preview {
    DashboardView()
}
