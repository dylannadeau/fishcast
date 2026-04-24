import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            DashboardView()
                .tabItem {
                    Label("Dashboard", systemImage: AppIcons.score)
                }

            MapView()
                .tabItem {
                    Label("Map", systemImage: AppIcons.map)
                }

            ForecastView()
                .tabItem {
                    Label("Forecast", systemImage: AppIcons.forecast)
                }

            LogView()
                .tabItem {
                    Label("Log", systemImage: AppIcons.log)
                }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: AppIcons.settings)
                }
        }
        .tint(Color.accentGold)
    }
}

#Preview {
    ContentView()
}
