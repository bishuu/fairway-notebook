import Foundation
import Combine

enum Gender: String, CaseIterable, Identifiable, Codable {
    case male, female, other

    var id: String { rawValue }

    var label: String {
        switch self {
        case .male: return "Male"
        case .female: return "Female"
        case .other: return "Other"
        }
    }

    /// Average stride length as a fraction of height.
    var strideFactor: Double {
        switch self {
        case .male: return 0.415
        case .female: return 0.413
        case .other: return 0.414
        }
    }

    /// Small adjustment to walking energy cost for typical body composition.
    var energyFactor: Double {
        switch self {
        case .male: return 1.0
        case .female: return 0.95
        case .other: return 0.975
        }
    }
}

/// A plain-value snapshot of the body inputs, safe to pass anywhere.
struct BodyStats: Hashable {
    var weightLb: Double
    var heightFeet: Int
    var heightInches: Int
    var gender: Gender

    var weightKg: Double { weightLb * 0.45359237 }
    var heightMeters: Double { Double(heightFeet * 12 + heightInches) * 0.0254 }
    var strideMeters: Double { heightMeters * gender.strideFactor }
}

/// The user's body inputs and daily goal. Saved on the device automatically.
@MainActor
final class UserProfile: ObservableObject {
    private enum Keys {
        static let weightLb = "profile.weightLb"
        static let heightFeet = "profile.heightFeet"
        static let heightInches = "profile.heightInches"
        static let gender = "profile.gender"
        static let dailyGoal = "profile.dailyGoal"
        static let hasOnboarded = "profile.hasOnboarded"
    }

    @Published var weightLb: Double { didSet { save() } }
    @Published var heightFeet: Int { didSet { save() } }
    @Published var heightInches: Int { didSet { save() } }
    @Published var gender: Gender { didSet { save() } }
    @Published var dailyGoal: Int { didSet { save() } }
    @Published var hasOnboarded: Bool { didSet { save() } }

    private let defaults = UserDefaults.standard

    init() {
        let storedWeight = defaults.double(forKey: Keys.weightLb)
        weightLb = storedWeight > 0 ? storedWeight : 160
        let storedFeet = defaults.integer(forKey: Keys.heightFeet)
        heightFeet = storedFeet > 0 ? storedFeet : 5
        heightInches = defaults.object(forKey: Keys.heightInches) == nil ? 8 : defaults.integer(forKey: Keys.heightInches)
        gender = Gender(rawValue: defaults.string(forKey: Keys.gender) ?? "") ?? .other
        let storedGoal = defaults.integer(forKey: Keys.dailyGoal)
        dailyGoal = storedGoal > 0 ? storedGoal : 10_000
        hasOnboarded = defaults.bool(forKey: Keys.hasOnboarded)
    }

    var body: BodyStats {
        BodyStats(weightLb: weightLb, heightFeet: heightFeet, heightInches: heightInches, gender: gender)
    }

    var heightLabel: String { "\(heightFeet)′ \(heightInches)″" }

    private func save() {
        defaults.set(weightLb, forKey: Keys.weightLb)
        defaults.set(heightFeet, forKey: Keys.heightFeet)
        defaults.set(heightInches, forKey: Keys.heightInches)
        defaults.set(gender.rawValue, forKey: Keys.gender)
        defaults.set(dailyGoal, forKey: Keys.dailyGoal)
        defaults.set(hasOnboarded, forKey: Keys.hasOnboarded)
    }
}
