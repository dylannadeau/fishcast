import SwiftUI

/// Bottom sheet shown when the user taps a saved spot's marker. Read mode
/// shows score, notes, and last catch; the pencil flips it into edit mode
/// where name/notes/species can be changed or the spot deleted entirely.
struct SpotDetailSheet: View {
    let spot: FishingSpot
    let viewModel: MapViewModel
    var onSaved: () -> Void = {}
    var onDeleted: () -> Void = {}

    @ObservedObject private var spotStore = SpotStore.shared
    @ObservedObject private var catchStore = CatchStore.shared
    @Environment(\.dismiss) private var dismiss
    @State private var score: FishingScore?
    @State private var isLoadingScore = true

    @State private var isEditing = false
    @State private var showDeleteConfirm = false

    @State private var draftName: String = ""
    @State private var draftNotes: String = ""
    @State private var draftSpecies: [String] = []
    @State private var newSpeciesField: String = ""

    /// The freshest version of the spot (the user can edit while the sheet
    /// is open). Falls back to the originally-passed value during deletion
    /// races, while the sheet is being dismissed.
    private var current: FishingSpot {
        spotStore.spots.first(where: { $0.id == spot.id }) ?? spot
    }

    private var lastCatch: CatchEntry? {
        catchStore.lastCatch(for: spot.id)
    }

    private var canSave: Bool {
        !draftName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.primaryBackground.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: Spacing.md) {
                        if isEditing {
                            editContent
                        } else {
                            readContent
                        }
                    }
                    .padding(Layout.screenEdge)
                }
            }
            .navigationTitle(isEditing ? "Edit Spot" : current.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
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
        .alert("Delete this spot?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) {
                spotStore.deleteSpot(current)
                Haptics.warning()
                onDeleted()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This cannot be undone.")
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        if isEditing {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel", action: cancelEdit)
                    .foregroundStyle(Color.textSecondary)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save", action: save)
                    .foregroundStyle(canSave ? Color.accentGold : Color.textTertiary)
                    .disabled(!canSave)
            }
        } else {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") { dismiss() }
                    .foregroundStyle(Color.accentGold)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: beginEdit) {
                    Image(systemName: "pencil")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color.accentGold)
                }
                .accessibilityLabel("Edit spot")
            }
        }
    }

    // MARK: - Read mode

    private var readContent: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            scoreCard
            notesCard
            catchCard
        }
    }

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

    private var notesCard: some View {
        FishCastCard {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                SectionHeader(title: "Notes")

                if current.notes.isEmpty {
                    Text("No notes yet.")
                        .font(.appBody)
                        .foregroundStyle(Color.textTertiary)
                } else {
                    Text(current.notes)
                        .font(.appBody)
                        .foregroundStyle(Color.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if !current.fishSpecies.isEmpty {
                    FlowTags(tags: current.fishSpecies)
                        .padding(.top, Spacing.xs)
                }
            }
        }
    }

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

    // MARK: - Edit mode

    private var editContent: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            nameEditCard
            notesEditCard
            speciesEditCard
            deleteCard
        }
    }

    private var nameEditCard: some View {
        FishCastCard {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                fieldLabel("Name")
                TextField("Spot name", text: $draftName)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .padding(Spacing.sm)
                    .background(Color.tertiaryBackground)
                    .clipShape(RoundedRectangle(cornerRadius: Layout.radiusSm))
                    .foregroundStyle(Color.textPrimary)
            }
        }
    }

    private var notesEditCard: some View {
        FishCastCard {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                fieldLabel("Notes")
                TextField(
                    "Structure, access, what was biting…",
                    text: $draftNotes,
                    axis: .vertical
                )
                .textInputAutocapitalization(.sentences)
                .lineLimit(3 ... 8)
                .padding(Spacing.sm)
                .background(Color.tertiaryBackground)
                .clipShape(RoundedRectangle(cornerRadius: Layout.radiusSm))
                .foregroundStyle(Color.textPrimary)
            }
        }
    }

    private var speciesEditCard: some View {
        FishCastCard {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                fieldLabel("Fish Species")

                if !draftSpecies.isEmpty {
                    FlexibleTags(tags: draftSpecies) { tag in
                        draftSpecies.removeAll { $0 == tag }
                    }
                }

                HStack(spacing: Spacing.xs) {
                    TextField("Add species (e.g. Bass)", text: $newSpeciesField)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                        .padding(Spacing.sm)
                        .background(Color.tertiaryBackground)
                        .clipShape(RoundedRectangle(cornerRadius: Layout.radiusSm))
                        .foregroundStyle(Color.textPrimary)
                        .onSubmit(addSpecies)

                    Button(action: addSpecies) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(canAddSpecies ? Color.accentGold : Color.textTertiary)
                    }
                    .disabled(!canAddSpecies)
                }
            }
        }
    }

    private var deleteCard: some View {
        Button(role: .destructive) {
            showDeleteConfirm = true
        } label: {
            HStack(spacing: Spacing.xs) {
                Image(systemName: "trash")
                Text("Delete Spot")
                    .font(.appHeadline)
            }
            .foregroundStyle(Color.scorePoor)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.sm)
            .background(Color.scorePoor.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: Layout.radiusMd))
            .overlay(
                RoundedRectangle(cornerRadius: Layout.radiusMd)
                    .stroke(Color.scorePoor.opacity(0.5), lineWidth: 1)
            )
        }
        .padding(.top, Spacing.sm)
    }

    // MARK: - Helpers

    private func fieldLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.appCaption)
            .foregroundStyle(Color.textSecondary)
            .tracking(1.5)
    }

    private var canAddSpecies: Bool {
        let trimmed = newSpeciesField.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty &&
            !draftSpecies.contains(where: { $0.caseInsensitiveCompare(trimmed) == .orderedSame })
    }

    private func addSpecies() {
        let trimmed = newSpeciesField.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              !draftSpecies.contains(where: { $0.caseInsensitiveCompare(trimmed) == .orderedSame })
        else { return }
        draftSpecies.append(trimmed)
        newSpeciesField = ""
    }

    // MARK: - Actions

    private func beginEdit() {
        draftName = current.name
        draftNotes = current.notes
        draftSpecies = current.fishSpecies
        newSpeciesField = ""
        withAnimation(.appEaseOut) { isEditing = true }
    }

    private func cancelEdit() {
        draftName = current.name
        draftNotes = current.notes
        draftSpecies = current.fishSpecies
        newSpeciesField = ""
        withAnimation(.appEaseOut) { isEditing = false }
    }

    private func save() {
        var updated = current
        updated.name = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.notes = draftNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.fishSpecies = draftSpecies
        spotStore.updateSpot(updated)
        Haptics.success()
        withAnimation(.appEaseOut) { isEditing = false }
        onSaved()
    }
}

// MARK: - Tag rows

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

/// Editable variant of `FlowTags` — each chip has an inline remove button.
private struct FlexibleTags: View {
    let tags: [String]
    let onRemove: (String) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.xs) {
                ForEach(tags, id: \.self) { tag in
                    HStack(spacing: 4) {
                        Text(tag)
                            .font(.appCaption)
                            .foregroundStyle(Color.accentGold)
                        Button {
                            onRemove(tag)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(Color.accentGold.opacity(0.7))
                        }
                    }
                    .padding(.horizontal, Spacing.xs)
                    .padding(.vertical, 4)
                    .background(Color.accentGold.opacity(0.15))
                    .clipShape(Capsule())
                }
            }
        }
    }
}
