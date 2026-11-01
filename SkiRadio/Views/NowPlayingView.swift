import SwiftUI

struct NowPlayingView: View {
    @EnvironmentObject private var player: RadioPlayer
    @EnvironmentObject private var library: Library
    @ObservedObject private var equalizer = Equalizer.shared
    @State private var showEqualizer = false

    var body: some View {
        VStack(spacing: 28) {
            Spacer(minLength: 0)

            if let station = player.station {
                NowPlayingArtwork(station: station, albumArt: player.albumArt, size: 280)
                    .shadow(color: .black.opacity(0.25), radius: 20, y: 10)

                VStack(spacing: 6) {
                    if let song = player.song {
                        Text(song.title)
                            .font(.title2.bold())
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                        if let artist = song.artist {
                            Text(artist)
                                .font(.title3)
                                .foregroundStyle(.orange)
                                .lineLimit(1)
                        }
                        Text(station.displayName)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    } else {
                        Text(station.displayName)
                            .font(.title2.bold())
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                        Text(station.subtitle)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    statusBadge(for: station)
                        .padding(.top, 2)
                }
                .padding(.horizontal)

                HStack(spacing: 48) {
                    Button { player.previous() } label: {
                        Image(systemName: "backward.fill").font(.title)
                    }
                    PlayPauseButton(size: 34)
                    Button { player.next() } label: {
                        Image(systemName: "forward.fill").font(.title)
                    }
                }
                .buttonStyle(.plain)

                HStack(spacing: 36) {
                    Button {
                        library.toggleFavorite(station)
                    } label: {
                        Image(systemName: library.isFavorite(station) ? "heart.fill" : "heart")
                            .font(.title2)
                            .foregroundStyle(.pink)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Favorite")

                    Button {
                        showEqualizer = true
                    } label: {
                        Image(systemName: "slider.vertical.3")
                            .font(.title2)
                            .foregroundStyle(equalizer.enabled ? Color.orange : Color.primary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Equalizer")

                    SleepTimerButton()

                    RoutePicker()
                        .frame(width: 44, height: 44)
                }
                .sheet(isPresented: $showEqualizer) {
                    NavigationStack {
                        EqualizerView()
                            .toolbar {
                                ToolbarItem(placement: .confirmationAction) {
                                    Button("Done") { showEqualizer = false }
                                }
                            }
                    }
                    .presentationDetents([.medium, .large])
                }
            } else {
                MessageView(symbol: "radio", title: "Nothing playing")
            }

            Spacer(minLength: 0)
        }
        .padding()
        .presentationDragIndicator(.visible)
    }

    @ViewBuilder
    private func statusBadge(for station: Station) -> some View {
        switch player.status {
        case .loading:
            Text("Connecting…").font(.caption).foregroundStyle(.secondary)
        case .failed(let message):
            Text(message).font(.caption).foregroundStyle(.red).multilineTextAlignment(.center)
        case .playing:
            HStack(spacing: 6) {
                Text("LIVE")
                    .font(.caption2.weight(.heavy))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.red, in: Capsule())
                    .foregroundStyle(.white)
                if let quality = station.qualityLabel {
                    Text(quality).font(.caption).foregroundStyle(.secondary)
                }
            }
        default:
            EmptyView()
        }
    }
}
