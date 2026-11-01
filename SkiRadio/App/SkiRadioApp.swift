import SwiftUI

@main
struct SkiRadioApp: App {
    @StateObject private var player = RadioPlayer.shared
    @StateObject private var library = Library.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(player)
                .environmentObject(library)
                .tint(.orange)
        }
    }
}

struct ContentView: View {
    var body: some View {
        TabView {
            NavigationStack { DiscoverView() }
                .miniPlayerInset()
                .tabItem { Label("Discover", systemImage: "dot.radiowaves.left.and.right") }

            NavigationStack { SearchView() }
                .miniPlayerInset()
                .tabItem { Label("Search", systemImage: "magnifyingglass") }

            NavigationStack { FavoritesView() }
                .miniPlayerInset()
                .tabItem { Label("Favorites", systemImage: "heart.fill") }
        }
    }
}

private extension View {
    func miniPlayerInset() -> some View {
        safeAreaInset(edge: .bottom) { MiniPlayer() }
    }
}
