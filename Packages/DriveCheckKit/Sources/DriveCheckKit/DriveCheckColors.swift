import SwiftUI

public enum DriveCheckColors {
    public static let background = Color(red: 0.047, green: 0.055, blue: 0.067)  // #0C0E11
    public static let statusClear = Color(red: 0.486, green: 0.765, blue: 0.608)  // #7CC39B
    public static let statusAlert = Color(red: 0.941, green: 0.486, blue: 0.486)  // #F07C7C
    public static let statusStale = Color(red: 0.910, green: 0.729, blue: 0.384)  // #E8BA62
    public static let statusChecking = Color(red: 0.604, green: 0.627, blue: 0.659)  // #9AA0A8
    /// Old or missing data stays neutral; yellow means caution about current alerts.
    public static let statusNoData = Color(red: 0.776, green: 0.792, blue: 0.816)  // #C6CAD0
    public static let textPrimary = Color(red: 0.949, green: 0.953, blue: 0.961)  // #F2F3F5
    public static let textSecondary = Color(red: 0.639, green: 0.655, blue: 0.682)  // #A3A7AE
    /// Decorative only; never used for a status-bearing element.
    public static let proAccent = Color(red: 0.918, green: 0.843, blue: 0.690)  // #EAD7B0
}
