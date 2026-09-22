import Foundation
import UniformTypeIdentifiers
import SwiftUI

/// Everything worth carrying to another phone, in one file.
struct StrideBackup: Codable {
    var version: Int = 1
    var exported: Date = Date()
    var walks: [Walk]
    var weightLb: Double
    var heightFeet: Int
    var heightInches: Int
    var gender: Gender
    var dailyGoal: Int
    var units: Units
}

/// A backup file the Files app (and so iCloud Drive) can hold.
struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    var data: Data

    init(data: Data) { self.data = data }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

@MainActor
enum BackupService {
    private static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        encoder.outputFormatting = .prettyPrinted
        return encoder
    }

    private static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return decoder
    }

    static func makeDocument(store: WalkStore, profile: UserProfile) -> BackupDocument? {
        let backup = StrideBackup(walks: store.walks,
                                  weightLb: profile.weightLb,
                                  heightFeet: profile.heightFeet,
                                  heightInches: profile.heightInches,
                                  gender: profile.gender,
                                  dailyGoal: profile.dailyGoal,
                                  units: profile.units)
        guard let data = try? encoder.encode(backup) else { return nil }
        return BackupDocument(data: data)
    }

    static var suggestedName: String {
        "Stride-" + Date().formatted(.iso8601.year().month().day()) + ".json"
    }

    /// Merges a backup into the app, keeping walks that are already here.
    @discardableResult
    static func restore(from url: URL, store: WalkStore, profile: UserProfile) throws -> Int {
        let needsAccess = url.startAccessingSecurityScopedResource()
        defer { if needsAccess { url.stopAccessingSecurityScopedResource() } }

        let data = try Data(contentsOf: url)
        let backup = try decoder.decode(StrideBackup.self, from: data)

        profile.weightLb = backup.weightLb
        profile.heightFeet = backup.heightFeet
        profile.heightInches = backup.heightInches
        profile.gender = backup.gender
        profile.dailyGoal = backup.dailyGoal
        profile.units = backup.units

        return store.merge(backup.walks)
    }
}
