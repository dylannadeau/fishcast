import SwiftUI

/// Top-of-screen greeting + location + timestamp.
struct DashboardHeaderView: View {
    let locationName: String?
    let date: Date

    private var greeting: String {
        switch Calendar.current.component(.hour, from: date) {
        case 5 ..< 12:  return "Good morning"
        case 12 ..< 17: return "Good afternoon"
        case 17 ..< 22: return "Good evening"
        default:        return "Tight lines"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text(greeting)
                .font(.appCallout)
                .foregroundStyle(Color.textSecondary)

            HStack(spacing: Spacing.xs) {
                Image(systemName: AppIcons.location)
                    .foregroundStyle(Color.accentGold)
                Text(locationName ?? "Locating…")
                    .font(.appTitle)
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(1)
            }

            Text(date.formatted(.dateTime.weekday(.wide).month().day().hour().minute()))
                .font(.appCaption)
                .foregroundStyle(Color.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    DashboardHeaderView(locationName: "Lake Champlain", date: .now)
        .padding(Layout.screenEdge)
        .background(Color.primaryBackground)
}
