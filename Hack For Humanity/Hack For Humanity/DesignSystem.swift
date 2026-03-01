import SwiftUI

// MARK: - Pantri Design System
// Centralized styling tokens for colors, fonts, spacing, and corner radii.
// Inspired by the Luma app: clean surfaces, generous whitespace, premium feel.

enum PantriColors {
    static let green = Color(hex: "00C405")
    static let darkGreen = Color(hex: "00A004")
    static let lightGreen = Color(hex: "E8FFE9")
    static let black = Color(hex: "1A1A1A")
    static let background = Color(hex: "FAFAFA")
    static let card = Color.white
    static let secondaryText = Color(hex: "6B7280")
    static let border = Color(hex: "E5E7EB")
    static let destructive = Color(hex: "EF4444")
    static let warning = Color(hex: "F59E0B")
    static let availabilityHigh = Color(hex: "22C55E")
    static let availabilityMed = Color(hex: "F59E0B")
    static let availabilityLow = Color(hex: "EF4444")
}

enum PantriSpacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 48
}

enum PantriRadius {
    static let sm: CGFloat = 8
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let full: CGFloat = 999
}

enum PantriFonts {
    // When Qurova fonts are added to the project, these will resolve automatically.
    // Fallback: system rounded fonts for a similar premium feel.
    static func semiBold(size: CGFloat) -> Font {
        .custom("Qurova-SemiBold", size: size, relativeTo: .body)
    }

    static func regular(size: CGFloat) -> Font {
        .custom("Qurova-Regular", size: size, relativeTo: .body)
    }

    // Semantic aliases
    static let largeTitle = semiBold(size: 34)
    static let title = semiBold(size: 28)
    static let title2 = semiBold(size: 22)
    static let title3 = semiBold(size: 20)
    static let headline = semiBold(size: 17)
    static let body = regular(size: 17)
    static let callout = regular(size: 16)
    static let subheadline = regular(size: 15)
    static let footnote = regular(size: 13)
    static let caption = regular(size: 12)
}

enum PantriShadow {
    static let sm = (color: Color.black.opacity(0.04), radius: CGFloat(8), x: CGFloat(0), y: CGFloat(2))
    static let md = (color: Color.black.opacity(0.08), radius: CGFloat(16), x: CGFloat(0), y: CGFloat(4))
    static let lg = (color: Color.black.opacity(0.12), radius: CGFloat(24), x: CGFloat(0), y: CGFloat(8))
}

// MARK: - Color Hex Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6:
            (a, r, g, b) = (255, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = ((int >> 24) & 0xFF, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
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

// MARK: - Pantri Card Style

struct PantriCardStyle: ViewModifier {
    var padding: CGFloat = PantriSpacing.md

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(PantriColors.card)
            .clipShape(RoundedRectangle(cornerRadius: PantriRadius.lg, style: .continuous))
            .shadow(
                color: PantriShadow.sm.color,
                radius: PantriShadow.sm.radius,
                x: PantriShadow.sm.x,
                y: PantriShadow.sm.y
            )
    }
}

extension View {
    func pantriCard(padding: CGFloat = PantriSpacing.md) -> some View {
        modifier(PantriCardStyle(padding: padding))
    }
}

// MARK: - Glassmorphism Modifier

struct GlassBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: PantriRadius.lg, style: .continuous))
    }
}

extension View {
    func glassBackground() -> some View {
        modifier(GlassBackground())
    }
}

// MARK: - Skeleton Loading Modifier

struct SkeletonModifier: ViewModifier {
    @State private var isAnimating = false

    func body(content: Content) -> some View {
        content
            .redacted(reason: .placeholder)
            .overlay(
                RoundedRectangle(cornerRadius: PantriRadius.sm)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.clear,
                                Color.white.opacity(0.4),
                                Color.clear
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .offset(x: isAnimating ? 300 : -300)
            )
            .clipShape(RoundedRectangle(cornerRadius: PantriRadius.sm))
            .onAppear {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    isAnimating = true
                }
            }
    }
}

extension View {
    func skeleton() -> some View {
        modifier(SkeletonModifier())
    }
}

// MARK: - Spring Animations

enum PantriAnimation {
    static let snappy = Animation.spring(response: 0.35, dampingFraction: 0.85, blendDuration: 0)
    static let smooth = Animation.spring(response: 0.5, dampingFraction: 0.8, blendDuration: 0)
    static let bouncy = Animation.spring(response: 0.4, dampingFraction: 0.65, blendDuration: 0)
}
