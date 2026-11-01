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

    func search(_ text: String, limit: Int = 60) async throws -> [Station] {
        try await stations(path: "/json/stations/search", query: [
            "name": text,
            "limit": "\(limit)",
            "order": "clickcount",
            "reverse": "true",
        ])
    }

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
