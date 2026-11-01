import SwiftUI

struct NowPlayingView: View {
    @EnvironmentObject private var player: RadioPlayer
    @EnvironmentObject private var library: Library

    var body: some View {
        VStack(spacing: 28) {
            Spacer(minLength: 0)

            if let station = player.station {
                StationArtwork(url: station.artworkURL, size: 260)
                    .shadow(color: .black.opacity(0.25), radius: 20, y: 10)

                VStack(spacing: 8) {
                    Text(player.trackTitle ?? station.displayName)
                        .font(.title2.bold())
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                    Text(player.trackTitle == nil ? station.subtitle : station.displayName)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    statusBadge(for: station)
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

                HStack(spacing: 48) {
                    Button {
                        library.toggleFavorite(station)
                    } label: {
                        Image(systemName: library.isFavorite(station) ? "heart.fill" : "heart")
                            .font(.title2)
                            .foregroundStyle(.pink)
                    }
                    .buttonStyle(.plain)
                    RoutePicker()
                        .frame(width: 44, height: 44)
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
