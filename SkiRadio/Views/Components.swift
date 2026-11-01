import AVKit
import SwiftUI

/// Station logo, falling back to a colored initials tile when there's no logo or it fails to load.
struct StationArtwork: View {
    let station: Station
    var size: CGFloat = 48

    var body: some View {
        AsyncImage(url: station.artworkURL) { phase in
            if let image = phase.image {
                image
                    .resizable()
                    .scaledToFit()
                    .padding(size * 0.08)
                    .frame(width: size, height: size)
                    .background(Color(.secondarySystemBackground))
            } else {
                monogram
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
    }

    private var monogram: some View {
        let color = Color(Monogram.color(for: station.displayName))
        return ZStack {
            LinearGradient(colors: [color.opacity(0.75), color], startPoint: .topLeading, endPoint: .bottomTrailing)
            Text(Monogram.initials(for: station.displayName))
                .font(.system(size: size * 0.36, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .padding(size * 0.08)
        }
    }
}

/// Square cover art for the song on air, with the station logo as a fallback.
struct NowPlayingArtwork: View {
    let station: Station
    let albumArt: UIImage?
    var size: CGFloat = 260

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            if let albumArt {
                Image(uiImage: albumArt)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(RoundedRectangle(cornerRadius: size * 0.08, style: .continuous))
                    .transition(.opacity)
                // Small station logo badge so you still know what's playing.
                StationArtwork(station: station, size: size * 0.24)
                    .overlay {
                        RoundedRectangle(cornerRadius: size * 0.24 * 0.22, style: .continuous)
                            .stroke(Color(.systemBackground), lineWidth: 3)
                    }
                    .offset(x: 8, y: 8)
            } else {
                StationArtwork(station: station, size: size)
            }
        }
        .animation(.easeInOut(duration: 0.4), value: albumArt)
    }
}

struct StationRow: View {
    let station: Station
    let list: [Station]

    @EnvironmentObject private var player: RadioPlayer
    @EnvironmentObject private var library: Library

    private var isCurrent: Bool { player.station?.id == station.id }
    private var isFavorite: Bool { library.isFavorite(station) }

    var body: some View {
        HStack(spacing: 12) {
            Button {
                player.play(station, from: list)
            } label: {
                HStack(spacing: 12) {
                    StationArtwork(station: station, size: 48)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(station.displayName)
                            .font(.body.weight(.medium))
                            .foregroundStyle(isCurrent ? Color.orange : Color.primary)
                            .lineLimit(1)
                        Text(station.subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 4)
                    if isCurrent && player.isPlaying {
                        Image(systemName: "waveform")
                            .foregroundStyle(.orange)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)

            Button {
                library.toggleFavorite(station)
            } label: {
                Image(systemName: isFavorite ? "heart.fill" : "heart")
                    .foregroundStyle(isFavorite ? Color.pink : Color.secondary)
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(isFavorite ? "Remove from favorites" : "Add to favorites")
        }
        .contextMenu {
            Button {
                player.play(station, from: list)
            } label: {
                Label("Play", systemImage: "play.fill")
            }
            Button {
                library.toggleFavorite(station)
            } label: {
                Label(isFavorite ? "Remove Favorite" : "Favorite", systemImage: isFavorite ? "heart.slash" : "heart")
            }
        }
    }
}

struct PlayPauseButton: View {
    @EnvironmentObject private var player: RadioPlayer
    var size: CGFloat = 22

    var body: some View {
        Button {
            player.togglePlayPause()
        } label: {
            ZStack {
                if player.status == .loading {
                    ProgressView()
                } else {
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: size, weight: .bold))
                }
            }
            .frame(width: size * 1.8, height: size * 1.8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(player.isPlaying ? "Pause" : "Play")
    }
}

struct MiniPlayer: View {
    @EnvironmentObject private var player: RadioPlayer
    @State private var showNowPlaying = false

    var body: some View {
        if let station = player.station {
            HStack(spacing: 12) {
                Group {
                    if let albumArt = player.albumArt {
                        Image(uiImage: albumArt)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 44, height: 44)
                            .clipShape(RoundedRectangle(cornerRadius: 44 * 0.22, style: .continuous))
                    } else {
                        StationArtwork(station: station, size: 44)
                    }
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(station.displayName)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    Text(statusLine(for: station))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                PlayPauseButton(size: 20)
            }
            .padding(10)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .padding(.horizontal, 10)
            .padding(.bottom, 6)
            .contentShape(Rectangle())
            .onTapGesture { showNowPlaying = true }
            .sheet(isPresented: $showNowPlaying) { NowPlayingView() }
        }
    }

    private func statusLine(for station: Station) -> String {
        switch player.status {
        case .loading: return "Connecting…"
        case .failed(let message): return message
        default: return player.trackTitle ?? station.subtitle
        }
    }
}

struct MessageView: View {
    let symbol: String
    let title: String
    var message: String? = nil
    var retry: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.headline)
            if let message {
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            if let retry {
                Button("Try Again", action: retry)
                    .buttonStyle(.bordered)
                    .padding(.top, 4)
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity)
    }
}

/// Gear button that opens Settings.
struct SettingsMenu: View {
    @State private var showSettings = false

    var body: some View {
        Button {
            showSettings = true
        } label: {
            Image(systemName: "gearshape")
        }
        .accessibilityLabel("Settings")
        .sheet(isPresented: $showSettings) { SettingsView() }
    }
}

/// AirPlay / Bluetooth output picker.
struct RoutePicker: UIViewRepresentable {
    func makeUIView(context: Context) -> AVRoutePickerView {
        let view = AVRoutePickerView()
        view.activeTintColor = .systemOrange
        view.tintColor = .label
        view.prioritizesVideoDevices = false
        return view
    }

    func updateUIView(_ uiView: AVRoutePickerView, context: Context) {}
}
