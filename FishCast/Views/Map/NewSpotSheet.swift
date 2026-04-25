import CoreLocation
import SwiftUI

/// Sheet shown after a long-press on the map — collects a name + notes for
/// the new spot before saving to the `SpotStore`.
struct NewSpotSheet: View {
    let coordinate: CLLocationCoordinate2D
    let onSave: (_ name: String, _ notes: String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""
    @State private var notes: String = ""
    @FocusState private var nameFieldFocused: Bool

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.primaryBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: Spacing.md) {
                        FishCastCard {
                            VStack(alignment: .leading, spacing: Spacing.sm) {
                                fieldLabel("Name")
                                TextField("e.g. Willow Creek Bend", text: $name)
                                    .textInputAutocapitalization(.words)
                                    .autocorrectionDisabled()
                                    .focused($nameFieldFocused)
                                    .padding(Spacing.sm)
                                    .background(Color.tertiaryBackground)
                                    .clipShape(RoundedRectangle(cornerRadius: Layout.radiusSm))
                                    .foregroundStyle(Color.textPrimary)

                                fieldLabel("Notes")
                                TextField("Structure, access, what was biting…", text: $notes, axis: .vertical)
                                    .textInputAutocapitalization(.sentences)
                                    .lineLimit(3 ... 6)
                                    .padding(Spacing.sm)
                                    .background(Color.tertiaryBackground)
                                    .clipShape(RoundedRectangle(cornerRadius: Layout.radiusSm))
                                    .foregroundStyle(Color.textPrimary)
                            }
                        }

                        FishCastCard {
                            HStack(spacing: Spacing.sm) {
                                Image(systemName: AppIcons.location)
                                    .foregroundStyle(Color.accentGold)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Coordinates")
                                        .font(.appCaption)
                                        .foregroundStyle(Color.textSecondary)
                                        .tracking(1.5)
                                    Text(coordinateString)
                                        .font(.appCallout.monospacedDigit())
                                        .foregroundStyle(Color.textPrimary)
                                }

                                Spacer()
                            }
                        }
                    }
                    .padding(Layout.screenEdge)
                }
            }
            .navigationTitle("Save Spot")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(trimmedName, notes.trimmingCharacters(in: .whitespacesAndNewlines))
                    }
                    .foregroundStyle(trimmedName.isEmpty ? Color.textTertiary : Color.accentGold)
                    .disabled(trimmedName.isEmpty)
                }
            }
            .toolbarBackground(Color.primaryBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .onAppear { nameFieldFocused = true }
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.appCaption)
            .foregroundStyle(Color.textSecondary)
            .tracking(1.5)
    }

    private var coordinateString: String {
        String(format: "%.5f, %.5f", coordinate.latitude, coordinate.longitude)
    }
}
