import SwiftUI
import UserNotifications

/// Full settings screen — units, daily reminder time, data tools, and about.
struct SettingsView: View {
    @AppStorage(SettingsKey.units) private var unitsRaw: String = UnitsPreference.imperial.rawValue
    @AppStorage(SettingsKey.notificationsOn) private var notificationsOn: Bool = false
    @AppStorage(SettingsKey.notificationsMinute) private var reminderMinutes: Int = 6 * 60 + 30

    @ObservedObject private var catchStore = CatchStore.shared
    @ObservedObject private var spotStore  = SpotStore.shared

    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined
    @State private var exportURL: URL?
    @State private var showingClearDataConfirm = false

    private var units: UnitsPreference {
        UnitsPreference(rawValue: unitsRaw) ?? .imperial
    }

    private var reminderTime: Date {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: .now)
        return start.addingTimeInterval(TimeInterval(reminderMinutes * 60))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient.gradientPrimary.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: Spacing.md) {
                        unitsCard
                        notificationsCard
                        dataCard
                        aboutCard
                    }
                    .padding(Layout.screenEdge)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(Color.primaryBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .task {
                notificationStatus = await NotificationScheduler.shared.currentAuthorizationStatus()
            }
            .sheet(item: shareItem) { item in
                ShareSheet(items: [item.url])
            }
            .alert("Clear all data?", isPresented: $showingClearDataConfirm) {
                Button("Cancel", role: .cancel) {}
                Button("Clear", role: .destructive) { clearAllData() }
            } message: {
                Text("This permanently deletes all saved spots and catch entries on this device.")
            }
        }
    }

    // MARK: - Cards

    private var unitsCard: some View {
        FishCastCard {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                cardHeader(icon: AppIcons.temperature, title: "Units")

                Picker("Units", selection: Binding(
                    get: { units },
                    set: { newValue in
                        Haptics.selection()
                        unitsRaw = newValue.rawValue
                    }
                )) {
                    ForEach(UnitsPreference.allCases) { option in
                        Text(option.label).tag(option)
                    }
                }
                .pickerStyle(.segmented)

                Text(units.summary)
                    .font(.appCaption)
                    .foregroundStyle(Color.textSecondary)
            }
        }
    }

    private var notificationsCard: some View {
        FishCastCard {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                cardHeader(icon: "bell.fill", title: "Daily Reminder")

                Toggle(isOn: Binding(
                    get: { notificationsOn },
                    set: { newValue in
                        notificationsOn = newValue
                        Task { await applyReminderState() }
                    }
                )) {
                    Text("Send a daily forecast reminder")
                        .font(.appBody)
                        .foregroundStyle(Color.textPrimary)
                }
                .tint(Color.accentGold)

                if notificationsOn {
                    DatePicker(
                        "Reminder time",
                        selection: Binding(
                            get: { reminderTime },
                            set: { newDate in
                                let comps = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                                reminderMinutes = (comps.hour ?? 6) * 60 + (comps.minute ?? 30)
                                Task { await applyReminderState() }
                            }
                        ),
                        displayedComponents: .hourAndMinute
                    )
                    .colorScheme(.dark)
                    .foregroundStyle(Color.textPrimary)
                }

                if notificationsOn, notificationStatus == .denied {
                    Text("Notifications are disabled in iOS Settings — enable them there to receive reminders.")
                        .font(.appCaption)
                        .foregroundStyle(Color.scoreFair)
                }
            }
        }
    }

    private var dataCard: some View {
        FishCastCard {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                cardHeader(icon: "tray.full", title: "Data")

                row(label: "Spots saved", value: "\(spotStore.spots.count)")
                row(label: "Catches logged", value: "\(catchStore.totalCatches)")

                Divider().overlay(Color.white.opacity(0.06))

                Button(action: exportCSV) {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text("Export catch log (CSV)")
                        Spacer()
                    }
                    .font(.appBody)
                    .foregroundStyle(Color.accentGold)
                }
                .disabled(catchStore.catches.isEmpty)
                .opacity(catchStore.catches.isEmpty ? 0.4 : 1)

                Button(role: .destructive) {
                    showingClearDataConfirm = true
                } label: {
                    HStack {
                        Image(systemName: "trash")
                        Text("Clear all data")
                        Spacer()
                    }
                    .font(.appBody)
                    .foregroundStyle(Color.scorePoor)
                }
            }
        }
    }

    private var aboutCard: some View {
        FishCastCard {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                cardHeader(icon: "info.circle", title: "About")

                row(label: "Version", value: appVersionString)

                Link(destination: URL(string: "https://example.com/fishcast-privacy")!) {
                    HStack {
                        Image(systemName: "lock.shield")
                        Text("Privacy Policy")
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.caption)
                    }
                    .font(.appBody)
                    .foregroundStyle(Color.accentGold)
                }

                Link(destination: URL(string: "mailto:feedback@example.com?subject=Anglers%20Edge%20Feedback")!) {
                    HStack {
                        Image(systemName: "envelope")
                        Text("Send Feedback")
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.caption)
                    }
                    .font(.appBody)
                    .foregroundStyle(Color.accentGold)
                }
            }
        }
    }

    // MARK: - Pieces

    private func cardHeader(icon: String, title: String) -> some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: icon)
                .foregroundStyle(Color.accentGold)
            Text(title)
                .font(.appHeadline)
                .foregroundStyle(Color.textPrimary)
        }
    }

    private func row(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.appBody)
                .foregroundStyle(Color.textSecondary)
            Spacer()
            Text(value)
                .font(.appBody)
                .foregroundStyle(Color.textPrimary)
                .monospacedDigit()
        }
    }

    private var appVersionString: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build   = info?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    // MARK: - Actions

    private func applyReminderState() async {
        if notificationsOn {
            let granted = await NotificationScheduler.shared.requestAuthorization()
            notificationStatus = await NotificationScheduler.shared.currentAuthorizationStatus()
            guard granted else {
                notificationsOn = false
                return
            }
            await NotificationScheduler.shared.scheduleDailyReminder(
                hour: reminderMinutes / 60,
                minute: reminderMinutes % 60
            )
        } else {
            NotificationScheduler.shared.cancelDailyReminder()
        }
    }

    private func exportCSV() {
        do {
            let url = try CatchExporter.writeCSV(
                catches: catchStore.catches,
                spots: spotStore.spots
            )
            Haptics.success()
            exportURL = url
        } catch {
            Haptics.warning()
        }
    }

    private func clearAllData() {
        // Snapshot first — iterating the @Published arrays directly while
        // mutating them would walk a moving target.
        let allCatches = catchStore.catches
        let allSpots = spotStore.spots
        for entry in allCatches { catchStore.deleteCatch(entry) }
        for spot in allSpots { spotStore.deleteSpot(spot) }
        Haptics.warning()
    }

    // Wrap exportURL into an Identifiable so .sheet(item:) can drive presentation.
    private var shareItem: Binding<ShareItem?> {
        Binding(
            get: { exportURL.map(ShareItem.init) },
            set: { newValue in exportURL = newValue?.url }
        )
    }
}

private struct ShareItem: Identifiable {
    let id = UUID()
    let url: URL
}

#Preview {
    SettingsView()
}
