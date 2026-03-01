import UIKit

// MARK: - Haptics Helper
// Lightweight wrapper around UIKit haptics for micro-interactions.

enum Haptics {
    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }

    static func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(type)
    }

    static func selection() {
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
    }

    // Semantic helpers
    static func tap() { impact(.light) }
    static func match() { notification(.success) }
    static func error() { notification(.error) }
    static func toggle() { impact(.rigid) }
}
