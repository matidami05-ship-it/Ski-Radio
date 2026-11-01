import AppIntents

/// "Play Last Station" for Shortcuts and Siri. Plays in the background without opening the app,
/// so a Shortcuts automation can start the radio when a Bluetooth device connects.
struct PlayLastStationIntent: AudioPlaybackIntent {
    static let title: LocalizedStringResource = "Play Last Station"
    static let description = IntentDescription("Plays the station you listened to most recently in Ski Radio.")
    static let openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let player = RadioPlayer.shared
        if player.isPlaying {
            return .result(dialog: "Already playing \(player.station?.displayName ?? "the radio").")
        }
        guard player.playMostRecent(), let station = player.station else {
            return .result(dialog: "Play a station in Ski Radio first.")
        }
        return .result(dialog: "Playing \(station.displayName).")
    }
}

struct PausePlaybackIntent: AudioPlaybackIntent {
    static let title: LocalizedStringResource = "Pause Radio"
    static let description = IntentDescription("Pauses Ski Radio.")
    static let openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult {
        RadioPlayer.shared.pause()
        return .result()
    }
}

struct SkiRadioShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: PlayLastStationIntent(),
            phrases: [
                "Play \(.applicationName)",
                "Play my last station in \(.applicationName)",
                "Start \(.applicationName)",
            ],
            shortTitle: "Play Last Station",
            systemImageName: "play.circle.fill"
        )
        AppShortcut(
            intent: PausePlaybackIntent(),
            phrases: ["Pause \(.applicationName)", "Stop \(.applicationName)"],
            shortTitle: "Pause Radio",
            systemImageName: "pause.circle.fill"
        )
    }
}
