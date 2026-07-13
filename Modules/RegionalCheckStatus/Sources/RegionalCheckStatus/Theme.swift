import SwiftUI

public enum Theme {
    public enum Colors {
        public static let normal = Color(red: 0.45, green: 0.62, blue: 0.52)
        public static let attention = Color(red: 0.78, green: 0.58, blue: 0.38)
        public static let checking = Color(red: 0.55, green: 0.57, blue: 0.60)
        public static let unavailable = Color(red: 0.52, green: 0.54, blue: 0.58)
        public static let onFill = Color.white.opacity(0.92)
        public static let onFillSecondary = Color.white.opacity(0.72)
    }

    public enum Typography {
        public static let stateTitle = Font.system(.largeTitle, design: .default).weight(.semibold)
        public static let regionTitle = Font.system(.title2, design: .default).weight(.regular)
        public static let caption = Font.system(.subheadline, design: .default).weight(.regular)
        public static let symbol = Font.system(size: 56, weight: .regular)
    }

    public enum Spacing {
        public static let xs: CGFloat = 8
        public static let sm: CGFloat = 12
        public static let md: CGFloat = 16
        public static let lg: CGFloat = 24
        public static let xl: CGFloat = 32
    }

    public enum CornerRadius {
        public static let control: CGFloat = 24
    }
}
