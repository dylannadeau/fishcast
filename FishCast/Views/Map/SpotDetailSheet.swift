import SwiftUI

/// Bottom sheet shown when the user taps a saved spot's marker.
struct SpotDetailSheet: View {
    let spot: FishingSpot
    let viewModel: MapViewModel

    @ObservedObject private var catchStore = CatchStore.shared
    @Environment(\.dismiss) private var dismiss
    @State private var score: FishingScore?
    @State private var isLoadingScore = true

    private var lastCatch: CatchEntry? {
        catchStore.lastCatch(for: spot.id)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.primaryBackground.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: Spacing.md) {
                        scoreCard
                        notesCard
                        catchCard
                    }
                    .padding(Layout.screenEdge)
                }
            }
            .navigationTitle(spot.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Color.accentGold)
                }
            }
            .toolbarBackground(Color.primaryBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .task {
            score = await viewModel.fishingScore(for: spot.coordinate)
            isLoadingScore = false
        }
    }

    // MARK: - Score

    private var scoreCard: some View {
        FishCastCard {
            VStack(spacing: Spacing.sm) {
                if let score {
                    HStack(spacing: Spacing.md) {
                        ScoreRingView(score: score.score, ringDiameter: 90, lineWidth: 6)

                        VStack(alignment: .leading, spacing: Spacing.xxs) {
                            Text("Current Score")
                                .font(.appCaption)
                                .foregroundStyle(Color.textSecondary)
                                .tracking(1.5)
                            Text(score.rating.label)
                                .font(.appTitle2)
                                .foregroundStyle(Color.textPrimary)
                            Text(score.summary)
                                .font(.appCaption)
                                .foregroundStyle(Color.textSecondary)
                                .lineLimit(3)
                        }
                    }
                } else if isLoadingScore {
                    HStack(spacing: Spacing.sm) {
                        ProgressView().tint(Color.accentGold)
                        Text("Fetching conditions for this spot…")
                            .font(.appCallout)
                            .foregroundStyle(Color.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Label("Conditions unavailable", systemImage: "wifi.exclamationmark")
                        .font(.appCallout)
                        .foregroundStyle(Color.textSecondary)
                }
            }
        }
    }

    // MARK: - Notes

    private var notesCard: some View {
        FishCastCard {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                SectionHeader(title: "Notes")

                if spot.notes.isEmpty {
                    Text("No notes yet.")
                        .font(.appBody)
                        .foregroundStyle(Color.textTertiary)
                } else {
                    Text(spot.notes)
                        .font(.appBody)
                        .foregroundStyle(Color.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if !spot.fishSpecies.isEmpty {
                    FlowTags(tags: spot.fishSpecies)
                        .padding(.top, Spacing.xs)
                }
            }
        }
    }

    // MARK: - Last catch

    private var catchCard: some View {
        FishCastCard {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                SectionHeader(title: "Last Catch")

                if let latest = lastCatch {
                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        Text(latest.species)
                            .font(.appHeadline)
                            .foregroundStyle(Color.textPrimary)

                        HStack(spacing: Spacing.md) {
                            if let weight = latest.weight {
                                Label(String(format: "%.1f lb", weight), systemImage: "scalemass")
                            }
                            if let length = latest.length {
                                Label(String(format: "%.0f in", length), systemImage: "ruler")
                            }
                            Label(latest.date.formatted(.relative(presentation: .named)), systemImage: "calendar")
                        }
                        .font(.appCaption)
                        .foregroundStyle(Color.textSecondary)
                    }
                } else {
                    Text("No catches logged yet.")
                        .font(.appBody)
                        .foregroundStyle(Color.textTertiary)
                }
            }
        }
    }
}

private struct FlowTags: View {
    let tags: [String]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.xs) {
                ForEach(tags, id: \.self) { tag in
                    Text(tag)
                        .font(.appCaption)
                        .foregroundStyle(Color.accentGold)
                        .padding(.horizontal, Spacing.xs)
                        .padding(.vertical, 4)
                        .background(Color.accentGold.opacity(0.15))
                        .clipShape(Capsule())
                }
            }
        }
    }
}
