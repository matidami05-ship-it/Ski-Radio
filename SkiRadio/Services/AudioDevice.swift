import AVFoundation

/// A Bluetooth or car audio output the user can pick for auto-play.
struct AudioDevice: Codable, Equatable {
    let uid: String
    let name: String

    private static let storageKey = "autoplay.bluetoothDevice"

    private static let wirelessTypes: Set<AVAudioSession.Port> = [
        .bluetoothA2DP, .bluetoothHFP, .bluetoothLE, .carAudio, .airPlay,
    ]

    func matches(_ other: AudioDevice) -> Bool {
        uid == other.uid || name == other.name
    }

    /// Bluetooth / car outputs connected right now. iOS doesn't let apps list paired devices,
    /// so a device has to be connected to be picked.
    static var currentOutputs: [AudioDevice] {
        AVAudioSession.sharedInstance().currentRoute.outputs
            .filter { wirelessTypes.contains($0.portType) }
            .map { AudioDevice(uid: $0.uid, name: $0.portName) }
    }

    static var autoplayDevice: AudioDevice? {
        get {
            guard let data = UserDefaults.standard.data(forKey: storageKey) else { return nil }
            return try? JSONDecoder().decode(AudioDevice.self, from: data)
        }
        set {
            if let newValue, let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: storageKey)
            } else {
                UserDefaults.standard.removeObject(forKey: storageKey)
            }
        }
    }
}
