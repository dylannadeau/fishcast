import SwiftUI

struct SettingsView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                Color.primaryBackground.ignoresSafeArea()

                VStack(spacing: Spacing.sm) {
                    Image(systemName: AppIcons.settings)
                        .font(.system(size: IconSize.hero))
                        .foregroundStyle(Color.accentGold)

                    Text("Settings")
                        .font(.appTitle)
                        .foregroundStyle(Color.textPrimary)

                    Text("App preferences & account")
                        .font(.appBody)
                        .foregroundStyle(Color.textSecondary)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

#Preview {
    SettingsView()
}
