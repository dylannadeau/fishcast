import SwiftUI

struct LogView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                Color.primaryBackground.ignoresSafeArea()

                VStack(spacing: Spacing.sm) {
                    Image(systemName: AppIcons.log)
                        .font(.system(size: IconSize.hero))
                        .foregroundStyle(Color.accentGold)

                    Text("Log")
                        .font(.appTitle)
                        .foregroundStyle(Color.textPrimary)

                    Text("Your fishing trip history")
                        .font(.appBody)
                        .foregroundStyle(Color.textSecondary)
                }
            }
            .navigationTitle("Log")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

#Preview {
    LogView()
}
