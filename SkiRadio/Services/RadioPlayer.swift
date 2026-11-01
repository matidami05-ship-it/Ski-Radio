import AVFoundation
import MediaPlayer
import UIKit

/// Plays live streams in the background and drives the lock screen, Control Center and CarPlay Now Playing.
@MainActor
final class RadioPlayer: NSObject, ObservableObject {
    enum Status: Equatable {
        case idle
        case loading
        case playing
        case paused
        case failed(String)
    }

    static let shared = RadioPlayer()

    @Published private(set) var station: Station?
    @Published private(set) var status: Status = .idle
    @Published private(set) var trackTitle: String?
    @Published private(set) var artwork: UIImage?

    /// The list the current station was started from; next/previous move through it.
    private(set) var queue: [Station] = []

    private let player = AVPlayer()
    private var itemStatusObservation: NSKeyValueObservation?
    private var timeControlObservation: NSKeyValueObservation?
    private var interruptionObserver: NSObjectProtocol?
    private var artworkTask: Task<Void, Never>?
    private var resumeAfterInterruption = false

    var isPlaying: Bool { status == .playing || status == .loading }

    private override init() {
        super.init()
        player.automaticallyWaitsToMinimizeStalling = true
        configureRemoteCommands()
        observePlayer()
        observeInterruptions()
    }

    // MARK: - Playback

    func play(_ station: Station, from list: [Station]? = nil) {
        if let list, !list.isEmpty {
            queue = list
        } else if !queue.contains(where: { $0.id == station.id }) {
            queue = [station]
        }

        let isNewStation = self.station?.id != station.id
        self.station = station
        if isNewStation {
            trackTitle = nil
            loadArtwork(for: station)
        }

        guard let url = station.streamURL else {
            status = .failed("This station has no stream.")
            updateNowPlaying()
            return
        }

        status = .loading
        activateAudioSession()

        let item = AVPlayerItem(url: url)
        let metadataOutput = AVPlayerItemMetadataOutput(identifiers: nil)
        metadataOutput.setDelegate(self, queue: .main)
        item.add(metadataOutput)

        itemStatusObservation = item.observe(\.status, options: [.new]) { [weak self] item, _ in
            let failed = item.status == .failed
            let message = item.error?.localizedDescription
            Task { @MainActor [weak self] in
                guard let self, failed, self.player.currentItem === item else { return }
                self.status = .failed(message ?? "Couldn't play this station.")
                self.updateNowPlaying()
            }
        }

        player.replaceCurrentItem(with: item)
        player.play()

        Library.shared.addRecent(station)
        updateNowPlaying()
        Task { await RadioBrowser.shared.registerClick(station) }
    }

    func togglePlayPause() {
        isPlaying ? pause() : resume()
    }

    func pause() {
        guard station != nil else { return }
        player.pause()
        status = .paused
        updateNowPlaying()
    }

    /// Live radio reconnects on resume so you hear what's on now, not what was buffered.
    func resume() {
        guard let station else { return }
        play(station)
    }

    func next() { step(by: 1) }
    func previous() { step(by: -1) }

    private func step(by offset: Int) {
        guard let station,
              queue.count > 1,
              let index = queue.firstIndex(where: { $0.id == station.id }) else { return }
        let nextIndex = (index + offset + queue.count) % queue.count
        play(queue[nextIndex])
    }

    // MARK: - Setup

