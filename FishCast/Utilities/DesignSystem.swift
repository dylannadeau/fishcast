import SwiftUI

// MARK: - Color

extension Color {

    // MARK: Backgrounds
    static let primaryBackground   = Color(ds: "#0A1628")
    static let secondaryBackground = Color(ds: "#112240")
    static let tertiaryBackground  = Color(ds: "#1A3256")

    // MARK: Accents
    static let accentGold      = Color(ds: "#F0A500")
    static let accentGoldLight = Color(ds: "#FFD166")
    static let accentTeal      = Color(ds: "#2EC4B6")

    // MARK: Text
    static let textPrimary   = Color(ds: "#F0F4F8")
    static let textSecondary = Color(ds: "#8BA3BC")
    static let textTertiary  = Color(ds: "#4A6580")

    // MARK: Score
    static let scoreExcellent = Color(ds: "#4CAF50")
    static let scoreGood      = Color(ds: "#8BC34A")
    static let scoreFair      = Color(ds: "#FFC107")
    static let scorePoor      = Color(ds: "#F44336")

    // Prefixed `ds:` to avoid colliding with any future SDK hex inits.
    init(ds hex: String) {
        let raw = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: raw).scanHexInt64(&value)
        self.init(
            red:   Double((value >> 16) & 0xFF) / 255,
            green: Double((value >>  8) & 0xFF) / 255,
            blue:  Double( value        & 0xFF) / 255
        )
    }
}

// MARK: - Gradients

extension LinearGradient {
    /// Deep navy — main screen backgrounds.
    static let gradientPrimary = LinearGradient(
        colors: [.primaryBackground, .secondaryBackground],
        startPoint: .top,
        endPoint: .bottom
    )

    /// Amber gold — score ring, hero elements.
    static let gradientGold = LinearGradient(
        colors: [.accentGold, .accentGoldLight],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Navy → teal — map, tide views.
    static let gradientWater = LinearGradient(
        stops: [
            .init(color: .primaryBackground,  location: 0.0),
            .init(color: .tertiaryBackground, location: 0.5),
            .init(color: .accentTeal,         location: 1.0),
        ],
        startPoint: .top,
        endPoint: .bottom
    )
}

// MARK: - Typography

extension Font {
    static let appLargeTitle = Font.system(size: 34, weight: .bold)
    static let appTitle      = Font.system(size: 24, weight: .bold)
    static let appTitle2     = Font.system(size: 20, weight: .semibold)
    static let appHeadline   = Font.system(size: 17, weight: .semibold)
    static let appBody       = Font.system(size: 15, weight: .regular)
    static let appCallout    = Font.system(size: 14, weight: .medium)
    static let appCaption    = Font.system(size: 12, weight: .regular)
    /// The large centred number inside the score ring.
    static let appScore      = Font.system(size: 56, weight: .heavy)
}

// MARK: - Spacing

enum Spacing {
    static let xxs: CGFloat = 4
    static let xs:  CGFloat = 8
    static let sm:  CGFloat = 12
    static let md:  CGFloat = 16
    static let lg:  CGFloat = 24
    static let xl:  CGFloat = 32
    static let xxl: CGFloat = 48
}

// MARK: - Layout

enum Layout {
    // Corner radii
    static let radiusSm: CGFloat = 8   // chips, small tags
    static let radiusMd: CGFloat = 12  // cards
    static let radiusLg: CGFloat = 20  // bottom sheets, modals
    static let radiusXl: CGFloat = 28  // hero cards

    // Padding
    static let cardPadding: CGFloat = 16
    static let screenEdge:  CGFloat = 20
}

// MARK: - Icon Sizes

enum IconSize {
    static let tabBar: CGFloat = 22
    static let card:   CGFloat = 18
    static let hero:   CGFloat = 32
}

// MARK: - SF Symbol Names

enum AppIcons {
    static let fish        = "fish.fill"
    static let location    = "location.fill"
    static let weather     = "cloud.sun.fill"
    static let wind        = "wind"
    static let barometer   = "gauge.with.dots.needle.50percent"
    static let moon        = "moon.stars.fill"
    static let tide        = "water.waves"
    static let temperature = "thermometer.medium"
    static let log         = "book.closed.fill"
    static let map         = "map.fill"
    static let forecast    = "chart.line.uptrend.xyaxis"
    static let settings    = "gear"
    static let plus        = "plus.circle.fill"
    static let score       = "target"
}

// MARK: - Animation

extension Animation {
    /// Default interactive spring — cards, rings, sheet transitions.
    static let appSpring  = Animation.spring(response: 0.4, dampingFraction: 0.7)
    /// Quick exit — cards fading/sliding away.
    static let appEaseOut = Animation.easeOut(duration: 0.25)
    /// Quick enter — elements arriving.
    static let appEaseIn  = Animation.easeIn(duration: 0.2)
}

// MARK: - App Icon Note
//
// Concept: bold fish hook forming the letter "F" on a deep navy circular
// background with a gold gradient — clean, minimal, recognisable at small sizes.
// Until final assets are delivered, generate AppIcon placeholder via Canvas:
// 1024×1024, primaryBackground fill, centred accentGold "F"-hook shape.
