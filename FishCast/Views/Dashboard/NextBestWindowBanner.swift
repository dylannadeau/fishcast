import SwiftUI

/// Amber/gold "next good window" banner shown when the current score is poor
/// or fair. Displays the upcoming window's date range and a live countdown.
struct NextBestWindowBanner: View {
    let window: DateInterval
    var onTap: () -> Void = {}

    @State private var now: Date = .now

    /// Drives the countdown text. One-second tick is fine — the label only
    /// ever shows hours + minutes, so we're not over-rendering.
    private let timer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "sun.horizon.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(LinearGradient.gradientGold)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Next good window")
                        .font(.appCaption)
                        .foregroundStyle(Color.primaryBackground.opacity(0.7))
                        .tracking(1.2)
                    Text(windowLabel)
                        .font(.appHeadline)
                        .foregroundStyle(Color.primaryBackground)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                    Text(countdownLabel)
                        .font(.appCaption)
                        .foregroundStyle(Color.primaryBackground.opacity(0.75))
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.primaryBackground.opacity(0.7))
            }
            .padding(Layout.cardPadding)
            .background(LinearGradient.gradientGold)
            .clipShape(RoundedRectangle(cornerRadius: Layout.radiusMd))
            .shadow(color: Color.accentGold.opacity(0.35), radius: 10, x: 0, y: 4)
        }
        .buttonStyle(.plain)
        .onReceive(timer) { now = $0 }
    }

    // MARK: - Labels

    private var windowLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        let start = formatter.string(from: window.start)
        let end = formatter.string(from: window.end)
        return "\(dayPrefix) \(start)–\(end)"
    }

    private var dayPrefix: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(window.start) { return "Today" }
        if calendar.isDateInTomorrow(window.start) { return "Tomorrow" }
        let day = DateFormatter()
        day.dateFormat = "EEEE"
        return day.string(from: window.start)
    }

    private var countdownLabel: String {
        let delta = window.start.timeIntervalSince(now)
        if delta <= 0 {
            // We're inside the window — show how long is left.
            let remaining = max(0, window.end.timeIntervalSince(now))
            return "Window open — \(formatDuration(remaining)) left"
        }
        return "In \(formatDuration(delta))"
    }

    private func formatDuration(_ interval: TimeInterval) -> String {
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        if hours == 0 { return "\(minutes)m" }
        return "\(hours)h \(minutes)m"
    }
}

#Preview {
    NextBestWindowBanner(
        window: DateInterval(
            start: Date().addingTimeInterval(9 * 3600 + 42 * 60),
            end: Date().addingTimeInterval(11 * 3600 + 30 * 60)
        )
    )
    .padding(Layout.screenEdge)
    .background(Color.primaryBackground)
}
