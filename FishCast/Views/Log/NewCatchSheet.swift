import PhotosUI
import SwiftUI

/// Form for logging a new catch. Captures a best-effort weather snapshot in
/// the background while the user fills the form — saved with the entry if
/// it lands in time.
struct NewCatchSheet: View {
    let viewModel: CatchLogViewModel
    let spots: [FishingSpot]
    var onSave: (CatchEntry) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var species: String = ""
    @State private var date: Date = .now
    @State private var spotId: UUID?
    @State private var weight: String = ""
    @State private var length: String = ""
    @State private var lure: String = ""
    @State private var notes: String = ""

    @State private var photoItem: PhotosPickerItem?
    @State private var photoData: Data?

    @State private var snapshot: WeatherSnapshot?
    @State private var snapshotLoading = true

    private let speciesSuggestions = [
        "Largemouth Bass", "Smallmouth Bass", "Trout", "Walleye",
        "Northern Pike", "Catfish", "Crappie", "Yellow Perch",
    ]

    private var canSave: Bool {
        !species.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.primaryBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: Spacing.md) {
                        photoCard
                        speciesCard
                        measurementsCard
                        contextCard
                        notesCard
                        weatherCard
                    }
                    .padding(Layout.screenEdge)
                }
            }
            .navigationTitle("New Catch")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .foregroundStyle(canSave ? Color.accentGold : Color.textTertiary)
                        .disabled(!canSave)
                }
            }
            .toolbarBackground(Color.primaryBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .task {
            snapshot = await viewModel.captureWeatherSnapshot()
            snapshotLoading = false
        }
        .onChange(of: photoItem) { _, newItem in
            Task { await loadPhoto(from: newItem) }
        }
    }

    // MARK: - Cards

    private var photoCard: some View {
        FishCastCard {
            PhotosPicker(selection: $photoItem, matching: .images) {
                if let photoData, let uiImage = UIImage(data: photoData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .frame(height: 180)
                        .clipShape(RoundedRectangle(cornerRadius: Layout.radiusMd))
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

    private var speciesCard: some View {
        FishCastCard {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                fieldLabel("Species")
                TextField("e.g. Largemouth Bass", text: $species)
                    .font(.appBody)
                    .foregroundStyle(Color.textPrimary)
                    .textFieldStyle(.plain)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Spacing.xs) {
                        ForEach(speciesSuggestions, id: \.self) { suggestion in
                            Button(suggestion) { species = suggestion }
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

    private var measurementsCard: some View {
        FishCastCard {
            HStack(spacing: Spacing.md) {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    fieldLabel("Weight (lb)")
                    TextField("0.0", text: $weight)
                        .keyboardType(.decimalPad)
                        .font(.appBody)
                        .foregroundStyle(Color.textPrimary)
                }
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    fieldLabel("Length (in)")
                    TextField("0", text: $length)
                        .keyboardType(.decimalPad)
                        .font(.appBody)
                        .foregroundStyle(Color.textPrimary)
                }
            }
        }
    }

    private var contextCard: some View {
        FishCastCard {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    fieldLabel("Date")
                    DatePicker("", selection: $date, in: ...Date(), displayedComponents: [.date, .hourAndMinute])
                        .labelsHidden()
                        .colorScheme(.dark)
                }

                VStack(alignment: .leading, spacing: Spacing.xs) {
                    fieldLabel("Spot")
                    Menu {
                        Button("None") { spotId = nil }
                        ForEach(spots) { spot in
                            Button(spot.name) { spotId = spot.id }
                        }
                    } label: {
                        HStack {
                            Text(spotName ?? "Pick a saved spot")
                                .foregroundStyle(spotId == nil ? Color.textTertiary : Color.textPrimary)
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
                    TextField("Spinnerbait, jig, live bait…", text: $lure)
                        .font(.appBody)
                        .foregroundStyle(Color.textPrimary)
                }
            }
        }
    }

    private var notesCard: some View {
        FishCastCard {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                fieldLabel("Notes")
                TextField("Anything worth remembering…", text: $notes, axis: .vertical)
                    .font(.appBody)
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(3 ... 6)
            }
        }
    }

    @ViewBuilder
    private var weatherCard: some View {
        FishCastCard {
            HStack(spacing: Spacing.sm) {
                Image(systemName: AppIcons.weather)
                    .font(.system(size: IconSize.card))
                    .foregroundStyle(Color.accentTeal)
                if snapshotLoading {
                    Text("Capturing conditions…")
                        .font(.appCaption)
                        .foregroundStyle(Color.textSecondary)
                } else if let snapshot {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Conditions captured")
                            .font(.appCaption)
                            .foregroundStyle(Color.textSecondary)
                        Text("\(Int(snapshot.temperatureF))°F · \(Int(snapshot.pressureHPa)) hPa · \(Int(snapshot.windMph)) mph")
                            .font(.appCallout)
                            .foregroundStyle(Color.textPrimary)
                    }
                } else {
                    Text("No weather snapshot — saved without conditions.")
                        .font(.appCaption)
                        .foregroundStyle(Color.textTertiary)
                }
                Spacer()
            }
        }
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .semibold))
            .tracking(1.0)
            .foregroundStyle(Color.textSecondary)
    }

    private var spotName: String? {
        guard let id = spotId else { return nil }
        return spots.first(where: { $0.id == id })?.name
    }

    // MARK: - Actions

    private func loadPhoto(from item: PhotosPickerItem?) async {
        guard let item else { return }
        guard let raw = try? await item.loadTransferable(type: Data.self) else { return }
        photoData = downsizedJPEG(from: raw, maxDimension: 1024)
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

    private func save() {
        let entry = CatchEntry(
            date: date,
            spotId: spotId,
            species: species.trimmingCharacters(in: .whitespaces),
            weight: Double(weight),
            length: Double(length),
            lure: lure.trimmingCharacters(in: .whitespaces).nilIfEmpty,
            notes: notes,
            weatherSnapshot: snapshot,
            photo: photoData
        )
        onSave(entry)
        dismiss()
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
