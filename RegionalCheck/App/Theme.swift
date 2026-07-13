import SwiftUI

enum Theme {
    enum Colors {
        static let normal = Color("Normal")
        static let attention = Color(red: 0.78, green: 0.58, blue: 0.38)
        static let checking = Color(red: 0.55, green: 0.57, blue: 0.60)
        static let unavailable = Color(red: 0.52, green: 0.54, blue: 0.58)
        static let onFill = Color.white.opacity(0.92)
        static let onFillSecondary = Color.white.opacity(0.72)
    }

    enum Typography {
        static let stateTitle = Font.system(.largeTitle, design: .default).weight(.semibold)
        static let regionTitle = Font.system(.title2, design: .default).weight(.regular)
        static let caption = Font.system(.subheadline, design: .default).weight(.regular)
        static let symbol = Font.system(size: 56, weight: .regular)
        static let refreshSymbol = Font.system(size: 18, weight: .semibold)
    }

    enum Spacing {
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let refreshControl: CGFloat = 52
    }
}
