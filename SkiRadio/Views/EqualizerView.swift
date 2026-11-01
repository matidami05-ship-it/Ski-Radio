import SwiftUI

struct EqualizerView: View {
    @ObservedObject private var equalizer = Equalizer.shared
    @EnvironmentObject private var player: RadioPlayer

    var body: some View {
        Form {
            Section {
                Toggle("Equalizer", isOn: $equalizer.enabled)
                unsupportedNote
            }

            Section("Presets") {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(EQPreset.all) { preset in
                            let selected = equalizer.enabled && equalizer.presetName == preset.name
                            Button(preset.name) { equalizer.apply(preset) }
                                .font(.subheadline.weight(.medium))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .background(selected ? Color.orange : Color(.tertiarySystemFill), in: Capsule())
                                .foregroundStyle(selected ? Color.white : Color.primary)
                                .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
            }

            Section {
                BandGraph(gains: equalizer.gains)
                    .frame(height: 90)
                    .opacity(equalizer.enabled ? 1 : 0.35)
                    .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))

                ForEach(EQShared.frequencies.indices, id: \.self) { band in
                    BandSlider(
                        label: EQShared.label(for: EQShared.frequencies[band]) + " Hz",
                        value: Binding(
                            get: { equalizer.gains[band] },
                            set: { equalizer.setGain($0, band: band) }
                        )
                    )
                }
            } header: {
                Text(equalizer.presetName)
            }

            Section {
                BandSlider(label: "Preamp", value: $equalizer.preamp)
            } footer: {
                Text("Raise or lower the overall volume before the equalizer. Boosts are automatically given headroom so loud stations don't distort.")
            }

            Section {
                Button("Reset to Flat", role: .destructive) { equalizer.reset() }
            }
        }
        .navigationTitle("Equalizer")
        .navigationBarTitleDisplayMode(.inline)
    }

    /// Some stations (HLS streams) don't pass audio through the app, so the EQ can't change them.
    private var unsupportedNote: some View {
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            if equalizer.enabled,
               player.status == .playing,
               let since = player.playingSince,
               Date().timeIntervalSince(since) > 3,
               !EQShared.isProcessing {
                Label("This station's stream format doesn't support the equalizer.", systemImage: "exclamationmark.triangle")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct BandSlider: View {
    let label: String
    @Binding var value: Float

    var body: some View {
        HStack(spacing: 10) {
            Text(label)
                .font(.subheadline.monospacedDigit())
                .frame(width: 62, alignment: .leading)
            Slider(value: $value, in: -12...12, step: 0.5)
            Text(String(format: "%+.1f", value))
                .font(.caption.monospacedDigit())
                .foregroundStyle(value == 0 ? Color.secondary : Color.orange)
                .frame(width: 40, alignment: .trailing)
        }
        .onTapGesture(count: 2) { value = 0 }
    }
}

/// Smooth curve of the current band gains.
private struct BandGraph: View {
    let gains: [Float]

    var body: some View {
        GeometryReader { geo in
            let points = gains.enumerated().map { index, gain -> CGPoint in
                let x = gains.count > 1 ? geo.size.width * CGFloat(index) / CGFloat(gains.count - 1) : 0
                let y = geo.size.height / 2 - CGFloat(gain) / 12 * (geo.size.height / 2 - 4)
                return CGPoint(x: x, y: y)
            }
            ZStack {
                Path { path in
                    path.move(to: CGPoint(x: 0, y: geo.size.height / 2))
                    path.addLine(to: CGPoint(x: geo.size.width, y: geo.size.height / 2))
                }
                .stroke(Color.secondary.opacity(0.4), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))

                Path { path in
                    guard let first = points.first else { return }
                    path.move(to: first)
                    for (previous, point) in zip(points, points.dropFirst()) {
                        let mid = (previous.x + point.x) / 2
                        path.addCurve(to: point,
                                      control1: CGPoint(x: mid, y: previous.y),
                                      control2: CGPoint(x: mid, y: point.y))
                    }
                }
                .stroke(Color.orange, style: StrokeStyle(lineWidth: 3, lineCap: .round))
            }
        }
        .animation(.easeOut(duration: 0.25), value: gains)
    }
}
