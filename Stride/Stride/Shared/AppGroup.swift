import Foundation

/// How distances, speeds and weights are shown.
enum Units: String, CaseIterable, Identifiable, Codable {
    case imperial, metric

    var id: String { rawValue }

    var label: String { self == .imperial ? "Miles" : "Kilometres" }
    var distanceSuffix: String { self == .imperial ? "mi" : "km" }
    var speedSuffix: String { self == .imperial ? "mph" : "km/h" }
    var weightSuffix: String { self == .imperial ? "lb" : "kg" }
    var elevationSuffix: String { self == .imperial ? "ft" : "m" }
    var metersPerUnit: Double { self == .imperial ? 1609.344 : 1000 }
    var metersPerElevationUnit: Double { self == .imperial ? 0.3048 : 1 }
}

/// The container the app and its widgets both read, so the widget can show
/// today's numbers without opening the app.
enum AppGroup {
    static let identifier = "group.com.bishuu.stride"

    /// Falls back to the app's own defaults when the App Group is unavailable
    /// (for example when the project is signed with a free Apple ID that does
    /// not carry the capability). The app keeps working; only the widget loses
    /// its data, and it says so on its face.
    static let defaults: UserDefaults = UserDefaults(suiteName: identifier) ?? .standard

    static var isShared: Bool { UserDefaults(suiteName: identifier) != nil }

    private enum Keys {
        static let snapshot = "shared.snapshot"
        static let units = "shared.units"
    }

    static var units: Units {
        get { Units(rawValue: defaults.string(forKey: Keys.units) ?? "") ?? .imperial }
        set { defaults.set(newValue.rawValue, forKey: Keys.units) }
    }

    static func loadSnapshot() -> StrideSnapshot? {
        guard let data = defaults.data(forKey: Keys.snapshot) else { return nil }
        return try? JSONDecoder().decode(StrideSnapshot.self, from: data)
    }

    static func save(_ snapshot: StrideSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: Keys.snapshot)
    }
}
