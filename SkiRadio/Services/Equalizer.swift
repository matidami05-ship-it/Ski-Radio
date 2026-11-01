import AVFoundation
import MediaToolbox
import os

// MARK: - Shared state read by the audio thread

struct EQState: Sendable {
    var enabled = false
    var gains = Array(repeating: Float(0), count: EQShared.frequencies.count)
    var preamp: Float = 0
    var version = 0
}

enum EQShared {
    static let frequencies: [Float] = [32, 64, 125, 250, 500, 1000, 2000, 4000, 8000, 16000]
    static let state = OSAllocatedUnfairLock(initialState: EQState())
    /// Last time the audio thread processed a buffer, so the UI can tell if EQ works on this stream.
    static let heartbeat = OSAllocatedUnfairLock(initialState: TimeInterval(0))

    static var isProcessing: Bool {
        ProcessInfo.processInfo.systemUptime - heartbeat.withLock { $0 } < 1.5
    }

    static func label(for frequency: Float) -> String {
        frequency >= 1000 ? "\(Int(frequency / 1000))k" : "\(Int(frequency))"
    }
}

// MARK: - Presets

struct EQPreset: Identifiable, Hashable {
    let name: String
    let gains: [Float]
    var id: String { name }

    static let flat = EQPreset(name: "Flat", gains: Array(repeating: 0, count: 10))

    static let all: [EQPreset] = [
        flat,
        EQPreset(name: "Bass Boost", gains: [6, 5, 4, 2, 0, 0, 0, 0, 0, 0]),
        EQPreset(name: "Treble Boost", gains: [0, 0, 0, 0, 0, 1, 2, 4, 5, 6]),
        EQPreset(name: "Car", gains: [4, 3, 2, 1, 0, 1, 2, 2, 1, 0]),
        EQPreset(name: "Loudness", gains: [5, 3, 0, 0, -1, 0, -1, 0, 3, 4]),
        EQPreset(name: "Rock", gains: [4, 3, 2, 0, -1, -1, 1, 2, 3, 4]),
        EQPreset(name: "Pop", gains: [-1, 1, 2, 3, 2, 0, -1, -1, 0, 1]),
        EQPreset(name: "Hip-Hop", gains: [5, 4, 2, 1, -1, -1, 1, 0, 1, 2]),
        EQPreset(name: "Jazz", gains: [3, 2, 1, 2, -1, -1, 0, 1, 2, 3]),
        EQPreset(name: "Classical", gains: [3, 2, 1, 0, 0, 0, -1, -1, 1, 2]),
        EQPreset(name: "Vocal", gains: [-2, -2, -1, 1, 3, 4, 3, 1, 0, -1]),
        EQPreset(name: "Talk Radio", gains: [-3, -2, 0, 2, 4, 4, 3, 1, 0, -2]),
    ]

    static func matching(_ gains: [Float]) -> EQPreset? {
        all.first { $0.gains == gains }
    }
}

// MARK: - Settings model (UI side)

@MainActor
final class Equalizer: ObservableObject {
    static let shared = Equalizer()

    private enum Keys {
        static let enabled = "eq.enabled"
        static let gains = "eq.gains"
        static let preamp = "eq.preamp"
    }

    @Published var enabled: Bool { didSet { save() } }
    @Published var preamp: Float { didSet { save() } }
    @Published private(set) var gains: [Float]

    var presetName: String { EQPreset.matching(gains)?.name ?? "Custom" }

    private init() {
        let defaults = UserDefaults.standard
        enabled = defaults.bool(forKey: Keys.enabled)
        preamp = defaults.float(forKey: Keys.preamp)
        let saved = defaults.array(forKey: Keys.gains) as? [Float] ?? []
        gains = saved.count == EQShared.frequencies.count ? saved : EQPreset.flat.gains
        push()
    }

    func setGain(_ value: Float, band: Int) {
        guard gains.indices.contains(band) else { return }
        gains[band] = (value * 2).rounded() / 2   // half-dB steps
        save()
    }

    func apply(_ preset: EQPreset) {
        gains = preset.gains
        if !enabled { enabled = true } else { save() }
    }

    func reset() {
        gains = EQPreset.flat.gains
        preamp = 0
        save()
    }

    private func save() {
        let defaults = UserDefaults.standard
        defaults.set(enabled, forKey: Keys.enabled)
        defaults.set(gains, forKey: Keys.gains)
        defaults.set(preamp, forKey: Keys.preamp)
        push()
    }

    private func push() {
        let snapshot = EQState(enabled: enabled, gains: gains, preamp: preamp, version: 0)
        EQShared.state.withLock { state in
            let version = state.version + 1
            state = snapshot
            state.version = version
        }
    }
}

// MARK: - Audio processing (runs on the audio thread)

/// A chain of peaking filters, one per band, applied to each channel.
final class EQProcessor {
    private static let maxBands = EQShared.frequencies.count

    private var sampleRate: Double = 44_100
    private var channels = 0
    private var isFloat = false
    private var nonInterleaved = true
    private var seenVersion = -1
    private var active = false
    private var bandCount = 0
    private var gain: Float = 1

    /// b0, b1, b2, a1, a2 per active band.
    private let coefficients: UnsafeMutablePointer<Float>
    /// x1, x2, y1, y2 per band per channel.
    private var history: UnsafeMutablePointer<Float>?
    private var historySize = 0

    init() {
        coefficients = .allocate(capacity: Self.maxBands * 5)
        coefficients.initialize(repeating: 0, count: Self.maxBands * 5)
    }

    deinit {
        coefficients.deallocate()
        history?.deallocate()
    }

