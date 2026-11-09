import SwiftUI

enum BrowseDestination: Hashable {
    case genre(Genre)
    case topWorldwide
    case polish
}

struct DiscoverView: View {
    @Binding var tab: AppTab

    @EnvironmentObject private var library: Library
    @EnvironmentObject private var player: RadioPlayer

    @State private var popular: [Station] = []
    @State private var phase: LoadPhase = .loading

    private let regionCode = Locale.current.region?.identifier ?? "US"
    private var regionName: String {
        Locale.current.localizedString(forRegionCode: regionCode) ?? regionCode
    }
    private let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                if !library.favorites.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Your Favorites").font(.title3.bold())
                            Spacer()
                            Button("See All") { tab = .favorites }
                                .font(.subheadline.weight(.semibold))
                        }
                        .padding(.horizontal)
                        StationCarousel(stations: library.favorites)
                    }
                }

                if !library.recents.isEmpty {
                    section("Recently Played") {
                        StationCarousel(stations: library.recents)
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("🇵🇱 Polish Radio").font(.title3.bold())
                        Spacer()
                        NavigationLink("See All", value: BrowseDestination.polish)
                            .font(.subheadline.weight(.semibold))
                    }
                    .padding(.horizontal)
                    StationCarousel(stations: BuiltInStations.all)
                }

                section("Genres") {
                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(Genre.all) { genre in
                            NavigationLink(value: BrowseDestination.genre(genre)) {
                                GenreTile(genre: genre)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                }

                section("Popular in \(regionName)") {
                    popularContent
                }

                NavigationLink(value: BrowseDestination.topWorldwide) {
                    Label("Top stations worldwide", systemImage: "globe")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .navigationTitle("Ski Radio")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) { SettingsMenu() }
        }
        .navigationDestination(for: BrowseDestination.self) { destination in
            switch destination {
            case .genre(let genre):
                StationListView(title: genre.name) {
                    try await RadioBrowser.shared.stations(tag: genre.tag)
                }
            case .topWorldwide:
                StationListView(title: "Top Worldwide") {
                    try await RadioBrowser.shared.topStations()
                }
            case .polish:
                StationListView(title: "Polish Radio") {
                    try await RadioBrowser.shared.polishStations()
                }
            }
        }
        .refreshable { await loadPopular() }
        .task {
            if popular.isEmpty { await loadPopular() }
        }
    }

    @ViewBuilder
    private var popularContent: some View {
        switch phase {
        case .loading:
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
        case .failed(let message):
            MessageView(symbol: "wifi.exclamationmark", title: "Couldn't load stations", message: message) {
                Task { await loadPopular() }
            }
        case .loaded:
            LazyVStack(spacing: 0) {
                ForEach(popular.prefix(25)) { station in
                    StationRow(station: station, list: Array(popular.prefix(25)))
                        .padding(.horizontal)
                        .padding(.vertical, 6)
                    Divider().padding(.leading, 76)
                }
            }
        }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.title3.bold())
                .padding(.horizontal)
            content()
        }
    }

    private func loadPopular() async {
        if popular.isEmpty { phase = .loading }
        do {
            popular = try await RadioBrowser.shared.stations(countryCode: regionCode)
            phase = .loaded
        } catch {
            if popular.isEmpty { phase = .failed(error.localizedDescription) }
        }
    }
}

struct GenreTile: View {
    let genre: Genre

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: genre.symbol)
                .font(.title3)
            Text(genre.name)
                .font(.subheadline.weight(.semibold))
            Spacer(minLength: 0)
        }
        .foregroundStyle(.white)
        .padding(14)
        .frame(height: 56)
        .background(genre.color.gradient, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

struct StationListView: View {
    let title: String
    let load: () async throws -> [Station]

    @State private var stations: [Station] = []
    @State private var phase: LoadPhase = .loading

    var body: some View {
        Group {
            switch phase {
            case .loading:
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .failed(let message):
                MessageView(symbol: "wifi.exclamationmark", title: "Couldn't load stations", message: message) {
                    Task { await reload() }
                }
                .frame(maxHeight: .infinity)
            case .loaded:
                if stations.isEmpty {
                    MessageView(symbol: "radio", title: "No stations found")
                        .frame(maxHeight: .infinity)
                } else {
                    List(stations) { station in
                        StationRow(station: station, list: stations)
                    }
                    .listStyle(.plain)
                    .refreshable { await reload() }
                }
            }
        }
        .navigationTitle(title)
        .task {
            if stations.isEmpty { await reload() }
        }
    }

    private func reload() async {
        if stations.isEmpty { phase = .loading }
        do {
            stations = try await load()
            phase = .loaded
        } catch {
            if stations.isEmpty { phase = .failed(error.localizedDescription) }
        }
    }
}
