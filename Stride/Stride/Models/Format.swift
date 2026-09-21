import Foundation

/// Small formatting helpers so every screen shows numbers the same way.
enum Format {
    static func steps(_ value: Int) -> String {
        value.formatted(.number.grouping(.automatic))
    }

    static func calories(_ value: Double) -> String {
        Int(value.rounded()).formatted(.number.grouping(.automatic))
    }

    static func miles(_ meters: Double, digits: Int = 2) -> String {
        let miles = meters / 1609.344
        return miles.formatted(.number.precision(.fractionLength(digits)))
    }

    static func distance(_ meters: Double) -> String {
        "\(miles(meters)) mi"
    }

    static func duration(_ seconds: TimeInterval) -> String {
        let total = Int(max(seconds, 0).rounded())
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%02d:%02d", minutes, secs)
    }

    static func shortDuration(_ seconds: TimeInterval) -> String {
        let total = Int(max(seconds, 0).rounded())
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        if hours > 0 { return "\(hours)h \(minutes)m" }
        if minutes > 0 { return "\(minutes) min" }
        return "\(total) sec"
    }

    /// Pace as minutes and seconds per mile, e.g. "17'30\"".
    static func pace(secondsPerMile: Double?) -> String {
        guard let secondsPerMile, secondsPerMile.isFinite, secondsPerMile > 0, secondsPerMile < 3600 else { return "--'--\"" }
        let minutes = Int(secondsPerMile) / 60
        let seconds = Int(secondsPerMile) % 60
        return String(format: "%d'%02d\"", minutes, seconds)
    }

    static func speedMph(metersPerSecond: Double) -> String {
        (metersPerSecond * 2.2369363).formatted(.number.precision(.fractionLength(1))) + " mph"
    }

    static func dayName(_ date: Date) -> String {
        if Calendar.current.isDateInToday(date) { return "Today" }
        if Calendar.current.isDateInYesterday(date) { return "Yesterday" }
        return date.formatted(.dateTime.weekday(.wide))
    }

    static func walkTitle(_ date: Date) -> String {
        let hour = Calendar.current.component(.hour, from: date)
        switch hour {
        case 5..<12: return "Morning Walk"
        case 12..<17: return "Afternoon Walk"
        case 17..<21: return "Evening Walk"
        default: return "Night Walk"
        }
    }

    static func dateTime(_ date: Date) -> String {
        if Calendar.current.isDateInToday(date) {
            return "Today, " + date.formatted(date: .omitted, time: .shortened)
        }
        if Calendar.current.isDateInYesterday(date) {
            return "Yesterday, " + date.formatted(date: .omitted, time: .shortened)
        }
        return date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day().hour().minute())
    }
}
