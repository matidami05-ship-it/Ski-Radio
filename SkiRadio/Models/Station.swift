import Foundation

/// A radio station from the Radio Browser directory (radio-browser.info).
struct Station: Codable, Identifiable, Hashable {
    let stationuuid: String
    let name: String
    let url: String
    let urlResolved: String?
    let favicon: String?
    let tags: String?
    let country: String?
    let countrycode: String?
    let codec: String?
    let bitrate: Int?

    var id: String { stationuuid }

    var displayName: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Unknown Station" : trimmed
    }

    var streamURL: URL? {
        if let resolved = urlResolved, !resolved.isEmpty, let link = URL(string: resolved) {
            return link
        }
        return URL(string: url)
    }

    var artworkURL: URL? {
        guard let favicon, !favicon.isEmpty else { return nil }
        return URL(string: favicon)
    }

    /// "Pop, Rock · United States"
    var subtitle: String {
        let tagList = (tags ?? "")
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces).capitalized }
            .filter { !$0.isEmpty }
            .prefix(3)
        var parts: [String] = []
        if !tagList.isEmpty { parts.append(tagList.joined(separator: ", ")) }
        if let country, !country.isEmpty { parts.append(country) }
        return parts.isEmpty ? "Live radio" : parts.joined(separator: " · ")
    }

    /// "MP3 · 128 kbps"
    var qualityLabel: String? {
        var parts: [String] = []
        if let codec, !codec.isEmpty, codec.uppercased() != "UNKNOWN" { parts.append(codec.uppercased()) }
        if let bitrate, bitrate > 0 { parts.append("\(bitrate) kbps") }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}

enum LoadPhase: Equatable {
    case loading
    case loaded
    case failed(String)
}
