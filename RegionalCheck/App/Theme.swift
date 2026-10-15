import SwiftUI

enum Theme {
    enum Colors {
        static let onFill = Color.white.opacity(0.92)
        static let onFillSecondary = Color.white.opacity(0.72)
    }

    enum Typography {
        static let caption = Font.system(.footnote, design: .rounded).weight(.regular)
    }

    enum Spacing {
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
    }

    enum Shadows {
        static let soft = Color.black.opacity(0.28)
        static let softRadius: CGFloat = 12
        static let softY: CGFloat = 6
    }

    enum Haptics {
        static let button = SensoryFeedback.press(.button)
        static let icon = SensoryFeedback.press(.buttonIconOnly)
    }
}

struct HapticButtonStyle: ButtonStyle {
    var feedback: SensoryFeedback = Theme.Haptics.button

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.72 : 1)
            .sensoryFeedback(feedback, trigger: configuration.isPressed) { _, isPressed in
                isPressed
            }
    }
}
