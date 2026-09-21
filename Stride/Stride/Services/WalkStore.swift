import Foundation
import Combine

/// Keeps the list of saved walks in a small JSON file on the device.
@MainActor
final class WalkStore: ObservableObject {
    @Published private(set) var walks: [Walk] = []

    private let fileURL: URL
    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()
    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let folder = base.appendingPathComponent("Stride", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        fileURL = folder.appendingPathComponent("walks.json")
        load()
    }

    func add(_ walk: Walk) {
        walks.insert(walk, at: 0)
        walks.sort { $0.start > $1.start }
        persist()
    }

    func update(_ walk: Walk) {
        guard let index = walks.firstIndex(where: { $0.id == walk.id }) else { return }
        walks[index] = walk
        persist()
    }

    func delete(_ walk: Walk) {
        walks.removeAll { $0.id == walk.id }
        persist()
    }

    func walk(with id: UUID) -> Walk? {
        walks.first { $0.id == id }
    }

    // MARK: - Totals

    var totalSteps: Int { walks.reduce(0) { $0 + $1.steps } }
    var totalDistanceMeters: Double { walks.reduce(0) { $0 + $1.distanceMeters } }
    var totalCalories: Double { walks.reduce(0) { $0 + $1.calories } }
    var longestWalk: Walk? { walks.max { $0.distanceMeters < $1.distanceMeters } }

    /// Walks grouped by calendar day, newest first.
    var walksByDay: [(day: Date, walks: [Walk])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: walks) { calendar.startOfDay(for: $0.start) }
        return grouped.keys.sorted(by: >).map { (day: $0, walks: grouped[$0] ?? []) }
    }

    // MARK: - Disk

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? decoder.decode([Walk].self, from: data) else { return }
        walks = decoded.sorted { $0.start > $1.start }
    }

    private func persist() {
        guard let data = try? encoder.encode(walks) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
