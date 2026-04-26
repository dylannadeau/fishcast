import PhotosUI
import SwiftUI

/// Read/edit screen for a single logged catch. Pushed from `LogView` via
/// `NavigationLink`. Read mode shows the captured fields plus the linked
/// spot (tapping it routes to the Map tab and focuses the pin); edit mode
/// reuses the same controls as `NewCatchSheet` and writes back through
/// `CatchStore.updateCatch(_:)`.
struct CatchDetailView: View {
    let entry: CatchEntry

    @ObservedObject private var catchStore = CatchStore.shared
    @ObservedObject private var spotStore = SpotStore.shared
    @State private var router = AppRouter.shared
    @Environment(\.dismiss) private var dismiss

    @State private var isEditing = false
    @State private var showDeleteConfirm = false
    @State private var showSavedToast = false

    @State private var draft: CatchEntry
    @State private var photoItem: PhotosPickerItem?
    @State private var weightField: String
    @State private var lengthField: String

    private let speciesSuggestions = [
        "Largemouth Bass", "Smallmouth Bass", "Trout", "Walleye",
        "Northern Pike", "Catfish", "Crappie", "Yellow Perch",
    ]

    init(entry: CatchEntry) {
        self.entry = entry
        _draft = State(initialValue: entry)
        _weightField = State(initialValue: entry.weight.map { Self.numberString($0) } ?? "")
        _lengthField = State(initialValue: entry.length.map { Self.numberString($0) } ?? "")
    }

    /// The freshest version of the entry. Falls back to the originally-passed
    /// value if the row was deleted out from under us (e.g. swipe-to-delete
    /// on the parent list while we're being popped off the stack).
    private var current: CatchEntry {
        catchStore.catches.first(where: { $0.id == entry.id }) ?? entry
    }

    private var linkedSpot: FishingSpot? {
        guard let spotId = current.spotId else { return nil }
        return spotStore.spots.first(where: { $0.id == spotId })
    }

