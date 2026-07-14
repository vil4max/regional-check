import SwiftUI

enum Theme {
    enum Colors {
        static let normal = Color("Normal")
        static let attention = Color(red: 0.88, green: 0.48, blue: 0.48)
        static let checking = Color(red: 0.55, green: 0.57, blue: 0.60)
        static let unavailable = Color("Unavailable")
        static let onFill = Color.white.opacity(0.92)
        static let onFillSecondary = Color.white.opacity(0.72)

        static func statusGradient(for state: StatusState) -> LinearGradient {
            let base: Color
            switch state {
            case .alarm:
                base = attention
            case .quiet:
                base = normal
            case .idle:
                base = checking
            case .error:
                base = unavailable
            }

            return LinearGradient(
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
        static let regionTitle = Font.system(.title, design: .rounded).weight(.medium)
        static let caption = Font.system(.footnote, design: .rounded).weight(.regular)
        static let refreshLabel = Font.system(.caption, design: .rounded).weight(.semibold)
        static let symbol = Font.system(size: 68, weight: .medium)
        static let refreshSymbol = Font.system(size: 20, weight: .semibold)
    }

    enum Spacing {
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let refreshControl: CGFloat = 56
    }

    enum Motion {
        static let stateSpring = Animation.spring(response: 0.45, dampingFraction: 0.82)
        static let quietFade = Animation.easeInOut(duration: 0.9)
        static let loudPulse = Animation.easeInOut(duration: 1.15).repeatForever(autoreverses: true)
    }
}
