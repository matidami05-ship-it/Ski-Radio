import AVFoundation
import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var player: RadioPlayer
    @EnvironmentObject private var library: Library
    @ObservedObject private var equalizer = Equalizer.shared

    @AppStorage(RadioPlayer.autoplayKey) private var autoplay = true
    @State private var autoplayDevice = AudioDevice.autoplayDevice
    @State private var connected = AudioDevice.currentOutputs
    @State private var confirmClear = false

    private let routeChanges = NotificationCenter.default.publisher(for: AVAudioSession.routeChangeNotification)

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    NavigationLink {
                        EqualizerView()
                    } label: {
                        LabeledContent {
                            Text(equalizer.enabled ? equalizer.presetName : "Off")
                        } label: {
                            Label("Equalizer", systemImage: "slider.vertical.3")
                        }
                    }
                    SleepTimerPicker()
                } header: {
                    Text("Sound")
                }

                Section {
                    Toggle(isOn: $autoplay) {
                        Label("Play when app opens", systemImage: "play.circle")
                    }
                } header: {
                    Text("Auto-play")
                } footer: {
                    Text("Starts your most recent station when you open Ski Radio or connect to CarPlay.")
                }

                bluetoothSection

                Section {
                    Button("Clear Recently Played", role: .destructive) { confirmClear = true }
                        .disabled(library.recents.isEmpty)
                } header: {
                    Text("History")
                }

                Section {
                    LabeledContent("Version", value: appVersion)
                    Link(destination: URL(string: "https://www.radio-browser.info")!) {
                        LabeledContent("Station directory", value: "Radio Browser")
                    }
                } header: {
                    Text("About")
                } footer: {
                    Text("Album art is looked up in Apple's iTunes catalog.")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onReceive(routeChanges.receive(on: RunLoop.main)) { _ in
                connected = AudioDevice.currentOutputs
            }
            .confirmationDialog("Clear your recently played stations?", isPresented: $confirmClear, titleVisibility: .visible) {
                Button("Clear", role: .destructive) { library.clearRecents() }
            }
        }
    }

    // MARK: - Bluetooth

    private var bluetoothSection: some View {
        Section {
            if let device = autoplayDevice {
                LabeledContent {
                    Button("Remove", role: .destructive) {
                        AudioDevice.autoplayDevice = nil
                        autoplayDevice = nil
                    }
                } label: {
                    Label(device.name, systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.primary)
                }
            }

            let choices = connected.filter { device in autoplayDevice.map { !device.matches($0) } ?? true }
            ForEach(choices, id: \.uid) { device in
                Button {
                    AudioDevice.autoplayDevice = device
                    autoplayDevice = device
                } label: {
                    Label("Use \(device.name)", systemImage: "plus.circle")
                }
            }

            if autoplayDevice == nil && connected.isEmpty {
                Label("Connect your car or speaker by Bluetooth to choose it here.", systemImage: "info.circle")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Bluetooth auto-play")
        } footer: {
            Text("Plays your most recent station when this device connects while Ski Radio is open or playing in the background. To have it work even when the app is closed, set up a Shortcuts automation: Bluetooth → your device → Run Immediately → Ski Radio “Play Last Station”.")
        }
    }

    private var appVersion: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}

struct SleepTimerPicker: View {
    @EnvironmentObject private var player: RadioPlayer

    private let options = [15, 30, 45, 60, 90, 120]

    static func title(for minutes: Int) -> String {
        switch minutes {
        case ..<60: return "\(minutes) minutes"
        case 60: return "1 hour"
        case 90: return "1½ hours"
        default: return "\(minutes / 60) hours"
        }
    }

    var body: some View {
        Menu {
            ForEach(options, id: \.self) { minutes in
                Button(Self.title(for: minutes)) {
                    player.setSleepTimer(minutes: minutes)
                }
            }
            if player.sleepEndsAt != nil {
                Divider()
                Button("Turn Off Timer", role: .destructive) { player.setSleepTimer(minutes: nil) }
            }
        } label: {
            LabeledContent {
                if let end = player.sleepEndsAt {
                    Text(timerInterval: Date()...end, countsDown: true)
                        .monospacedDigit()
                        .foregroundStyle(.orange)
                } else {
                    Text("Off")
                }
            } label: {
                Label("Sleep timer", systemImage: "moon.zzz")
                    .foregroundStyle(.primary)
            }
        }
    }
}

/// Moon button for the Now Playing screen.
struct SleepTimerButton: View {
    @EnvironmentObject private var player: RadioPlayer

    var body: some View {
        Menu {
            ForEach([15, 30, 45, 60, 90, 120], id: \.self) { minutes in
                Button(SleepTimerPicker.title(for: minutes)) { player.setSleepTimer(minutes: minutes) }
            }
            if player.sleepEndsAt != nil {
                Divider()
                Button("Turn Off Timer", role: .destructive) { player.setSleepTimer(minutes: nil) }
            }
        } label: {
            VStack(spacing: 2) {
                Image(systemName: player.sleepEndsAt == nil ? "moon.zzz" : "moon.zzz.fill")
                    .font(.title2)
                if let end = player.sleepEndsAt {
                    Text(timerInterval: Date()...end, countsDown: true)
                        .font(.caption2.monospacedDigit())
                }
            }
            .foregroundStyle(player.sleepEndsAt == nil ? Color.primary : Color.orange)
        }
        .accessibilityLabel("Sleep timer")
    }
}
