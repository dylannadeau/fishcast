import SwiftUI

/// Three-screen first-launch flow. Permission prompts are best-effort —
/// the user can deny and still use the app (degraded experience handled
/// by the per-feature error states).
struct OnboardingView: View {
    @AppStorage(SettingsKey.onboardingComplete) private var onboardingComplete = false
    @State private var page: Int = 0

    var body: some View {
        ZStack {
            LinearGradient.gradientPrimary.ignoresSafeArea()

            VStack(spacing: 0) {
                TabView(selection: $page) {
                    welcomePage.tag(0)
                    locationPage.tag(1)
                    notificationsPage.tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.appSpring, value: page)

                pageIndicator
                    .padding(.bottom, Spacing.md)

                actionButtons
                    .padding(.horizontal, Layout.screenEdge)
                    .padding(.bottom, Spacing.xl)
            }
        }
    }

    // MARK: - Pages

    private var welcomePage: some View {
        OnboardingPage(
            icon: AppIcons.fish,
            iconColor: .accentGold,
            title: "Welcome to Anglers Edge",
            message: "Real-time fishing forecasts powered by weather, barometric pressure, moon phases, and tide data — so you know before you go."
        )
    }

    private var locationPage: some View {
        OnboardingPage(
            icon: AppIcons.location,
            iconColor: .accentTeal,
            title: "Find Spots Near You",
            message: "Anglers Edge uses your location to fetch live conditions and nearby NOAA tide stations. Your location never leaves your device."
        )
    }

    private var notificationsPage: some View {
        OnboardingPage(
            icon: AppIcons.weather,
            iconColor: .accentGoldLight,
            title: "Daily Bite Reminders",
            message: "Get a once-a-day push when conditions look promising — set the time in Settings later if you'd like."
        )
    }

    // MARK: - Indicator + actions

    private var pageIndicator: some View {
        HStack(spacing: 8) {
            ForEach(0 ..< 3, id: \.self) { index in
                Capsule()
                    .fill(index == page ? Color.accentGold : Color.textTertiary)
                    .frame(width: index == page ? 24 : 8, height: 8)
                    .animation(.appSpring, value: page)
            }
        }
    }

    @ViewBuilder
    private var actionButtons: some View {
        switch page {
        case 0:
            PrimaryButton(title: "Get Started") { advance() }
        case 1:
            VStack(spacing: Spacing.sm) {
                PrimaryButton(title: "Allow Location") {
                    Task {
                        Haptics.selection()
                        _ = await LocationService.shared.requestWhenInUseAuthorization()
                        advance()
                    }
                }
                GhostButton(title: "Maybe Later") { advance() }
            }
        case 2:
            VStack(spacing: Spacing.sm) {
                PrimaryButton(title: "Enable Notifications") {
                    Task {
                        Haptics.selection()
                        let granted = await NotificationScheduler.shared.requestAuthorization()
                        if granted {
                            await NotificationScheduler.shared.scheduleDailyReminder(hour: 6, minute: 30)
                        }
                        complete()
                    }
                }
                GhostButton(title: "Not Now") { complete() }
            }
        default:
            EmptyView()
        }
    }

    private func advance() {
        withAnimation(.appSpring) { page = min(page + 1, 2) }
    }

    private func complete() {
        Haptics.success()
        withAnimation(.appEaseOut) { onboardingComplete = true }
    }
}

// MARK: - Page chrome

private struct OnboardingPage: View {
    let icon: String
    let iconColor: Color
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: Spacing.lg) {
            Spacer()

            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 180, height: 180)
                Image(systemName: icon)
                    .font(.system(size: 80, weight: .semibold))
                    .foregroundStyle(iconColor)
                    .symbolRenderingMode(.hierarchical)
            }

            VStack(spacing: Spacing.sm) {
                Text(title)
                    .font(.appLargeTitle)
                    .foregroundStyle(Color.textPrimary)
                    .multilineTextAlignment(.center)

                Text(message)
                    .font(.appBody)
                    .foregroundStyle(Color.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, Layout.screenEdge)

            Spacer()
        }
    }
}

#Preview {
    OnboardingView()
}
