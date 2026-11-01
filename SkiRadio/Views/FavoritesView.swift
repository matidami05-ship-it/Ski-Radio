import SwiftUI

struct FavoritesView: View {
    @EnvironmentObject private var library: Library

    var body: some View {
        List {
            ForEach(library.favorites) { station in
                StationRow(station: station, list: library.favorites)
            }
            .onDelete { library.removeFavorites(at: $0) }
            .onMove { library.moveFavorites(from: $0, to: $1) }
        }
        .listStyle(.plain)
        .overlay {
            if library.favorites.isEmpty {
                MessageView(symbol: "heart", title: "No favorites yet",
                            message: "Tap the heart on any station. Your favorites are the first tab in CarPlay.")
            }
        }
        .navigationTitle("Favorites")
        .toolbar {
            if !library.favorites.isEmpty {
                EditButton()
            }
        }
    }
}
