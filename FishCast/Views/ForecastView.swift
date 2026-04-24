import SwiftUI

struct ForecastView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                Color.primaryBackground.ignoresSafeArea()

                VStack(spacing: Spacing.sm) {
                    Image(systemName: AppIcons.forecast)
                        .font(.system(size: IconSize.hero))
                        .foregroundStyle(Color.accentGold)

                    Text("Forecast")
                        .font(.appTitle)
                        .foregroundStyle(Color.textPrimary)

                    Text("7-day bite window forecast")
                        .font(.appBody)
                        .foregroundStyle(Color.textSecondary)
                }
            }
            .navigationTitle("Forecast")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

#Preview {
    ForecastView()
}
