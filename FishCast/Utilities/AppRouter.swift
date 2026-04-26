import Foundation
import SwiftUI

/// Cross-tab navigation hub. Today its only consumer is the catch detail
/// view, which can ask the Map tab to focus a specific saved spot — adding
/// it here keeps `ContentView` the only place that knows tab indices.
@MainActor
@Observable
final class AppRouter {
    static let shared = AppRouter()

    enum Tab: Int, Hashable {
        case dashboard = 0
        case map = 1
        case forecast = 2
        case log = 3
        case settings = 4
    }

    var selectedTab: Tab = .dashboard

    /// When set, the Map tab focuses on this spot and opens its detail
    /// sheet on its next render, then clears the value.
    var spotToFocus: UUID?

    func jumpToSpot(_ spotId: UUID) {
        spotToFocus = spotId
        selectedTab = .map
    }
}
