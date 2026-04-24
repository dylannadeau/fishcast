import SwiftUI

@main
struct FishCastApp: App {

    init() {
        configureTabBarAppearance()
        configureNavigationBarAppearance()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
        }
    }

    // MARK: - UIKit appearance overrides

    private func configureTabBarAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(Color.secondaryBackground)

        let itemAppearance = UITabBarItemAppearance()
        itemAppearance.normal.iconColor    = UIColor(Color.textTertiary)
        itemAppearance.normal.titleTextAttributes    = [.foregroundColor: UIColor(Color.textTertiary)]
        itemAppearance.selected.iconColor  = UIColor(Color.accentGold)
        itemAppearance.selected.titleTextAttributes  = [.foregroundColor: UIColor(Color.accentGold)]

        appearance.stackedLayoutAppearance = itemAppearance
        appearance.inlineLayoutAppearance  = itemAppearance
        appearance.compactInlineLayoutAppearance = itemAppearance

        UITabBar.appearance().standardAppearance   = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    private func configureNavigationBarAppearance() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(Color.secondaryBackground)
        appearance.titleTextAttributes = [
            .foregroundColor: UIColor(Color.textPrimary),
            .font: UIFont.systemFont(ofSize: 17, weight: .semibold),
        ]
        appearance.largeTitleTextAttributes = [
            .foregroundColor: UIColor(Color.textPrimary),
            .font: UIFont.systemFont(ofSize: 34, weight: .bold),
        ]

        UINavigationBar.appearance().standardAppearance   = appearance
        UINavigationBar.appearance().compactAppearance    = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().tintColor = UIColor(Color.accentGold)
    }
}
