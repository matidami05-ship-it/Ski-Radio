import SwiftUI

/// Favorites as big, easy-to-tap station tiles. Edit switches to a list for reordering and deleting.
struct FavoritesView: View {
    @Binding var tab: AppTab

    @EnvironmentObject private var library: Library
    @EnvironmentObject private var player: RadioPlayer
    @State private var isEditing = false

    private let columns = [GridItem(.adaptive(minimum: 104), spacing: 14)]

    var body: some View {
        Group {
            if library.favorites.isEmpty {
                emptyState
            } else if isEditing {
                editList
            } else {
                grid
            }
        }
        .navigationTitle("Favorites")
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) { SettingsMenu() }
        }
        .toolbar {
            if !library.favorites.isEmpty {
                Button(isEditing ? "Done" : "Edit") {
                    withAnimation { isEditing.toggle() }
                }
                .fontWeight(isEditing ? .semibold : .regular)
            }
        }
        .onChange(of: library.favorites.isEmpty) { _, empty in
            if empty { isEditing = false }
        }
    }

    private var grid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 18) {
                ForEach(library.favorites) { station in
                    FavoriteTile(station: station, list: library.favorites)
                }
            }
            .padding()
        }
    }

    private var editList: some View {
        List {
            ForEach(library.favorites) { station in
                HStack(spacing: 12) {
                    StationArtwork(station: station, size: 44)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(station.displayName).font(.body.weight(.medium)).lineLimit(1)
                        Text(station.subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                }
            }
            .onDelete { library.removeFavorites(at: $0) }
            .onMove { library.moveFavorites(from: $0, to: $1) }
        }
        .listStyle(.plain)
        .environment(\.editMode, .constant(.active))
    }

    private var emptyState: some View {
        VStack(spacing: 4) {
            MessageView(symbol: "heart", title: "No favorites yet",
                        message: "Tap the heart on any station to keep it here. Favorites are also the first tab in CarPlay.")
            Button {
                tab = .discover
            } label: {
                Label("Find stations", systemImage: "dot.radiowaves.left.and.right")
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxHeight: .infinity)
    }
}

struct FavoriteTile: View {
    let station: Station
    let list: [Station]

    @EnvironmentObject private var player: RadioPlayer
    @EnvironmentObject private var library: Library

    private var isCurrent: Bool { player.station?.id == station.id }

    var body: some View {
        Button {
            if isCurrent && player.isPlaying {
                player.pause()
            } else {
                player.play(station, from: list)
            }
        } label: {
            VStack(spacing: 8) {
                ZStack(alignment: .bottomTrailing) {
                    StationArtwork(station: station, size: 104)
                        .overlay {
                            RoundedRectangle(cornerRadius: 104 * 0.22, style: .continuous)
                                .stroke(Color.orange, lineWidth: isCurrent ? 3 : 0)
                        }
                    if isCurrent {
                        Image(systemName: player.isPlaying ? "waveform" : "pause.fill")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(6)
                            .background(Color.orange, in: Circle())
                            .offset(x: 4, y: 4)
                    }
                }
                Text(station.displayName)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(isCurrent ? Color.orange : Color.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 110)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                player.play(station, from: list)
            } label: {
                Label("Play", systemImage: "play.fill")
            }
            Button(role: .destructive) {
                library.toggleFavorite(station)
            } label: {
                Label("Remove Favorite", systemImage: "heart.slash")
            }
        }
    }
}

/// Horizontal row of station tiles, used for Favorites and Recently Played on Discover.
struct StationCarousel: View {
    let stations: [Station]

    @EnvironmentObject private var player: RadioPlayer

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 14) {
                ForEach(stations) { station in
                    Button {
                        player.play(station, from: stations)
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            StationArtwork(station: station, size: 96)
                            Text(station.displayName)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(player.station?.id == station.id ? Color.orange : Color.primary)
                                .lineLimit(1)
                                .frame(width: 96, alignment: .leading)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
        }
    }
}
