import SwiftUI

struct DashboardView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                Color.primaryBackground.ignoresSafeArea()

                VStack(spacing: Spacing.sm) {
                    Image(systemName: AppIcons.score)
                        .font(.system(size: IconSize.hero))
                        .foregroundStyle(Color.accentGold)

                    Text("Dashboard")
                        .font(.appTitle)
                        .foregroundStyle(Color.textPrimary)

                    Text("Fishing score & conditions overview")
                        .font(.appBody)
                        .foregroundStyle(Color.textSecondary)
                }
            }
            .navigationTitle("Dashboard")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

#Preview {
    DashboardView()
}
