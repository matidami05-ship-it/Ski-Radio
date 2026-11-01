import SwiftUI

/// Favorites and recently played stations, saved on the device and shared by the phone and CarPlay.
@MainActor
final class Library: ObservableObject {
    static let shared = Library()

    private enum Keys {
        static let favorites = "library.favorites"
        static let recents = "library.recents"
    }

    private let maxRecents = 20

    @Published private(set) var favorites: [Station] = [] {
        didSet { save(favorites, key: Keys.favorites) }
    }

    @Published private(set) var recents: [Station] = [] {
        didSet { save(recents, key: Keys.recents) }
    }

    private init() {
        favorites = load(key: Keys.favorites)
        recents = load(key: Keys.recents)
    }

    func isFavorite(_ station: Station) -> Bool {
        favorites.contains { $0.id == station.id }
    }

    func toggleFavorite(_ station: Station) {
        if isFavorite(station) {
            favorites.removeAll { $0.id == station.id }
        } else {
            favorites.append(station)
        }
    }

    func removeFavorites(at offsets: IndexSet) {
        favorites.remove(atOffsets: offsets)
    }

    func moveFavorites(from source: IndexSet, to destination: Int) {
        favorites.move(fromOffsets: source, toOffset: destination)
    }

    func clearRecents() {
        recents = []
    }

    func addRecent(_ station: Station) {
        var updated = recents.filter { $0.id != station.id }
        updated.insert(station, at: 0)
        recents = Array(updated.prefix(maxRecents))
    }

    // MARK: - Storage

    private func save(_ stations: [Station], key: String) {
        guard let data = try? JSONEncoder().encode(stations) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    private func load(key: String) -> [Station] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let stations = try? JSONDecoder().decode([Station].self, from: data) else { return [] }
        return stations
    }
}
