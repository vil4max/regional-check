import SwiftUI

enum Theme {
    enum Colors {
        static let normal = Color("Normal")
        static let attention = Color(red: 0.88, green: 0.48, blue: 0.48)
        static let checking = Color(red: 0.55, green: 0.57, blue: 0.60)
        static let onboarding = Color(red: 0.86, green: 0.68, blue: 0.28)
        static let tabSelected = Color.white
        static let unavailable = Color("Unavailable")
        static let onFill = Color.white.opacity(0.92)
        static let onFillSecondary = Color.white.opacity(0.72)
        static let dashboard = Color(red: 0.07, green: 0.08, blue: 0.10)
        static let separator = Color.white.opacity(0.18)

        static func statusAccent(for state: StatusState) -> Color {
            switch state {
            case .alarm:
                attention
            case .quiet:
                normal
            case .idle:
                checking
            case .error, .regionUnavailable:
                unavailable
            }
        }

        static func statusBackdrop(for state: StatusState) -> LinearGradient {
            let accent = statusAccent(for: state)
            return LinearGradient(
                colors: [
                    dashboard,
                    dashboard.mix(with: accent, by: 0.28),
                    dashboard.mix(with: accent, by: 0.12)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }

        static var onboardingGradient: LinearGradient {
            gradient(base: onboarding)
        }

        private static func gradient(base: Color) -> LinearGradient {
            LinearGradient(
                colors: [
                    base.mix(with: .white, by: 0.18),
                    base,
                    base.mix(with: .black, by: 0.22)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    enum Typography {
        static let stateTitle = Font.system(.largeTitle, design: .rounded).weight(.bold)
        static let regionTitle = Font.system(.title, design: .rounded).weight(.semibold)
        static let caption = Font.system(.footnote, design: .rounded).weight(.regular)
        static let refreshLabel = Font.system(.caption, design: .rounded).weight(.semibold)
        static let symbol = Font.system(size: 88, weight: .medium)
        static let refreshSymbol = Font.system(size: 20, weight: .semibold)
    }

    enum Spacing {
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let refreshControl: CGFloat = 44
    }

    enum Motion {
        static let stateSpring = Animation.spring(response: 0.45, dampingFraction: 0.82)
        static let quietFade = Animation.easeInOut(duration: 0.9)
        static let loudPulse = Animation.easeInOut(duration: 1.15).repeatForever(autoreverses: true)
    }

    enum Shadows {
        static let soft = Color.black.opacity(0.28)
        static let softRadius: CGFloat = 12
        static let softY: CGFloat = 6
        static let elevated = Color.black.opacity(0.35)
        static let elevatedRadius: CGFloat = 18
        static let elevatedY: CGFloat = 10
        static let glow = Color.black.opacity(0.4)
        static let glowRadius: CGFloat = 28
        static let glowY: CGFloat = 14
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
