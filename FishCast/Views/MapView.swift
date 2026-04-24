import SwiftUI

struct MapView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                Color.primaryBackground.ignoresSafeArea()

                VStack(spacing: Spacing.sm) {
                    Image(systemName: AppIcons.map)
                        .font(.system(size: IconSize.hero))
                        .foregroundStyle(Color.accentGold)

                    Text("Map")
                        .font(.appTitle)
                        .foregroundStyle(Color.textPrimary)

                    Text("Nearby fishing spots & conditions")
                        .font(.appBody)
                        .foregroundStyle(Color.textSecondary)
                }
            }
            .navigationTitle("Map")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

#Preview {
    MapView()
}
