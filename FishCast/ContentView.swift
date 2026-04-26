import SwiftUI

struct ContentView: View {
    @State private var router = AppRouter.shared

    var body: some View {
        @Bindable var router = router

        TabView(selection: $router.selectedTab) {
            DashboardView()
                .tabItem {
                    Label("Dashboard", systemImage: AppIcons.score)
                }
                .tag(AppRouter.Tab.dashboard)

            MapView()
                .tabItem {
                    Label("Map", systemImage: AppIcons.map)
                }
                .tag(AppRouter.Tab.map)

            ForecastView()
                .tabItem {
                    Label("Forecast", systemImage: AppIcons.forecast)
                }
                .tag(AppRouter.Tab.forecast)

            LogView()
                .tabItem {
                    Label("Log", systemImage: AppIcons.log)
                }
                .tag(AppRouter.Tab.log)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: AppIcons.settings)
                }
                .tag(AppRouter.Tab.settings)
        }
        .tint(Color.accentGold)
    }
}

#Preview {
    ContentView()
}