    func prepare(format: AudioStreamBasicDescription) {
        sampleRate = format.mSampleRate > 0 ? format.mSampleRate : 44_100
        nonInterleaved = format.mFormatFlags & kAudioFormatFlagIsNonInterleaved != 0
        isFloat = format.mFormatFlags & kAudioFormatFlagIsFloat != 0 && format.mBitsPerChannel == 32
        channels = Int(format.mChannelsPerFrame)

        history?.deallocate()
        historySize = max(channels, 1) * Self.maxBands * 4
        let buffer = UnsafeMutablePointer<Float>.allocate(capacity: historySize)
        buffer.initialize(repeating: 0, count: historySize)
        history = buffer
        seenVersion = -1
    }

    func unprepare() {
        history?.deallocate()
        history = nil
    }

    private func refreshIfNeeded() {
        let known = seenVersion
        guard let settings = EQShared.state.withLock({ $0.version == known ? nil : $0 }) else { return }
        seenVersion = settings.version
        active = settings.enabled

        // Leave headroom for boosts so loud stations don't distort.
        let maxBoost = max(0, settings.gains.max() ?? 0)
        gain = powf(10, (settings.preamp - maxBoost * 0.5) / 20)

        bandCount = 0
        for (index, frequency) in EQShared.frequencies.enumerated() where index < settings.gains.count {
            let dB = settings.gains[index]
            guard abs(dB) >= 0.25, Double(frequency) < sampleRate * 0.45 else { continue }

            // Peaking filter (RBJ audio EQ cookbook).
            let a = pow(10, Double(dB) / 40)
            let w0 = 2 * Double.pi * Double(frequency) / sampleRate
            let alpha = sin(w0) / (2 * 1.41)
            let cosW0 = cos(w0)
            let a0 = 1 + alpha / a
            let k = coefficients + bandCount * 5
            k[0] = Float((1 + alpha * a) / a0)
            k[1] = Float((-2 * cosW0) / a0)
            k[2] = Float((1 - alpha * a) / a0)
            k[3] = Float((-2 * cosW0) / a0)
            k[4] = Float((1 - alpha / a) / a0)
            bandCount += 1
        }
        history?.update(repeating: 0, count: historySize)
    }

    func process(_ bufferList: UnsafeMutablePointer<AudioBufferList>, frames: Int) {
        EQShared.heartbeat.withLock { $0 = ProcessInfo.processInfo.systemUptime }
        guard isFloat, let history, frames > 0 else { return }
        refreshIfNeeded()
        guard active, bandCount > 0 || gain != 1 else { return }

        let buffers = UnsafeMutableAudioBufferListPointer(bufferList)
        for (bufferIndex, buffer) in buffers.enumerated() {
            guard let raw = buffer.mData else { continue }
            let samples = raw.assumingMemoryBound(to: Float.self)
            let channelsInBuffer = max(Int(buffer.mNumberChannels), 1)
            let frameCount = min(frames, Int(buffer.mDataByteSize) / (4 * channelsInBuffer))

            for c in 0..<channelsInBuffer {
                let channel = nonInterleaved ? bufferIndex : c
                guard channel < max(channels, 1) else { continue }
                let state = history + channel * Self.maxBands * 4
                var i = c
                for _ in 0..<frameCount {
                    var x = samples[i] * gain
                    for band in 0..<bandCount {
                        let k = coefficients + band * 5
                        let z = state + band * 4
                        let y = k[0] * x + k[1] * z[0] + k[2] * z[1] - k[3] * z[2] - k[4] * z[3]
                        z[1] = z[0]; z[0] = x
                        z[3] = z[2]; z[2] = y
                        x = y
                    }
                    samples[i] = min(1, max(-1, x))
                    i += channelsInBuffer
                }
            }
        }
    }
}

// MARK: - Hooking the processor into AVPlayer

enum EqualizerTap {
    private static func processor(_ tap: MTAudioProcessingTap) -> EQProcessor {
        Unmanaged<EQProcessor>.fromOpaque(MTAudioProcessingTapGetStorage(tap)).takeUnretainedValue()
    }

    /// Builds an audio mix that runs the stream through the equalizer.
    static func audioMix(for track: AVAssetTrack) -> AVAudioMix? {
        let client = Unmanaged.passRetained(EQProcessor()).toOpaque()

        var callbacks = MTAudioProcessingTapCallbacks(
            version: kMTAudioProcessingTapCallbacksVersion_0,
            clientInfo: client,
            init: { _, clientInfo, storageOut in
                storageOut.pointee = clientInfo
            },
            finalize: { tap in
                Unmanaged<EQProcessor>.fromOpaque(MTAudioProcessingTapGetStorage(tap)).release()
            },
            prepare: { tap, _, format in
                EqualizerTap.processor(tap).prepare(format: format.pointee)
            },
            unprepare: { tap in
                EqualizerTap.processor(tap).unprepare()
            },
            process: { tap, frames, _, bufferList, framesOut, flagsOut in
                let status = MTAudioProcessingTapGetSourceAudio(tap, frames, bufferList, flagsOut, nil, framesOut)
                guard status == noErr else { return }
                EqualizerTap.processor(tap).process(bufferList, frames: Int(framesOut.pointee))
            }
        )

        var unmanagedTap: Unmanaged<MTAudioProcessingTap>?
        let status = MTAudioProcessingTapCreate(kCFAllocatorDefault, &callbacks, kMTAudioProcessingTapCreationFlag_PostEffects, &unmanagedTap)
        guard status == noErr, let tap = unmanagedTap?.takeRetainedValue() else {
            Unmanaged<EQProcessor>.fromOpaque(client).release()
            return nil
        }

        let parameters = AVMutableAudioMixInputParameters(track: track)
        parameters.audioTapProcessor = tap
        let mix = AVMutableAudioMix()
        mix.inputParameters = [parameters]
        return mix
    }
}
