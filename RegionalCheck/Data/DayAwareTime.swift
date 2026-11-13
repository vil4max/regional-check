import Foundation

/// A time that never reads as today when it is not: the time alone on the reference's day, day and
/// abbreviated month with it on an earlier one. No year, which only lengthens the line. Shared by
/// the CarPlay "Last update" row and the phone's "Alert since" line (STATUS-reason R4).
enum DayAwareTime {
    static func text(_ date: Date, reference: Date) -> String {
        Calendar.current.isDate(date, inSameDayAs: reference)
            ? date.formatted(date: .omitted, time: .shortened)
            : date.formatted(.dateTime.day().month(.abbreviated).hour().minute())
    }
}
