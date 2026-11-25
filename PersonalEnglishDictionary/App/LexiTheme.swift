import SwiftUI

/// Shared visual identity for Lexi. All colors are intentionally dark-mode first.
enum LexiTheme {
    // Brand
    static let navy = Color(red: 16.0 / 255, green: 23.0 / 255, blue: 43.0 / 255)
    static let mint = Color(red: 128.0 / 255, green: 239.0 / 255, blue: 174.0 / 255)
    static let deepBlue = Color(red: 25.0 / 255, green: 43.0 / 255, blue: 80.0 / 255)

    // Semantic colors
    static let background = navy
    static let surface = Color(red: 32.0 / 255, green: 45.0 / 255, blue: 72.0 / 255)
    static let tabBar = Color(red: 25.0 / 255, green: 35.0 / 255, blue: 59.0 / 255)
    static let primaryText = Color.white
    static let secondaryText = Color(red: 194.0 / 255, green: 203.0 / 255, blue: 220.0 / 255)
    static let inactive = Color(red: 160.0 / 255, green: 171.0 / 255, blue: 191.0 / 255)
    static let accent = mint
    static let onAccent = navy
    static let favorite = Color(red: 247.0 / 255, green: 193.0 / 255, blue: 93.0 / 255)
    static let destructive = Color(red: 255.0 / 255, green: 122.0 / 255, blue: 130.0 / 255)
    static let border = Color.white.opacity(0.12)

    // Layout
    static let cornerRadius: CGFloat = 20
    static let smallCornerRadius: CGFloat = 12
    static let screenPadding: CGFloat = 16
    static let spacing: CGFloat = 16

    // Typography
    static let brandFont = Font.system(size: 44, weight: .bold, design: .serif)
    static let titleFont = Font.largeTitle.weight(.bold)
    static let cardTitleFont = Font.headline
    static let captionFont = Font.subheadline

    // Optional brand gradient for prominent cards or headers.
    static let brandGradient = LinearGradient(
        colors: [deepBlue, navy],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}
