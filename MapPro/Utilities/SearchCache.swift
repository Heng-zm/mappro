import Foundation

struct CachedSearch: Codable {
    let query: String
    let savedAt: Date
    let places: [SavedPlace]
}

/// Stores the latest successful searches so offline mode can still show results.
final class SearchCache {
    static let shared = SearchCache()

    private let storageKey = "com.hengzm.mappro.searchCache.v1"
    private let maxEntries = 8
    private let defaults = UserDefaults.standard
    private(set) var entries: [CachedSearch] = []

    private init() {
        load()
    }

    func save(query: String, places: [Place]) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !places.isEmpty else { return }

        let entry = CachedSearch(
            query: trimmed,
            savedAt: Date(),
            places: places.map { SavedPlace(place: $0) }
        )

        entries.removeAll { $0.query.caseInsensitiveCompare(trimmed) == .orderedSame }
        entries.insert(entry, at: 0)
        if entries.count > maxEntries {
            entries = Array(entries.prefix(maxEntries))
        }
        persist()
    }

    func results(for query: String) -> [Place] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        let match = entries.first { $0.query.caseInsensitiveCompare(trimmed) == .orderedSame }
            ?? entries.first {
                $0.query.localizedCaseInsensitiveContains(trimmed)
                    || trimmed.localizedCaseInsensitiveContains($0.query)
            }

        return match?.places.map { $0.place } ?? []
    }

    private func load() {
        guard let data = defaults.data(forKey: storageKey) else { return }
        guard let decoded = try? JSONDecoder().decode([CachedSearch].self, from: data) else { return }
        entries = decoded.sorted { $0.savedAt > $1.savedAt }
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        defaults.set(data, forKey: storageKey)
    }
}