    private var canSave: Bool {
        !draft.species.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        ZStack {
            LinearGradient.gradientPrimary.ignoresSafeArea()

            ScrollView {
                if isEditing {
                    editContent
                } else {
                    readContent
                }
            }
        }
        .navigationTitle(isEditing ? "Edit Catch" : current.species)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
        .toolbarBackground(Color.primaryBackground, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .alert("Delete this catch?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) {
                catchStore.deleteCatch(entry)
                Haptics.warning()
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This cannot be undone.")
        }
        .toast("Changes saved", isPresented: $showSavedToast)
        .onChange(of: photoItem) { _, item in
            Task { await loadPhoto(from: item) }
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
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    beginEdit()
                } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color.accentGold)
                }
                .accessibilityLabel("Edit catch")
            }
        }
    }

    // MARK: - Read mode

    private var readContent: some View {
        VStack(spacing: Spacing.md) {
            if let data = current.photo, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 260)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: Layout.radiusLg))
                    .padding(.horizontal, Layout.screenEdge)
            }

            VStack(spacing: Spacing.md) {
                headerReadCard
                if current.weight != nil || current.length != nil {
                    measurementsReadCard
                }
                if (current.lure?.isEmpty == false) || !current.notes.isEmpty {
                    detailsReadCard
                }
                if let snapshot = current.weatherSnapshot {
                    weatherReadCard(snapshot: snapshot)
                }
                if let spot = linkedSpot {
                    spotReadCard(spot: spot)
                }
            }
            .padding(.horizontal, Layout.screenEdge)
            .padding(.bottom, Spacing.xl)
        }
        .padding(.vertical, Spacing.md)
    }

    private var headerReadCard: some View {
        FishCastCard {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(current.species)
                    .font(.appTitle)
                    .foregroundStyle(Color.textPrimary)
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "calendar")
                    Text(current.date.formatted(date: .abbreviated, time: .shortened))
                }
                .font(.appCallout)
                .foregroundStyle(Color.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var measurementsReadCard: some View {
        FishCastCard {
            HStack(spacing: Spacing.lg) {
                if let weight = current.weight {
                    measurementColumn(label: "Weight", value: String(format: "%.1f lb", weight))
                }
                if let length = current.length {
                    measurementColumn(label: "Length", value: String(format: "%.1f in", length))
                }
                Spacer(minLength: 0)
            }
        }
    }

    private func measurementColumn(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .tracking(1.0)
                .foregroundStyle(Color.textSecondary)
            Text(value)
                .font(.appTitle2)
                .foregroundStyle(Color.accentGold)
                .monospacedDigit()
        }
    }

    private var detailsReadCard: some View {
        FishCastCard {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                if let lure = current.lure, !lure.isEmpty {
                    VStack(alignment: .leading, spacing: 2) {
                        sectionLabel("Lure / Bait")
                        Text(lure)
                            .font(.appBody)
                            .foregroundStyle(Color.textPrimary)
                    }
                }
                if !current.notes.isEmpty {
                    VStack(alignment: .leading, spacing: 2) {
                        sectionLabel("Notes")
                        Text(current.notes)
                            .font(.appBody)
                            .foregroundStyle(Color.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func weatherReadCard(snapshot: WeatherSnapshot) -> some View {
        FishCastCard {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                SectionHeader(title: "Conditions at Catch")
                HStack(spacing: Spacing.md) {
                    weatherStat(icon: AppIcons.temperature, value: "\(Int(snapshot.temperatureF))°F")
                    weatherStat(icon: AppIcons.barometer,   value: "\(Int(snapshot.pressureHPa)) hPa")
                    weatherStat(icon: AppIcons.wind,        value: "\(Int(snapshot.windMph)) mph")
                }
                if let moon = snapshot.moonPhase {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: AppIcons.moon)
                            .foregroundStyle(Color.accentGoldLight)
                        Text(moon)
                            .font(.appCallout)
                            .foregroundStyle(Color.textPrimary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func weatherStat(icon: String, value: String) -> some View {
        HStack(spacing: Spacing.xxs) {
            Image(systemName: icon)
                .foregroundStyle(Color.accentTeal)
            Text(value)
                .font(.appCallout)
                .foregroundStyle(Color.textPrimary)
                .monospacedDigit()
        }
    }

    private func spotReadCard(spot: FishingSpot) -> some View {
        Button {
            router.jumpToSpot(spot.id)
            Haptics.selection()
            dismiss()
        } label: {
            FishCastCard {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: AppIcons.location)
                        .font(.system(size: IconSize.card))
                        .foregroundStyle(Color.accentGold)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Spot")
                            .font(.appCaption)
                            .foregroundStyle(Color.textSecondary)
                            .tracking(1.5)
                        Text(spot.name)
                            .font(.appHeadline)
                            .foregroundStyle(Color.textPrimary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.textTertiary)
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Edit mode

    private var editContent: some View {
        VStack(spacing: Spacing.md) {
            photoEditCard
            speciesEditCard
            measurementsEditCard
            contextEditCard
            notesEditCard
            deleteCard
        }
        .padding(Layout.screenEdge)
    }

    private var photoEditCard: some View {
        FishCastCard {
            PhotosPicker(selection: $photoItem, matching: .images) {
                if let photoData = draft.photo, let uiImage = UIImage(data: photoData) {
                    ZStack(alignment: .bottomTrailing) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: .infinity)
                            .frame(height: 200)
                            .clipShape(RoundedRectangle(cornerRadius: Layout.radiusMd))
                        Image(systemName: "pencil.circle.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(Color.accentGold, Color.primaryBackground)
                            .padding(Spacing.xs)
                    }
                } else {
                    VStack(spacing: Spacing.xs) {
                        Image(systemName: "photo.badge.plus")
                            .font(.system(size: IconSize.hero))
                            .foregroundStyle(Color.accentGold)
                        Text("Add Photo")
                            .font(.appCallout)
                            .foregroundStyle(Color.textSecondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 140)
                }
            }
        }
    }

    private var speciesEditCard: some View {
        FishCastCard {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                fieldLabel("Species")
                TextField("e.g. Largemouth Bass", text: $draft.species)
                    .font(.appBody)
                    .foregroundStyle(Color.textPrimary)
                    .textFieldStyle(.plain)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Spacing.xs) {
                        ForEach(speciesSuggestions, id: \.self) { suggestion in
                            Button(suggestion) { draft.species = suggestion }
                                .font(.appCaption)
                                .padding(.horizontal, Spacing.sm)
                                .padding(.vertical, 6)
                                .background(Color.tertiaryBackground)
                                .foregroundStyle(Color.accentGold)
                                .clipShape(Capsule())
                        }
                    }
                }
                .padding(.top, 2)
            }
        }
    }

    private var measurementsEditCard: some View {
        FishCastCard {
            HStack(spacing: Spacing.md) {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    fieldLabel("Weight (lb)")
                    TextField("0.0", text: $weightField)
                        .keyboardType(.decimalPad)
                        .font(.appBody)
                        .foregroundStyle(Color.textPrimary)
                }
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    fieldLabel("Length (in)")
                    TextField("0", text: $lengthField)
                        .keyboardType(.decimalPad)
                        .font(.appBody)
                        .foregroundStyle(Color.textPrimary)
                }
            }
        }
    }

    private var contextEditCard: some View {
        FishCastCard {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    fieldLabel("Date")
                    DatePicker("", selection: $draft.date, in: ...Date(), displayedComponents: [.date, .hourAndMinute])
                        .labelsHidden()
                        .colorScheme(.dark)
                }

                VStack(alignment: .leading, spacing: Spacing.xs) {
                    fieldLabel("Spot")
                    Menu {
                        Button("None") { draft.spotId = nil }
                        ForEach(spotStore.spots) { spot in
                            Button(spot.name) { draft.spotId = spot.id }
                        }
                    } label: {
                        HStack {
                            Text(draftSpotName ?? "Pick a saved spot")
                                .foregroundStyle(draft.spotId == nil ? Color.textTertiary : Color.textPrimary)
                            Spacer()
                            Image(systemName: "chevron.up.chevron.down")
                                .foregroundStyle(Color.accentGold)
                        }
                        .font(.appBody)
                        .padding(.vertical, Spacing.xs)
                    }
                }

                VStack(alignment: .leading, spacing: Spacing.xs) {
                    fieldLabel("Lure / Bait")
                    TextField(
                        "Spinnerbait, jig, live bait…",
                        text: Binding(
                            get: { draft.lure ?? "" },
                            set: { draft.lure = $0 }
                        )
                    )
                    .font(.appBody)
                    .foregroundStyle(Color.textPrimary)
                }
            }
        }
    }

    private var notesEditCard: some View {
        FishCastCard {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                fieldLabel("Notes")
                TextField("Anything worth remembering…", text: $draft.notes, axis: .vertical)
                    .font(.appBody)
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(3 ... 6)
            }
        }
    }

    private var deleteCard: some View {
        Button(role: .destructive) {
            showDeleteConfirm = true
        } label: {
            HStack(spacing: Spacing.xs) {
                Image(systemName: "trash")
                Text("Delete Entry")
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
            .font(.system(size: 10, weight: .semibold))
            .tracking(1.0)
            .foregroundStyle(Color.textSecondary)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.appCaption)
            .foregroundStyle(Color.textSecondary)
            .tracking(1.5)
    }

    private var draftSpotName: String? {
        guard let id = draft.spotId else { return nil }
        return spotStore.spots.first(where: { $0.id == id })?.name
    }

    // MARK: - Actions

    private func beginEdit() {
        draft = current
        weightField = current.weight.map { Self.numberString($0) } ?? ""
        lengthField = current.length.map { Self.numberString($0) } ?? ""
        photoItem = nil
        withAnimation(.appEaseOut) { isEditing = true }
    }

    private func cancelEdit() {
        draft = current
        weightField = current.weight.map { Self.numberString($0) } ?? ""
        lengthField = current.length.map { Self.numberString($0) } ?? ""
        photoItem = nil
        withAnimation(.appEaseOut) { isEditing = false }
    }

    private func save() {
        var updated = draft
        updated.species = draft.species.trimmingCharacters(in: .whitespaces)
        updated.weight = Double(weightField.replacingOccurrences(of: ",", with: "."))
        updated.length = Double(lengthField.replacingOccurrences(of: ",", with: "."))
        updated.lure = draft.lure?.trimmingCharacters(in: .whitespaces).nilIfEmpty
        catchStore.updateCatch(updated)
        Haptics.success()
        showSavedToast = true
        withAnimation(.appEaseOut) { isEditing = false }
    }

    private func loadPhoto(from item: PhotosPickerItem?) async {
        guard let item else { return }
        guard let raw = try? await item.loadTransferable(type: Data.self) else { return }
        draft.photo = downsizedJPEG(from: raw, maxDimension: 1024)
    }

    private func downsizedJPEG(from data: Data, maxDimension: CGFloat) -> Data? {
        guard let image = UIImage(data: data) else { return data }
        let scale = min(1, maxDimension / max(image.size.width, image.size.height))
        let target = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: target)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
        return resized.jpegData(compressionQuality: 0.8)
    }

    private static func numberString(_ value: Double) -> String {
        if value == value.rounded() {
            return String(format: "%.0f", value)
        }
        return String(format: "%.1f", value)
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
