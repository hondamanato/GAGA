import SwiftUI

enum GAGATheme {
    // MARK: - Brand Colors
    static let coral = Color(red: 1.0, green: 0.42, blue: 0.42)       // #FF6B6B
    static let amber = Color(red: 1.0, green: 0.70, blue: 0.28)       // #FFB347
    static let deepNavy = Color(red: 0.05, green: 0.11, blue: 0.16)   // #0D1B2A

    // MARK: - Gradients
    static let accentGradient = LinearGradient(
        colors: [coral, amber],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let accentGradientVertical = LinearGradient(
        colors: [coral, amber],
        startPoint: .top,
        endPoint: .bottom
    )

    // MARK: - Status Colors
    static func tripStatusColor(_ status: TripStatus) -> Color {
        switch status {
        case .planning: .orange
        case .traveling: .green
        case .completed: .cyan
        }
    }

    // MARK: - Typography (SF Pro Rounded)
    static let titleFont: Font = .system(.title, design: .rounded, weight: .bold)
    static let headlineFont: Font = .system(.headline, design: .rounded, weight: .semibold)
    static let bodyFont: Font = .system(.body, design: .rounded)
    static let captionFont: Font = .system(.caption, design: .rounded)
    static let largeTitleFont: Font = .system(.largeTitle, design: .rounded, weight: .bold)

    // MARK: - Dimensions
    static let cardRadius: CGFloat = 20
    static let buttonRadius: CGFloat = 16
    static let avatarRingWidth: CGFloat = 2.5

    // MARK: - Spacing
    static let spacingXS: CGFloat = 4
    static let spacingSM: CGFloat = 8
    static let spacingMD: CGFloat = 16
    static let spacingLG: CGFloat = 24
    static let spacingXL: CGFloat = 32

    // MARK: - Animation
    static let springBounce: Animation = .spring(duration: 0.4, bounce: 0.3)
    static let springSnappy: Animation = .spring(duration: 0.25)
}
