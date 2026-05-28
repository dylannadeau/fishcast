import CoreLocation
import SwiftUI

/// Top-of-screen header: location name, today's date, coordinates subtitle,
/// and a compact refresh button. Tap the button to re-fetch conditions.
struct DashboardHeaderView: View {
    let locationName: String?
    let coordinate: CLLocationCoordinate2D?
    let date: Date
    var isRefreshing: Bool = false
    var onRefresh: () -> Void = {}

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: AppIcons.location)
                        .foregroundStyle(Color.accentGold)
                    Text(locationName ?? "Locating…")
                        .font(.appTitle)
                        .foregroundStyle(Color.textPrimary)
                        .lineLimit(1)
                }

                Text(date.formatted(.dateTime.weekday(.wide).month().day().year()))
                    .font(.appCallout)
                    .foregroundStyle(Color.textSecondary)

                if let coordinate {
                    Text(coordinateString(coordinate))
                        .font(.appCaption.monospacedDigit())
                        .foregroundStyle(Color.textTertiary)
                }
            }

            Spacer(minLength: 0)

            Button(action: onRefresh) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.accentGold)
                    .padding(Spacing.xs)
                    .background(Color.secondaryBackground)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.white.opacity(0.06), lineWidth: 1))
                    .rotationEffect(.degrees(isRefreshing ? 360 : 0))
                    .animation(
                        isRefreshing
                            ? .linear(duration: 1.0).repeatForever(autoreverses: false)
                            : .default,
                        value: isRefreshing
                    )
            }
            .accessibilityLabel("Refresh conditions")
            .disabled(isRefreshing)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func coordinateString(_ coordinate: CLLocationCoordinate2D) -> String {
        String(format: "%.4f° %@, %.4f° %@",
               abs(coordinate.latitude),  coordinate.latitude  >= 0 ? "N" : "S",
               abs(coordinate.longitude), coordinate.longitude >= 0 ? "E" : "W")
    }
}

#Preview {
    DashboardHeaderView(
        locationName: "Lake Champlain",
        coordinate: CLLocationCoordinate2D(latitude: 44.4759, longitude: -73.2121),
        date: .now
    )
    .padding(Layout.screenEdge)
    .background(Color.primaryBackground)
}
