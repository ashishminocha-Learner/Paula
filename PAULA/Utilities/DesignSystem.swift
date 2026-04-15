import SwiftUI

// MARK: - Brand Colors
extension Color {
    /// Deep navy — primary screen background
    static let paulaNavy     = Color(red: 0.059, green: 0.078, blue: 0.157)
    /// Mid navy — elevated surfaces on dark screens
    static let paulaNavyMid  = Color(red: 0.102, green: 0.125, blue: 0.251)
    /// Electric blue — primary accent, waveform bars, links
    static let paulaBlue     = Color(red: 0.290, green: 0.498, blue: 1.000)
    /// Cyan — secondary accent, waveform top highlight
    static let paulaCyan     = Color(red: 0.369, green: 0.773, blue: 1.000)
    /// Coral red — recording state, destructive actions
    static let paulaRed      = Color(red: 1.000, green: 0.231, blue: 0.361)
}

// MARK: - Brand Gradients
extension LinearGradient {
    /// Full-screen dark background for the Record screen
    static let paulaBackground = LinearGradient(
        colors: [Color(red: 0.086, green: 0.102, blue: 0.220),
                 Color(red: 0.031, green: 0.039, blue: 0.094)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    /// Gradient used for waveform bars
    static let paulaWaveform = LinearGradient(
        colors: [Color.paulaBlue, Color.paulaCyan],
        startPoint: .bottom,
        endPoint: .top
    )
    /// Gradient for the subscription hero card
    static let paulaSubscription = LinearGradient(
        colors: [Color(red: 0.102, green: 0.125, blue: 0.310),
                 Color(red: 0.180, green: 0.320, blue: 0.780)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

// MARK: - Typography
extension Font {
    /// Large recording timer: thin monospaced
    static let paulaTimer    = Font.system(size: 70, weight: .thin, design: .monospaced)
    /// Screen display title
    static let paulaDisplay  = Font.system(.largeTitle, design: .rounded, weight: .bold)
    /// Section / card title
    static let paulaTitle    = Font.system(.title2, design: .rounded, weight: .semibold)
    /// Row headline
    static let paulaHeadline = Font.system(.headline, design: .rounded, weight: .semibold)
    /// Pill / badge label
    static let paulaLabel    = Font.system(.caption2, design: .rounded, weight: .bold)
}

// MARK: - Card Style
struct CardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Color.white.opacity(0.07))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.10), lineWidth: 0.5)
            )
    }
}

extension View {
    func paulaCard() -> some View { modifier(CardModifier()) }
}
