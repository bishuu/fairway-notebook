import Foundation

/// Small formatting helpers so every screen shows numbers the same way.
/// Distances and speeds follow the unit chosen in Profile.
enum Format {
    static var units: Units { AppGroup.units }

    static func steps(_ value: Int) -> String {
        value.formatted(.number.grouping(.automatic))
    }

    static func calories(_ value: Double) -> String {
        Int(value.rounded()).formatted(.number.grouping(.automatic))
    }

    /// Distance as a bare number in the chosen unit.
    static func distanceValue(_ meters: Double, digits: Int = 2) -> String {
        let value = meters / units.metersPerUnit
        return value.formatted(.number.precision(.fractionLength(digits)))
    }

    /// Distance with its unit, e.g. "2.41 mi".
    static func distance(_ meters: Double, digits: Int = 2) -> String {
        "\(distanceValue(meters, digits: digits)) \(units.distanceSuffix)"
    }

    static func elevation(_ meters: Double) -> String {
        let value = meters / units.metersPerElevationUnit
        return "\(Int(value.rounded())) \(units.elevationSuffix)"
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

    /// Pace in minutes and seconds per mile or kilometre, e.g. "17'30\"".
    static func pace(secondsPerMeter: Double?) -> String {
        guard let secondsPerMeter, secondsPerMeter.isFinite, secondsPerMeter > 0 else { return "--'--\"" }
        let perUnit = secondsPerMeter * units.metersPerUnit
        guard perUnit > 0, perUnit < 5400 else { return "--'--\"" }
        let minutes = Int(perUnit) / 60
        let seconds = Int(perUnit) % 60
        return String(format: "%d'%02d\"", minutes, seconds)
    }

    static func speed(metersPerSecond: Double) -> String {
        let value = metersPerSecond / units.metersPerUnit * 3600
        return value.formatted(.number.precision(.fractionLength(1))) + " " + units.speedSuffix
    }

    static func heartRate(_ bpm: Double?) -> String {
        guard let bpm, bpm > 0 else { return "--" }
        return "\(Int(bpm.rounded()))"
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

    /// Weight shown in the chosen unit (stored canonically in pounds).
    static func weight(fromPounds pounds: Double) -> String {
        if units == .metric {
            return (pounds * 0.45359237).formatted(.number.precision(.fractionLength(1))) + " kg"
        }
        return pounds.formatted(.number.precision(.fractionLength(0))) + " lb"
    }
}
