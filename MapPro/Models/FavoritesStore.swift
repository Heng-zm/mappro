import Foundation
import Combine

/// Persists saved places and dropped pins as JSON in `UserDefaults`.
final class FavoritesStore: ObservableObject {
    @Published private(set) var places: [SavedPlace] = []

    private let defaults: UserDefaults
    private let storageKey = "com.hengzm.mappro.savedPlaces.v1"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
    }

    var isEmpty: Bool {
        places.isEmpty
    }

    var count: Int {
        places.count
    }

    func isSaved(_ place: Place) -> Bool {
        places.contains { $0.id == place.id }
    }

    /// Returns `true` when the place was added, `false` when it was removed.
    @discardableResult
    func toggle(_ place: Place) -> Bool {
        if let index = places.firstIndex(where: { $0.id == place.id }) {
            places.remove(at: index)
            persist()
            return false
        }

        places.insert(SavedPlace(place: place), at: 0)
        persist()
        return true
    }

    func remove(_ saved: SavedPlace) {
        places.removeAll { $0.id == saved.id }
        persist()
    }

    func removeAll() {
        guard !places.isEmpty else { return }
        places.removeAll()
        persist()
    }

    // MARK: - Storage

    private func load() {
        guard let data = defaults.data(forKey: storageKey) else { return }
        guard let decoded = try? decoder.decode([SavedPlace].self, from: data) else { return }
        places = decoded.sorted { $0.savedAt > $1.savedAt }
    }

    private func persist() {
        guard let data = try? encoder.encode(places) else { return }
        defaults.set(data, forKey: storageKey)
    }
}
