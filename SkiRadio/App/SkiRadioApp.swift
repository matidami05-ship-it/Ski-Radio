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

enum AppTab: Hashable {
    case favorites, discover, search
}

struct ContentView: View {
    @EnvironmentObject private var library: Library
    @State private var tab: AppTab = .favorites
    @State private var pickedStartTab = false

    var body: some View {
        tabs.onAppear {
            // Open straight to Favorites once you have some; otherwise start on Discover.
            guard !pickedStartTab else { return }
            pickedStartTab = true
            if library.favorites.isEmpty { tab = .discover }
        }
    }

    private var tabs: some View {
        TabView(selection: $tab) {
            NavigationStack { FavoritesView(tab: $tab) }
                .miniPlayerInset()
                .tabItem { Label("Favorites", systemImage: "heart.fill") }
                .tag(AppTab.favorites)

            NavigationStack { DiscoverView(tab: $tab) }
                .miniPlayerInset()
                .tabItem { Label("Discover", systemImage: "dot.radiowaves.left.and.right") }
                .tag(AppTab.discover)

            NavigationStack { SearchView() }
                .miniPlayerInset()
                .tabItem { Label("Search", systemImage: "magnifyingglass") }
                .tag(AppTab.search)
        }
    }
}

private extension View {
    func miniPlayerInset() -> some View {
        safeAreaInset(edge: .bottom) { MiniPlayer() }
    }
}
