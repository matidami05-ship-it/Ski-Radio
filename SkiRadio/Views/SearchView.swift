import SwiftUI

struct SearchView: View {
    @State private var query = ""
    @State private var results: [Station] = []
    @State private var phase: LoadPhase = .loaded

    private var trimmed: String { query.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        List(results) { station in
            StationRow(station: station, list: results)
        }
        .listStyle(.plain)
        .overlay { overlay }
        .navigationTitle("Search")
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Station name")
        .autocorrectionDisabled()
        .task(id: query) { await search() }
    }

    @ViewBuilder
    private var overlay: some View {
        if trimmed.count < 2 {
            MessageView(symbol: "magnifyingglass", title: "Find a station",
                        message: "Search by name, like “NPR”, “KISS FM” or “BBC Radio 1”.")
        } else if phase == .loading && results.isEmpty {
            ProgressView()
        } else if case .failed(let message) = phase {
            MessageView(symbol: "wifi.exclamationmark", title: "Search failed", message: message) {
                Task { await search() }
            }
        } else if results.isEmpty && phase == .loaded {
            MessageView(symbol: "radio", title: "No stations found", message: "Try a shorter or different name.")
        }
    }

    private func search() async {
        let text = trimmed
        guard text.count >= 2 else {
            results = []
            phase = .loaded
            return
        }
        phase = .loading
        // Debounce typing.
        try? await Task.sleep(nanoseconds: 350_000_000)
        guard !Task.isCancelled else { return }
        do {
            let found = try await RadioBrowser.shared.search(text)
            guard !Task.isCancelled else { return }
            results = found
            phase = .loaded
        } catch {
            guard !Task.isCancelled else { return }
            phase = .failed(error.localizedDescription)
        }
    }
}
