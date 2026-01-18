import SwiftUI

// MARK: - Brand Colors

extension Color {
    // Primary brand colors
    static let brandPrimary = Color(hex: "2B6CB0")       // Deep blue
    static let brandSecondary = Color(hex: "D97706")     // Amber

    // Agent-specific accent colors
    static let claudeAccent = Color(hex: "F97316")       // Orange for Claude Code
    static let codexAccent = Color(hex: "22C55E")        // Green for Codex

    // Background colors
    static let backgroundPrimary = Color(nsColor: .windowBackgroundColor)
    static let backgroundSecondary = Color(nsColor: .controlBackgroundColor)
    static let backgroundTertiary = Color(nsColor: .underPageBackgroundColor)

    // Surface colors (for cards, panels)
    static let surfaceDefault = Color(nsColor: .controlBackgroundColor)
    static let surfaceElevated = Color(nsColor: .controlBackgroundColor).opacity(0.7)
    static let surfaceHover = Color(nsColor: .labelColor).opacity(0.05)

    // Stroke and separators
    static let strokeSoft = Color.primary.opacity(0.08)
    static let strokeStrong = Color.primary.opacity(0.16)

    // Text colors
    static let textPrimary = Color(nsColor: .labelColor)
    static let textSecondary = Color(nsColor: .secondaryLabelColor)
    static let textTertiary = Color(nsColor: .tertiaryLabelColor)

    // Status colors
    static let statusSuccess = Color(hex: "10B981")      // Green
    static let statusWarning = Color(hex: "F59E0B")      // Amber
    static let statusError = Color(hex: "EF4444")        // Red
    static let statusInfo = Color(hex: "3B82F6")         // Blue

    // Utility initializer for hex colors
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Theme Configuration

struct AppTheme {
    let accent: Color
    let accentGradient: LinearGradient
    let name: String

    static let claudeCode = AppTheme(
        accent: .claudeAccent,
        accentGradient: LinearGradient(
            colors: [Color(hex: "F97316"), Color(hex: "FB923C")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        ),
        name: "Claude Code"
    )

    static let codex = AppTheme(
        accent: .codexAccent,
        accentGradient: LinearGradient(
            colors: [Color(hex: "22C55E"), Color(hex: "4ADE80")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        ),
        name: "Codex"
    )

    static func forAgent(_ agent: AgentType) -> AppTheme {
        switch agent {
        case .claudeCode: return .claudeCode
        case .codex: return .codex
        }
    }
}

// MARK: - Custom View Modifiers

struct CardStyle: ViewModifier {
    var isHovering: Bool = false

    func body(content: Content) -> some View {
        content
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isHovering ? Color.surfaceHover : Color.surfaceElevated)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.strokeSoft, lineWidth: 1)
            )
    }
}

struct GradientButtonStyle: ButtonStyle {
    let gradient: LinearGradient

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
            .background(gradient)
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .shadow(color: Color.black.opacity(configuration.isPressed ? 0.08 : 0.18), radius: 8, y: 4)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
            .background(Color.surfaceElevated)
            .foregroundColor(.textPrimary)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(Color.strokeSoft, lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.12), value: configuration.isPressed)
    }
}

extension View {
    func cardStyle(isHovering: Bool = false) -> some View {
        modifier(CardStyle(isHovering: isHovering))
    }
}

// MARK: - Typography

struct AppTypography {
    static let titleLarge = Font.custom("Avenir Next", size: 26).weight(.semibold)
    static let titleMedium = Font.custom("Avenir Next", size: 18).weight(.semibold)
    static let titleSmall = Font.custom("Avenir Next", size: 14).weight(.semibold)
    static let bodyLarge = Font.custom("Avenir Next", size: 14).weight(.regular)
    static let bodyMedium = Font.custom("Avenir Next", size: 13).weight(.regular)
    static let bodySmall = Font.custom("Avenir Next", size: 12).weight(.regular)
    static let caption = Font.custom("Avenir Next", size: 11).weight(.regular)
    static let captionMedium = Font.custom("Avenir Next", size: 11).weight(.medium)
    static let micro = Font.custom("Avenir Next", size: 10).weight(.medium)
    static let mono = Font.custom("SF Mono", size: 11).weight(.regular)
}
