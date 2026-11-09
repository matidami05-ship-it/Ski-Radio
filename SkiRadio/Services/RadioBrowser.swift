import Foundation

enum RadioBrowserError: LocalizedError {
    case badResponse

    var errorDescription: String? {
        switch self {
        case .badResponse: return "The station directory didn't respond. Try again in a moment."
        }
    }
}

/// Client for the free, community-run Radio Browser directory (https://www.radio-browser.info).
actor RadioBrowser {
    static let shared = RadioBrowser()

    private let fallbackHosts = [
        "de1.api.radio-browser.info",
        "de2.api.radio-browser.info",
        "fi1.api.radio-browser.info",
    ]
    private var workingHost: String?

    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.httpAdditionalHeaders = ["User-Agent": "SkiRadio/1.0"]
        config.timeoutIntervalForRequest = 15
        return URLSession(configuration: config)
    }()

    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }()

    // MARK: - Queries

    func topStations(limit: Int = 60) async throws -> [Station] {
        try await stations(path: "/json/stations/topclick/\(limit)", query: [:])
    }

    /// Searches by station name, optionally only within one country (ISO code like "PL").
    func search(_ text: String, countryCode: String? = nil, limit: Int = 60) async throws -> [Station] {
        var query = [
            "limit": "\(limit)",
            "order": "clickcount",
            "reverse": "true",
        ]
        if !text.isEmpty { query["name"] = text }
        if let countryCode { query["countrycode"] = countryCode }
        let found = try await stations(path: "/json/stations/search", query: query)
        return Self.merge(BuiltInStations.matching(text, countryCode: countryCode), found)
    }

    /// Polish radio: Chicago Polish stations first, then stations added by hand, then Poland's most popular.
    func polishStations() async throws -> [Station] {
        async let chicago = (try? stations(path: "/json/stations/search", query: [
            "language": "polish", "countrycode": "US", "limit": "20", "order": "clickcount", "reverse": "true",
        ])) ?? []
        async let poland = stations(countryCode: "PL", limit: 150)
        return Self.merge(BuiltInStations.polishChicago, await chicago, BuiltInStations.polishExtra, try await poland)
    }

    /// Joins lists, dropping repeats of the same station name.
    private static func merge(_ lists: [Station]...) -> [Station] {
        var seen = Set<String>()
        return lists.joined().filter { seen.insert($0.displayName.lowercased()).inserted }
    }

    /// Every country in the directory with its station count, biggest first.
    func countries() async throws -> [Country] {
        if let cachedCountries { return cachedCountries }
        struct Raw: Decodable {
            let name: String
            let iso_3166_1: String
            let stationcount: Int
        }
        let data = try await data(path: "/json/countries", query: [:])
        let raw = try JSONDecoder().decode([Raw].self, from: data)

        // The directory can list a country more than once; merge by code.
        var counts: [String: Int] = [:]
        for entry in raw {
            let code = entry.iso_3166_1.uppercased()
            guard code.count == 2, entry.stationcount > 0 else { continue }
            counts[code, default: 0] += entry.stationcount
        }
        let list = counts
            .map { Country(code: $0.key, stationCount: $0.value) }
            .sorted { $0.stationCount > $1.stationCount }
        cachedCountries = list
        return list
    }

    private var cachedCountries: [Country]?

    func stations(tag: String, limit: Int = 80) async throws -> [Station] {
        try await stations(path: "/json/stations/search", query: [
            "tag": tag,
            "limit": "\(limit)",
            "order": "clickcount",
            "reverse": "true",
        ])
    }

    func stations(countryCode: String, limit: Int = 80) async throws -> [Station] {
        try await stations(path: "/json/stations/search", query: [
            "countrycode": countryCode,
            "limit": "\(limit)",
            "order": "clickcount",
            "reverse": "true",
        ])
    }

    /// Radio Browser asks apps to report plays so popular stations rank correctly.
    func registerClick(_ station: Station) async {
        guard !BuiltInStations.isBuiltIn(station) else { return }
        _ = try? await data(path: "/json/url/\(station.stationuuid)", query: [:])
    }

    // MARK: - Networking

    private func stations(path: String, query: [String: String]) async throws -> [Station] {
        var query = query
        query["hidebroken"] = "true"
        let data = try await data(path: path, query: query)
        let list = try decoder.decode([Station].self, from: data)

        // The directory has many duplicate entries for the same station; keep the most popular one.
        var seen = Set<String>()
        return list.filter { station in
            station.streamURL != nil && seen.insert(station.displayName.lowercased()).inserted
        }
    }

    private func data(path: String, query: [String: String]) async throws -> Data {
        let hosts: [String]
        if let workingHost {
            hosts = [workingHost] + fallbackHosts.filter { $0 != workingHost }
        } else {
            hosts = fallbackHosts.shuffled()
        }

        var lastError: Error = RadioBrowserError.badResponse
        for host in hosts {
            var components = URLComponents()
            components.scheme = "https"
            components.host = host
            components.path = path
            if !query.isEmpty {
                components.queryItems = query
                    .sorted { $0.key < $1.key }
                    .map { URLQueryItem(name: $0.key, value: $0.value) }
            }
            guard let url = components.url else { continue }

            do {
                let (data, response) = try await session.data(from: url)
                guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                    throw RadioBrowserError.badResponse
                }
                workingHost = host
                return data
            } catch {
                if (error as? URLError)?.code == .cancelled { throw error }
                lastError = error
            }
        }
        throw lastError
    }
}