    private func activateAudioSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default, options: [])
        try? session.setActive(true)
    }

    private func observePlayer() {
        timeControlObservation = player.observe(\.timeControlStatus, options: [.new]) { [weak self] player, _ in
            let control = player.timeControlStatus
            Task { @MainActor [weak self] in
                guard let self else { return }
                switch control {
                case .playing:
                    self.status = .playing
                case .waitingToPlayAtSpecifiedRate:
                    if self.status == .playing { self.status = .loading }
                default:
                    break
                }
                self.updateNowPlaying()
            }
        }
    }

    private func observeInterruptions() {
        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] note in
            guard let info = note.userInfo,
                  let rawType = info[AVAudioSessionInterruptionTypeKey] as? UInt,
                  let type = AVAudioSession.InterruptionType(rawValue: rawType) else { return }
            let rawOptions = info[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
            let shouldResume = AVAudioSession.InterruptionOptions(rawValue: rawOptions).contains(.shouldResume)
            Task { @MainActor [weak self] in
                self?.handleInterruption(type, shouldResume: shouldResume)
            }
        }
    }

    private func handleInterruption(_ type: AVAudioSession.InterruptionType, shouldResume: Bool) {
        switch type {
        case .began:
            resumeAfterInterruption = isPlaying
            if isPlaying { pause() }
        case .ended:
            if resumeAfterInterruption && shouldResume { resume() }
            resumeAfterInterruption = false
        @unknown default:
            break
        }
    }

    private func configureRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()

        center.playCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in self?.resume() }
            return .success
        }
        center.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in self?.pause() }
            return .success
        }
        center.stopCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in self?.pause() }
            return .success
        }
        center.togglePlayPauseCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in self?.togglePlayPause() }
            return .success
        }
        center.nextTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in self?.next() }
            return .success
        }
        center.previousTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in self?.previous() }
            return .success
        }

        // Live streams can't seek.
        center.skipForwardCommand.isEnabled = false
        center.skipBackwardCommand.isEnabled = false
        center.changePlaybackPositionCommand.isEnabled = false
        center.seekForwardCommand.isEnabled = false
        center.seekBackwardCommand.isEnabled = false
    }

    // MARK: - Now Playing

    private func loadArtwork(for station: Station) {
        artworkTask?.cancel()
        artwork = nil
        artworkTask = Task { [weak self] in
            let image = await ImageCache.shared.image(for: station.artworkURL)
            guard !Task.isCancelled, let self, self.station?.id == station.id else { return }
            self.artwork = image
            self.updateNowPlaying()
        }
    }

    private func updateNowPlaying() {
        guard let station else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            return
        }

        var info: [String: Any] = [
            MPMediaItemPropertyTitle: trackTitle ?? station.displayName,
            MPMediaItemPropertyArtist: trackTitle == nil ? station.subtitle : station.displayName,
            MPNowPlayingInfoPropertyIsLiveStream: true,
            MPNowPlayingInfoPropertyMediaType: MPNowPlayingInfoMediaType.audio.rawValue,
            MPNowPlayingInfoPropertyPlaybackRate: status == .playing ? 1.0 : 0.0,
        ]
        if let artwork {
            info[MPMediaItemPropertyArtwork] = Self.makeArtwork(artwork)
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    /// Built outside the main actor because the system calls the artwork closure on a background thread.
    nonisolated private static func makeArtwork(_ image: UIImage) -> MPMediaItemArtwork {
        MPMediaItemArtwork(boundsSize: image.size) { _ in image }
    }

    nonisolated fileprivate static func cleanTitle(_ raw: String) -> String? {
        let title = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let junk: Set<String> = ["", "-", " - ", "unknown", "advert", "advertisement"]
        return junk.contains(title.lowercased()) ? nil : title
    }
}

// MARK: - Song titles from the stream (ICY metadata)

extension RadioPlayer: AVPlayerItemMetadataOutputPushDelegate {
    nonisolated func metadataOutput(
        _ output: AVPlayerItemMetadataOutput,
        didOutputTimedMetadataGroups groups: [AVTimedMetadataGroup],
        from track: AVPlayerItemTrack?
    ) {
        let items = groups.flatMap { $0.items }
        let preferred = items.filter {
            $0.identifier == .icyMetadataStreamTitle || $0.commonKey == .commonKeyTitle
        }
        let candidates = preferred.isEmpty ? items : preferred

        Task { @MainActor [weak self] in
            for item in candidates {
                guard let value = try? await item.load(.stringValue),
                      let title = RadioPlayer.cleanTitle(value) else { continue }
                self?.trackTitle = title
                self?.updateNowPlaying()
                return
            }
        }
    }
}
