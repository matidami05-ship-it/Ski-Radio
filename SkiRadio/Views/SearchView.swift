import SwiftUI

struct SearchView: View {
    @State private var query = ""
    @State private var country: Country? = SearchView.savedCountry
    @State private var results: [Station] = []
    @State private var phase: LoadPhase = .loaded
    @State private var showCountryPicker = false

    private var trimmed: String { query.trimmingCharacters(in: .whitespacesAndNewlines) }

    /// With a country picked you can browse its top stations without typing anything.
    private var canSearch: Bool { trimmed.count >= 2 || country != nil }

    var body: some View {
        List {
            Section {
                ForEach(results) { station in
                    StationRow(station: station, list: results)
                }
            } header: {
                countryBar
            }
        }
        .listStyle(.plain)
        .overlay { overlay }
        .navigationTitle("Search")
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always),
                    prompt: country.map { "Stations in \($0.name)" } ?? "Station name")
        .autocorrectionDisabled()
        .task(id: "\(query)|\(country?.code ?? "")") { await search() }
        .sheet(isPresented: $showCountryPicker) {
            CountryPicker(selection: $country)
        }
        .onChange(of: country) { _, newValue in
            SearchView.savedCountry = newValue
        }
    }

    private var countryBar: some View {
        HStack(spacing: 8) {
            Button {
                showCountryPicker = true
            } label: {
                HStack(spacing: 6) {
                    if let country {
                        Text(country.flag)
                        Text(country.name).lineLimit(1)
                    } else {
                        Image(systemName: "globe")
                        Text("All countries")
                    }
                    Image(systemName: "chevron.down")
                        .font(.caption2.weight(.bold))
                }
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(country == nil ? Color(.tertiarySystemFill) : Color.orange.opacity(0.18), in: Capsule())
                .foregroundStyle(country == nil ? Color.primary : Color.orange)
            }
            .buttonStyle(.plain)

            if country != nil {
                Button {
                    country = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear country filter")
            }
            Spacer()
        }
        .padding(.vertical, 4)
        .textCase(nil)
    }

    @ViewBuilder
    private var overlay: some View {
        if !canSearch {
            MessageView(symbol: "magnifyingglass", title: "Find a station",
                        message: "Search by name, like “NPR”, “RMF FM” or “BBC Radio 1”, or pick a country to see its top stations.")
                .padding(.top, 40)
        } else if phase == .loading && results.isEmpty {
            ProgressView()
        } else if case .failed(let message) = phase {
            MessageView(symbol: "wifi.exclamationmark", title: "Search failed", message: message) {
                Task { await search() }
            }
        } else if results.isEmpty && phase == .loaded {
            MessageView(symbol: "radio", title: "No stations found",
                        message: country == nil ? "Try a shorter or different name." : "Try a different name or clear the country filter.")
        }
    }

    private func search() async {
        let text = trimmed
        guard canSearch else {
            results = []
            phase = .loaded
            return
        }
        phase = .loading
        // Debounce typing.
        try? await Task.sleep(nanoseconds: 350_000_000)
        guard !Task.isCancelled else { return }
        do {
            let found = try await RadioBrowser.shared.search(
                text.count >= 2 ? text : "",
                countryCode: country?.code,
                limit: text.count >= 2 ? 60 : 100
            )
            guard !Task.isCancelled else { return }
            results = found
            phase = .loaded
        } catch {
            guard !Task.isCancelled else { return }
            phase = .failed(error.localizedDescription)
        }
    }

    // Remember the last filter between launches.
    private static let countryKey = "search.country"
    static var savedCountry: Country? {
        get { UserDefaults.standard.string(forKey: countryKey).map { Country(code: $0) } }
        set { UserDefaults.standard.set(newValue?.code, forKey: countryKey) }
    }
}

struct CountryPicker: View {
    @Binding var selection: Country?
    @Environment(\.dismiss) private var dismiss

    @State private var countries: [Country] = []
    @State private var phase: LoadPhase = .loading
    @State private var filter = ""

    private var recentCodes: [String] {
        UserDefaults.standard.stringArray(forKey: "search.recentCountries") ?? []
    }

    private var filtered: [Country] {
        let text = filter.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return countries }
        return countries.filter {
            $0.name.localizedCaseInsensitiveContains(text) || $0.code.caseInsensitiveCompare(text) == .orderedSame
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if filter.isEmpty {
                    Section {
                        row(nil)
                        row(countries.first { $0.code == Country.current.code } ?? Country.current)
                        ForEach(recentCodes.filter { $0 != Country.current.code }.prefix(4), id: \.self) { code in
                            row(countries.first { $0.code == code } ?? Country(code: code))
                        }
                    }
                }
                Section(filter.isEmpty ? "All countries" : "") {
                    ForEach(filtered) { row($0) }
                }
            }
            .overlay {
                if phase == .loading && countries.isEmpty {
                    ProgressView()
                } else if case .failed(let message) = phase, countries.isEmpty {
                    MessageView(symbol: "wifi.exclamationmark", title: "Couldn't load countries", message: message) {
                        Task { await load() }
                    }
                }
            }
            .searchable(text: $filter, placement: .navigationBarDrawer(displayMode: .always), prompt: "Country")
            .navigationTitle("Country")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .task { await load() }
        }
    }

    private func row(_ country: Country?) -> some View {
        Button {
            choose(country)
        } label: {
            HStack(spacing: 12) {
                if let country {
                    Text(country.flag).font(.title2)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(country.name).foregroundStyle(.primary)
                        if country.stationCount > 0 {
                            Text("\(country.stationCount) stations")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                } else {
                    Image(systemName: "globe")
                        .font(.title2)
                        .foregroundStyle(.orange)
                        .frame(width: 30)
                    Text("All countries").foregroundStyle(.primary)
                }
                Spacer()
                if selection?.code == country?.code {
                    Image(systemName: "checkmark").foregroundStyle(.orange).fontWeight(.semibold)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func choose(_ country: Country?) {
        selection = country
        if let code = country?.code {
            var recents = recentCodes.filter { $0 != code }
            recents.insert(code, at: 0)
            UserDefaults.standard.set(Array(recents.prefix(6)), forKey: "search.recentCountries")
        }
        dismiss()
    }

    private func load() async {
        if countries.isEmpty { phase = .loading }
        do {
            let list = try await RadioBrowser.shared.countries()
            countries = list
            phase = .loaded
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }
}
