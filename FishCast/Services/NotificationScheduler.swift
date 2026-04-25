import Foundation
import UserNotifications

/// Manages the daily fishing-forecast local notification.
///
/// The notification fires once a day at the user-selected time with a
/// generic body ("Today's fishing forecast is ready"). Tapping it opens
/// the app, where the Dashboard refreshes with current conditions —
/// dynamic per-day content would require BGTaskScheduler refresh, which
/// isn't worth the battery cost for a single daily reminder.
@MainActor
final class NotificationScheduler {
    static let shared = NotificationScheduler()

    private static let identifier = "com.fishcast.daily-forecast"
    private let center = UNUserNotificationCenter.current()

    /// Prompts the user for `.alert + .sound + .badge` permission. Returns
    /// the granted state. Safe to call repeatedly.
    @discardableResult
    func requestAuthorization() async -> Bool {
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    /// Current OS-level authorization status — used by the Settings UI to
    /// show whether the user has actually allowed alerts.
    func currentAuthorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    /// Schedules a recurring daily reminder at `hour`:`minute` (device-local
    /// time). Replaces any existing schedule.
    func scheduleDailyReminder(hour: Int, minute: Int) async {
        cancelDailyReminder()

        let content = UNMutableNotificationContent()
        content.title = "FishCast"
        content.body = "Today's fishing forecast is ready — check current conditions."
        content.sound = .default
        content.categoryIdentifier = Self.identifier

        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)

        let request = UNNotificationRequest(
            identifier: Self.identifier,
            content: content,
            trigger: trigger
        )
        try? await center.add(request)
    }

    func cancelDailyReminder() {
        center.removePendingNotificationRequests(withIdentifiers: [Self.identifier])
    }
}
